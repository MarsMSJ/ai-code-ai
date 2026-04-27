#!/bin/bash
# Agentic coding benchmark for vLLM endpoint
# Sends a realistic ~4K token codec audit prompt and times the response

set -e

ENDPOINT="${ENDPOINT:-http://192.168.1.120:8000/v1/chat/completions}"
MODEL="${MODEL:-MiniMax-M2.7}"
MAX_TOKENS="${MAX_TOKENS:-2000}"

PROMPT='You are working on a proprietary AV1 decoder library. Below is the relevant context.

File: dav1d_wrapper.h
typedef struct {
    uint32_t width;
    uint32_t height;
    uint32_t profile;
    uint32_t level;
    uint32_t bit_depth;
    uint32_t color_range;
    uint32_t color_primaries;
    uint32_t transfer_characteristics;
    uint32_t matrix_coefficients;
    uint32_t chroma_sample_position;
    void *reserved[16];
} av1_seq_info_t;

typedef enum {
    AV1_OK = 0,
    AV1_ERR_INVALID_PARAM = -1,
    AV1_ERR_NO_MEMORY = -2,
    AV1_ERR_NEED_MORE_DATA = -3,
    AV1_ERR_DECODE_FAILED = -4,
    AV1_ERR_UNSUPPORTED = -5,
} av1_status_t;

typedef struct av1_decoder av1_decoder_t;

av1_status_t av1_query_memory(const av1_seq_info_t *info, size_t *out_size);
av1_status_t av1_create(const av1_seq_info_t *info, void *mem, size_t mem_size, av1_decoder_t **out_dec);
av1_status_t av1_decode_au(av1_decoder_t *dec, const uint8_t *data, size_t size, uint64_t pts);
av1_status_t av1_sync_au(av1_decoder_t *dec);
av1_status_t av1_receive_output(av1_decoder_t *dec, av1_frame_t *out_frame);
void av1_destroy(av1_decoder_t *dec);

File: dav1d_wrapper.c (current implementation, partial)
struct av1_decoder {
    Dav1dContext *dav1d_ctx;
    Dav1dSettings settings;
    void *mem_pool;
    size_t mem_pool_size;
    size_t mem_pool_used;
    av1_seq_info_t info;
    pthread_mutex_t lock;
    int initialized;
};

av1_status_t av1_query_memory(const av1_seq_info_t *info, size_t *out_size) {
    if (!info || !out_size) return AV1_ERR_INVALID_PARAM;
    if (info->width == 0 || info->height == 0) return AV1_ERR_INVALID_PARAM;
    if (info->bit_depth != 8 && info->bit_depth != 10 && info->bit_depth != 12) {
        return AV1_ERR_INVALID_PARAM;
    }

    size_t base = sizeof(struct av1_decoder);
    size_t frame_buf_size = (size_t)info->width * info->height * 3 / 2;
    if (info->bit_depth > 8) frame_buf_size *= 2;
    size_t dpb_size = frame_buf_size * 8;
    size_t scratch = 4 * 1024 * 1024;

    *out_size = base + dpb_size + scratch;
    return AV1_OK;
}

Task: Audit av1_query_memory for completeness. Specifically:
1. Identify any missing validation (chroma subsampling, color space combos, profile/level limits)
2. Check whether the memory calculation accounts for libdav1d internal allocations
3. Verify alignment requirements are honored
4. Suggest specific code changes with exact line-level diffs

Provide a structured response with: findings, severity per finding, and the corrected function body.'

PAYLOAD=$(jq -n \
    --arg model "$MODEL" \
    --arg prompt "$PROMPT" \
    --argjson max_tokens "$MAX_TOKENS" \
    '{
        model: $model,
        messages: [{role: "user", content: $prompt}],
        max_tokens: $max_tokens,
        temperature: 0.2,
        stream: false
    }')

echo "=== Agentic benchmark ==="
echo "Endpoint: $ENDPOINT"
echo "Model:    $MODEL"
echo "Started:  $(date)"
echo

START=$(date +%s.%N)

RESPONSE=$(curl -s "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

END=$(date +%s.%N)
ELAPSED=$(echo "$END - $START" | bc)

if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
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

if [ "$COMPLETION_TOKENS" != "n/a" ] && [ "$COMPLETION_TOKENS" -gt 0 ]; then
    RATE=$(echo "scale=2; $COMPLETION_TOKENS / $ELAPSED" | bc)
    echo "End-to-end rate:   ${RATE} tok/s (includes prefill)"
fi

echo
echo "=== Response (first 500 chars) ==="
echo "$RESPONSE" | jq -r '.choices[0].message.content' | head -c 500
echo
echo "..."
echo
echo "=== Full response saved to /tmp/agentic_bench_last.json ==="
echo "$RESPONSE" > /tmp/agentic_bench_last.json
