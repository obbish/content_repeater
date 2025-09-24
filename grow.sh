TOTAL_BLOCKS=$((DISK_LENGTH / PHYSICAL_BLOCKSIZE))
# This evaluates to: 250059350016 / 4096 = 61,049,646

for (( i=1; i<=TOTAL_BLOCKS; i++ )); do
    # This loop tries to count from 1 all the way to 61,049,646
    if (( TOTAL_BLOCKS % i == 0 )); then
        # ...
    fi
done
