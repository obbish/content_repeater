#!/bin/bash

# ==============================================================================
# Script: create_perfect_segment.sh
# Description: Generates a list of valid segment lengths that are multiples of
#              the physical block size and divisors of the total disk length.
#              It then prompts the user to choose a size and creates a binary
#              file tiled with a pattern derived from a user-provided string.
# Usage: ./create_perfect_segment.sh "<your_string>"
# ==============================================================================

# --- Drive & Filesystem Configuration ---

# The physical block size of the storage device in bytes.
readonly PHYSICAL_BLOCKSIZE=4096
# The total length of the disk or partition in bytes.
readonly DISK_LENGTH=250059350016
# The name of the output file.
readonly OUTPUT_FILE="perfect_segment.bin"

# --- Input Validation ---

# 1. Check for the correct number of command-line arguments.
if [ "$#" -ne 1 ]; then
    echo "Error: You must provide a text string as an argument." >&2
    echo "Usage: $0 \"<your_string>\"" >&2
    exit 1
fi

# 2. Store the input string and calculate its byte length.
USER_STRING="$1"
STRING_LEN=$(echo -n "$USER_STRING" | wc -c)

# 3. Validate the string length. It must be shorter than the smallest possible segment.
if [ "$STRING_LEN" -lt 1 ] || [ "$STRING_LEN" -ge "$PHYSICAL_BLOCKSIZE" ]; then
    echo "Error: Input string length must be between 1 and 4095 bytes." >&2
    echo "Your string length: $STRING_LEN bytes." >&2
    exit 1
fi

# --- Segment Size Selection ---

# These are pre-calculated valid segment lengths. Each is a multiple of 4096
# and a perfect divisor of 250059350016.
segment_choices=(
    4096              # 4 KiB (1 block)
    8192              # 8 KiB (2 blocks)
    12288             # 12 KiB (3 blocks)
    86016             # 84 KiB (21 blocks)
    1969152           # 1.88 MiB
    37996544          # 36.24 MiB
    75993088          # 72.47 MiB
    2101035008        # 1.96 GiB
    250059350016      # 232.89 GiB (The entire disk)
)

echo "💿 Found valid segment lengths for a ${DISK_LENGTH} byte disk."
echo "Please choose a segment length for the output file:"

# Display the choices in a user-friendly format
# We use 'awk' for floating-point division to show human-readable sizes.
for i in "${!segment_choices[@]}"; do
    bytes=${segment_choices[$i]}
    hr_size=$(awk -v b=$bytes '
      BEGIN{
        s="B K M G T P"; split(s,a);
        while(b>=1024 && length(s)>1){ b/=1024; s=substr(s,3) }
        printf "%.2f %sB\n", b, substr(s,1,1)
      }')
    printf "  %d) %12d bytes (%s)\n" "$((i+1))" "$bytes" "$hr_size"
done

# --- User Input Loop ---

user_choice=0
while true; do
    read -p "Enter your choice (1-9): " user_choice
    # Check if input is a number and within the valid range
    if [[ "$user_choice" =~ ^[0-9]+$ ]] && [ "$user_choice" -ge 1 ] && [ "$user_choice" -le "${#segment_choices[@]}" ]; then
        break
    else
        echo "Invalid input. Please enter a number between 1 and 9."
    fi
done

# Set the chosen segment length as our new target size
SEGMENT_LENGTH=${segment_choices[$((user_choice-1))]}
echo ""
echo "Selected segment length: $SEGMENT_LENGTH bytes."

# --- Pattern Calculation (for the chosen SEGMENT_LENGTH) ---

echo "⚙️  Calculating optimal tiling pattern..."

# Find the smallest factor of SEGMENT_LENGTH >= string length.
PATTERN_LEN=0
for (( i=STRING_LEN; i<=SEGMENT_LENGTH; i++ )); do
    if (( SEGMENT_LENGTH % i == 0 )); then
        PATTERN_LEN=$i
        break
    fi
done

NUM_ZEROS=$((PATTERN_LEN - STRING_LEN))
REPETITIONS=$((SEGMENT_LENGTH / PATTERN_LEN))

echo "✅ Calculation complete for segment."
echo "   - Pattern length: $PATTERN_LEN bytes (String: $STRING_LEN, Zeros: $NUM_ZEROS)"
echo "   - Repetitions: $REPETITIONS times"
echo ""

# --- File Creation ---

echo "🛠️  Creating file '$OUTPUT_FILE'..."

(
    for (( r=0; r<REPETITIONS; r++ )); do
        printf "%s" "$USER_STRING"
        if [ "$NUM_ZEROS" -gt 0 ]; then
            for (( z=0; z<NUM_ZEROS; z++ )); do
                printf '\0'
            done
        fi
    done
) > "$OUTPUT_FILE"

# --- Verification ---

echo "🔍 Verifying file size..."
FINAL_SIZE=$(wc -c < "$OUTPUT_FILE")

if [ "$FINAL_SIZE" -eq "$SEGMENT_LENGTH" ]; then
    echo "🎉 Success! File '$OUTPUT_FILE' created with the correct size: $FINAL_SIZE bytes."
else
    echo "🔥 Error: File creation failed. Expected $SEGMENT_LENGTH, but got $FINAL_SIZE bytes." >&2
    exit 1
fi

exit 0
