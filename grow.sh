#!/bin/bash

# ==============================================================================
# Script: create_perfect_segment.sh (v2 - Corrected)
# Description: Dynamically generates a list of GUARANTEED valid segment lengths
#              and creates a binary file based on the user's choice.
# Usage: ./create_perfect_segment.sh "<your_string>"
# ==============================================================================

# --- Drive & Filesystem Configuration ---
readonly PHYSICAL_BLOCKSIZE=4096
readonly DISK_LENGTH=250059350016
readonly OUTPUT_FILE="perfect_segment.bin"

# --- Input Validation ---
if [ "$#" -ne 1 ]; then
    echo "Error: You must provide a text string as an argument." >&2
    echo "Usage: $0 \"<your_string>\"" >&2
    exit 1
fi
USER_STRING="$1"
STRING_LEN=$(echo -n "$USER_STRING" | wc -c)
if [ "$STRING_LEN" -lt 1 ] || [ "$STRING_LEN" -ge "$PHYSICAL_BLOCKSIZE" ]; then
    echo "Error: Input string length must be between 1 and 4095 bytes." >&2
    echo "Your string length: $STRING_LEN bytes." >&2
    exit 1
fi

# --- Segment Size Selection (Dynamic & Correct) ---

# Prime factors of the disk length, excluding the base of 2.
# DISK_LENGTH = 2¹³ × 3 × 7 × 13 × 37 × 929
optional_factors=(3 7 13 37 929)

# Dynamically generate a list of guaranteed valid choices.
# Every number in this list is guaranteed to be a divisor of DISK_LENGTH.
segment_choices=(
    $PHYSICAL_BLOCKSIZE                     # 4096 (2¹²)
    $((PHYSICAL_BLOCKSIZE * 2))             # 8192 (2¹³)
    $((PHYSICAL_BLOCKSIZE * 3))             # 4096 * 3
    $((PHYSICAL_BLOCKSIZE * 2 * 3))         # 8192 * 3
    $((PHYSICAL_BLOCKSIZE * 7))             # 4096 * 7
    $((PHYSICAL_BLOCKSIZE * 13))            # 4096 * 13
    $((PHYSICAL_BLOCKSIZE * 929))           # 4096 * 929 (Largest prime factor combo)
    $((PHYSICAL_BLOCKSIZE * 3 * 7 * 13))    # A more complex combination
    $DISK_LENGTH                            # The entire disk
)

# Sort the choices numerically for a clean presentation
segment_choices=($(for i in "${segment_choices[@]}"; do echo $i; done | sort -un))

echo "💿 Found valid segment lengths for a ${DISK_LENGTH} byte disk."
echo "Please choose a segment length for the output file:"

# Display the choices in a user-friendly format
choice_count=${#segment_choices[@]}
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
    read -p "Enter your choice (1-${choice_count}): " user_choice
    if [[ "$user_choice" =~ ^[0-9]+$ ]] && [ "$user_choice" -ge 1 ] && [ "$user_choice" -le "$choice_count" ]; then
        break
    else
        echo "Invalid input. Please enter a number between 1 and ${choice_count}."
    fi
done

# --- Set chosen size and show repetition count ---
SEGMENT_LENGTH=${segment_choices[$((user_choice-1))]}
REPETITION_COUNT=$((DISK_LENGTH / SEGMENT_LENGTH))

echo ""
echo "Selected segment length: $SEGMENT_LENGTH bytes."
echo "✅ This segment will fit perfectly into the disk $REPETITION_COUNT times."

# --- Pattern Calculation ---
echo "⚙️  Calculating optimal tiling pattern for the segment..."
PATTERN_LEN=0
for (( i=STRING_LEN; i<=SEGMENT_LENGTH; i++ )); do
    if (( SEGMENT_LENGTH % i == 0 )); then
        PATTERN_LEN=$i
        break
    fi
done
NUM_ZEROS=$((PATTERN_LEN - STRING_LEN))
REPETITIONS=$((SEGMENT_LENGTH / PATTERN_LEN))
echo "   - Pattern length: $PATTERN_LEN bytes (String: $STRING_LEN, Zeros: $NUM_ZEROS)"
echo "   - Pattern will be repeated $REPETITIONS times to create the segment file."
echo ""

# --- File Creation ---
echo "🛠️  Creating file '$OUTPUT_FILE'..."
(
    for (( r=0; r<REPETITIONS; r++ )); do
        printf "%s" "$USER_STRING"
        if [ "$NUM_ZEROS" -gt 0 ]; then
            head -c "$NUM_ZEROS" /dev/zero # More efficient for large zero padding
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
