import os

def concatenate_md_files(output_file="combined.md", separator="\n---\n"):
    """
    Scan current directory for .md files and concatenate them in order.
    
    Args:
        output_file (str): Name of the output file (default: "combined.md")
        separator (str): Separator to place between files (default: "---")
    """
    # Get all .md files in current directory, sorted alphabetically
    md_files = [f for f in os.listdir('.') if f.endswith('.md') and os.path.isfile(f)]
    md_files.sort()  # Ensure consistent ordering
    
    if not md_files:
        print("No Markdown files found in current directory.")
        return
    
    print(f"Found {len(md_files)} Markdown files:")
    for file in md_files:
        print(f"  - {file}")
    
    # Write concatenated content
    with open(output_file, 'w', encoding='utf-8') as outfile:
        for i, filename in enumerate(md_files):
            # Add separator before all files except the first one
            if i > 0:
                outfile.write(separator)
            
            # Read and write file content
            with open(filename, 'r', encoding='utf-8') as infile:
                outfile.write(infile.read())
            
            # Add newline at the end of each file
            outfile.write('\n')
    
    print(f"\nConcatenation complete. Output saved to '{output_file}'")

if __name__ == "__main__":
    concatenate_md_files()
