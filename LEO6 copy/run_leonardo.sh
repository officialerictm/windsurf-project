#!/bin/bash
# Leonardo AI Universal Seed Launcher
# This script properly launches the Universal Seed script

# Set default TERM if not defined
if [[ -z "$TERM" ]]; then
    export TERM=xterm-256color
fi

# Launch the main script with arguments
source "$(dirname "$0")/leonardo_universal_seed.sh"
main "$@"
