#!/bin/bash

# Ensure the source file exists
if [ ! -f "output.bin" ]; then
    echo "Error: output.bin not found."
    exit 1
fi

echo "Starting continuous write process. Press Ctrl+C to stop."

# This is the outer loop that will repeat the entire dd process.
while :; do
    echo "$(date): Starting new dd cycle."

    # The pipeline:
    # The left side is a subshell (...) running a 'cat' loop.
    # This 'while cat ...' loop will terminate (and the subshell will exit)
    # when 'cat' fails, e.g., due to SIGPIPE after dd closes the pipe.
    (
        while cat output.bin; do
            # The colon ':' is a shell no-op (does nothing).
            # This loop continues as long as 'cat' exits successfully.
            :
        done
        # You can add a log here to see when the cat-loop subshell exits
        # echo "$(date): Cat loop subshell finished." >&2
    ) | sudo dd of=/dev/sdb bs=1048576 status=progress count=1907729 iflag=fullblock oflag=direct conv=fdatasync
    # Using count=4 for debugging as per your example.
    # Remember to change '/dev/sda' and 'count' back to your original values for production.

    # Capture the exit status of the pipeline.
    # Without 'set -o pipefail', this is typically the exit status of the last command (dd).
    # If 'set -o pipefail' is active, it's the status of the first command in the pipe to fail.
    pipeline_exit_status=$?

    echo "$(date): dd process and cat loop subshell have finished."
    echo "$(date): Pipeline exit status: $pipeline_exit_status."

    # Check if dd (or the pipeline) was successful.
    # A successful dd usually exits with 0.
    # If cat died from SIGPIPE (e.g. 141) and pipefail is on, pipeline_exit_status might be 141.
    # For robustness, you might primarily care that dd completed its task,
    # but for the loop to continue, the pipeline just needs to terminate.
    if [ $pipeline_exit_status -ne 0 ]; then
        # If dd itself failed with an error (not just cat getting SIGPIPE),
        # or if pipefail caused a non-zero status you want to stop on.
        echo "$(date): Pipeline exited with status $pipeline_exit_status. Halting loop."
        break # Exit the outer 'while :;' loop
    fi

    echo "$(date): Restarting dd cycle..."
    # sleep 1 # You can add a small delay here if you want before restarting.
done

echo "$(date): Script loop terminated."
