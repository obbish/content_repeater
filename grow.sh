#!/bin/bash

# ==============================================================================
# Script: create_segment.sh
# Description: Creates a binary file of a user-chosen size. The script first
#              finds all possible file sizes (between ~1MB and ~4MB) that are
#              multiples of the physical block size AND can perfectly tile a
#              given disk length. After the user chooses a size, the script
#              fills the file with a repeating pattern derived from a user-
#              provided string and zero-padding.
# ==============================================================================

# --- System Configuration ---
# NOTE: For perfect tiling, DISK_LENGTH MUST be a multiple of PHYSICAL_BLOCKSIZE.
# The values below are a working example. Replace DISK_LENGTH with your own.

readonly PHYSICAL_BLOCKSIZE=4096
# Example Disk Length: 4,730,880 bytes = 4096 * 1155. This is ~4.5 MiB.
readonly DISK_LENGTH=4730880
readonly OUTPUT_FILE="perfect_segment.bin"

# --- Input Validation ---

# 1. Check for the correct number of command-line arguments.
if [ "$#" -ne 1 ]; then
    echo "Error: You must provide a single text string as an argument." >&2
    echo "Usage: $0 \"<your_string>\"" >&2
    exit 1
fi

# 2. Store the input string and validate its length.
#    The length must be less than the block size to allow for padding.
USER_STRING="$1"
STRING_LEN=$(echo -n "$USER_STRING" | wc -c)

if [ "$STRING_LEN" -lt 1 ] || [ "$STRING_LEN" -ge "$PHYSICAL_BLOCKSIZE" ]; then
    echo "Error: Input string length must be between 1 and 4095 bytes." >&2
    echo "Your string length: $STRING_LEN bytes." >&2
    exit 1
fi

# --- Find & Present Valid File Sizes ---

echo "⚙️  Finding valid file sizes that perfectly tile the disk..."

declare -a choices_size
declare -a choices_count

# Calculate how many physical blocks fit on the entire disk.
readonly TOTAL_BLOCKS=$((DISK_LENGTH / PHYSICAL_BLOCKSIZE))

# Find all divisors of TOTAL_BLOCKS. Each divisor represents a valid
# repetition count for a potential segment file.
for (( i=1; i<=TOTAL_BLOCKS; i++ )); do
    if (( TOTAL_BLOCKS % i == 0 )); then
        # 'i' is a valid repetition count (how many times the file fits on disk)
        # The corresponding file size is DISK_LENGTH / i
        file_size=$((DISK_LENGTH / i))

        # Filter for sizes roughly between 1MB and 4MB for user convenience
        if [ "$file_size" -ge 1000000 ] && [ "$file_size" -le 4000000 ]; then
            choices_size+=("$file_size")
            choices_count+=("$i")
        fi
    fi
done

# Exit if no suitable sizes were found in the specified range.
if [ ${#choices_size[@]} -eq 0 ]; then
    echo "Error: No valid file sizes found in the 1MB-4MB range for the given disk length." >&2
    exit 1
fi

echo "✅ Please choose a file size. Each option is guaranteed to fit perfectly."
# Display the choices in a numbered list
for i in "${!choices_size[@]}"; do
    size_bytes=${choices_size[$i]}
    fit_count=${choices_count[$i]}
    hr_size=$(awk -v b=$size_bytes 'BEGIN{s="B K M G T"; while(b>=1024){b/=1024;s=substr(s,3)} printf "%.2f %sB", b, substr(s,1,1)}')
    printf "  %d) File Size: %-9d bytes (%-9s) -> Fits %d times on disk\n" "$((i+1))" "$size_bytes" "$hr_size" "$fit_count"
done

# --- Get User Choice ---
user_choice=0
while true; do
    read -p "Enter your choice (1-${#choices_size[@]}): " user_choice
    if [[ "$user_choice" =~ ^[0-9]+$ ]] && [ "$user_choice" -ge 1 ] && [ "$user_choice" -le "${#choices_size[@]}" ]; then
        break
    else
        echo "Invalid input. Please enter a valid number from the list."
    fi
done

# Set the final TARGET_SIZE based on the user's selection.
TARGET_SIZE=${choices_size[$((user_choice-1))]}
echo ""
echo "Selected target file size: $TARGET_SIZE bytes."

# --- Pattern Calculation & File Creation ---

echo "⚙️  Calculating optimal pattern to fill the $TARGET_SIZE byte file..."

# Find the smallest factor of TARGET_SIZE that is >= the string length.
# This will be our total pattern length for tiling the file.
PATTERN_LEN=0
for (( i=STRING_LEN; i<=TARGET_SIZE; i++ )); do
    if (( TARGET_SIZE % i == 0 )); then
        PATTERN_LEN=$i
        break
    fi
done

# Calculate padding and repetition count for the file content.
NUM_ZEROS=$((PATTERN_LEN - STRING_LEN))
REPETITIONS=$((TARGET_SIZE / PATTERN_LEN))

echo "   - Pattern: '$USER_STRING' + $NUM_ZEROS zero bytes"
echo "   - This pattern will be repeated $REPETITIONS times to create the file."
echo ""
echo "🛠️  Creating file '$OUTPUT_FILE'..."

# Create the file using a single, efficient subshell redirection.
(
    for (( r=0; r<REPETITIONS; r++ )); do
        printf "%s" "$USER_STRING"
        if [ "$NUM_ZEROS" -gt 0 ]; then
            head -c "$NUM_ZEROS" /dev/zero
        fi
    done
) > "$OUTPUT_FILE"

# --- Verification ---
echo "🔍 Verifying final file size..."
FINAL_SIZE=$(wc -c < "$OUTPUT_FILE")

if [ "$FINAL_SIZE" -eq "$TARGET_SIZE" ]; then
    echo "🎉 Success! File '$OUTPUT_FILE' created with the correct size: $FINAL_SIZE bytes."
else
    echo "🔥 Error: File creation failed. Expected $TARGET_SIZE, but got $FINAL_SIZE bytes." >&2
    exit 1
fi

exit 0
