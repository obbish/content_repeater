#!/bin/bash

# Define the target size in bytes (1 MiB)
target_size=1048576

# Define the initial source file name
initial_source="source.txt"
small_file="small_file.bin"
output_file="output.bin"

# Copy the initial source to the working small_file
cp "$initial_source" "$small_file"
original_source_size=$(stat -c "%s" "$small_file")
echo "Original source file size: $original_source_size bytes"

found_suitable=0
best_segment_size=0
best_num_copies=0
initial_pad_needed=0

# Iterate through potential segment sizes (divisors of target_size)
for segment_size in $(seq "$original_source_size" "$target_size"); do
  if [ $((target_size % segment_size)) -eq 0 ]; then
    num_copies=$((target_size / segment_size))
    if [ "$num_copies" -gt 1 ]; then
      initial_pad_needed=$((segment_size - original_source_size))
      echo "Found suitable configuration:"
      echo "Number of copies: $num_copies"
      echo "Segment size (padded source): $segment_size bytes"
      echo "Initial padding needed: $initial_pad_needed bytes"
      best_segment_size="$segment_size"
      best_num_copies="$num_copies"
      found_suitable=1
      break # Found the first (smallest segment size >= original, maximizing copies)
    fi
  fi
done

if [ "$found_suitable" -eq 0 ]; then
  echo "Error: Could not find a suitable configuration for even spacing with more than one copy."
  exit 1
fi

# Create the final output file
rm -f "$output_file"

# Create the initially padded source file
{ head -c "$initial_pad_needed" /dev/zero; cat "$initial_source"; } > "padded_$small_file"
mv "padded_$small_file" "$small_file"

# Loop to copy the (initially padded) source data
for i in $(seq 1 "$best_num_copies"); do
  cat "$small_file" >> "$output_file"
done

# Verify the size of the output file
output_size=$(stat -c "%s" "$output_file")
echo "Created '$output_file' with size: $output_size bytes."

if [ "$output_size" -eq "$target_size" ]; then
  echo "Successfully created a 1 MiB file with $best_num_copies evenly sized segments (initially padded data)."
else
  echo "Warning: The output file size is not exactly 1 MiB."
fi

exit 0
