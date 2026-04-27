#!/usr/bin/env bash
# Portable agentic coding benchmark for OpenAI-compatible chat completion APIs.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  agentic_bench_universal.sh MODEL_ID URL [MAX_TOKENS]

Arguments:
  MODEL_ID    Model name served by the endpoint, for example MiniMax-M2.7
  URL         OpenAI-compatible base URL or chat completions URL
              Examples:
                http://localhost:8000
                http://localhost:8000/v1
                http://localhost:8000/v1/chat/completions
  MAX_TOKENS  Optional completion token limit. Defaults to 2000.

Environment:
  API_KEY      Optional bearer token for authenticated endpoints.
  TEMPERATURE  Optional sampling temperature. Defaults to 0.2.
  OUT_FILE     Optional response JSON path. Defaults to /tmp/agentic_bench_last.json.

Examples:
  ./agentic_bench_universal.sh MiniMax-M2.7 http://localhost:8000/v1
  API_KEY=sk-... ./agentic_bench_universal.sh gpt-oss http://my-server:8000/v1/chat/completions 1000
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

normalize_endpoint() {
  local url="${1%/}"

  case "$url" in
    */v1/chat/completions)
      printf '%s\n' "$url"
      ;;
    */v1)
      printf '%s/chat/completions\n' "$url"
      ;;
    *)
      printf '%s/v1/chat/completions\n' "$url"
      ;;
  esac
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

[[ $# -ge 2 && $# -le 3 ]] || {
  usage >&2
  exit 2
}

require_cmd curl
require_cmd jq
require_cmd python3

MODEL="$1"
ENDPOINT=$(normalize_endpoint "$2")
MAX_TOKENS="${3:-2000}"
TEMPERATURE="${TEMPERATURE:-0.2}"
OUT_FILE="${OUT_FILE:-/tmp/agentic_bench_last.json}"

[[ "$MAX_TOKENS" =~ ^[0-9]+$ ]] || die "MAX_TOKENS must be an integer"

PROMPT=$(cat <<'EOF'
You are implementing a small production utility from a written spec. Generate code first, then validate the code against the provided fixture without using external libraries.

Task:
Write a self-contained Python 3 function named summarize_usage_events(events) that accepts a list of dictionaries and returns a dictionary with two keys:
  summaries: a list of per-user summary dictionaries
  rejected: a list of rejected event dictionaries with a reason field added

Each input event may contain:
  user_id: string
  session_id: string
  ts: ISO-8601 UTC timestamp ending in Z
  kind: one of "start", "heartbeat", "stop"
  tokens: integer token count for that event

Rules:
1. Reject an event if user_id or session_id is missing or empty.
2. Reject an event if ts is missing, not valid ISO-8601 UTC ending in Z, or cannot be parsed.
3. Reject an event if kind is not start, heartbeat, or stop.
4. Reject an event if tokens is missing, not an integer, or negative. Booleans must not count as integers.
5. For accepted events, group by user_id.
6. For each user, total_tokens is the sum of accepted tokens.
7. For each user, session_count is the number of distinct accepted session_id values.
8. For each user, first_seen and last_seen are the earliest and latest accepted timestamps, emitted in the same ISO format with Z.
9. For each user, has_unclosed_session is true if any accepted session has a start event with no later stop event in that same session.
10. Sort summaries by user_id ascending.
11. Sort rejected events by original input order.

Fixture input to validate against:
[
  {"user_id": "alice", "session_id": "s1", "ts": "2026-04-26T10:00:00Z", "kind": "start", "tokens": 3},
  {"user_id": "alice", "session_id": "s1", "ts": "2026-04-26T10:01:00Z", "kind": "heartbeat", "tokens": 2},
  {"user_id": "bob", "session_id": "b1", "ts": "2026-04-26T09:59:00Z", "kind": "start", "tokens": 5},
  {"user_id": "alice", "session_id": "s1", "ts": "2026-04-26T10:02:00Z", "kind": "stop", "tokens": 1},
  {"user_id": "alice", "session_id": "s2", "ts": "2026-04-26T10:05:00Z", "kind": "start", "tokens": 7},
  {"user_id": "", "session_id": "bad", "ts": "2026-04-26T10:06:00Z", "kind": "start", "tokens": 1},
  {"user_id": "carol", "session_id": "c1", "ts": "not-a-date", "kind": "start", "tokens": 1},
  {"user_id": "bob", "session_id": "b1", "ts": "2026-04-26T10:10:00Z", "kind": "stop", "tokens": true},
  {"user_id": "bob", "session_id": "b1", "ts": "2026-04-26T10:11:00Z", "kind": "stop", "tokens": 4}
]

Response requirements:
1. Provide the complete Python function in one code block.
2. Manually validate the function against the fixture and provide the exact returned dictionary as JSON.
3. Explain briefly how the code detects unclosed sessions.
4. List two additional edge cases that should be tested.
EOF
)

PAYLOAD=$(jq -n \
  --arg model "$MODEL" \
  --arg prompt "$PROMPT" \
  --argjson max_tokens "$MAX_TOKENS" \
  --argjson temperature "$TEMPERATURE" \
  '{
      model: $model,
      messages: [{role: "user", content: $prompt}],
      max_tokens: $max_tokens,
      temperature: $temperature,
      stream: false
  }')

echo "=== Agentic benchmark ==="
echo "Endpoint:   $ENDPOINT"
echo "Model:      $MODEL"
echo "Max tokens: $MAX_TOKENS"
echo "Started:    $(date)"
echo

curl_args=(
  -sS
  "$ENDPOINT"
  -H "Content-Type: application/json"
  -d "$PAYLOAD"
)

if [[ -n "${API_KEY:-}" ]]; then
  curl_args+=(-H "Authorization: Bearer $API_KEY")
fi

START=$(python3 - <<'PY'
import time
print(time.time())
PY
)

RESPONSE=$(curl "${curl_args[@]}")

END=$(python3 - <<'PY'
import time
print(time.time())
PY
)

ELAPSED=$(python3 - "$START" "$END" <<'PY'
import sys
start = float(sys.argv[1])
end = float(sys.argv[2])
print(f"{end - start:.3f}")
PY
)

if echo "$RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
  echo "ERROR from server:"
  echo "$RESPONSE" | jq '.error'
  exit 1
fi

PROMPT_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.prompt_tokens // "n/a"')
COMPLETION_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.completion_tokens // "n/a"')
TOTAL_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.total_tokens // "n/a"')

echo "=== Results ==="
echo "Elapsed:           ${ELAPSED}s"
echo "Prompt tokens:     $PROMPT_TOKENS"
echo "Completion tokens: $COMPLETION_TOKENS"
echo "Total tokens:      $TOTAL_TOKENS"

if [[ "$COMPLETION_TOKENS" =~ ^[0-9]+$ && "$COMPLETION_TOKENS" -gt 0 ]]; then
  RATE=$(python3 - "$COMPLETION_TOKENS" "$ELAPSED" <<'PY'
import sys
tokens = int(sys.argv[1])
elapsed = float(sys.argv[2])
print(f"{tokens / elapsed:.2f}")
PY
)
  echo "End-to-end rate:   ${RATE} tok/s (includes prefill)"
fi

echo
echo "=== Response (first 500 chars) ==="
echo "$RESPONSE" | jq -r '.choices[0].message.content // ""' | python3 -c 'import sys; print(sys.stdin.read()[:500])'
echo "..."
echo
echo "=== Full response saved to $OUT_FILE ==="
printf '%s\n' "$RESPONSE" > "$OUT_FILE"
