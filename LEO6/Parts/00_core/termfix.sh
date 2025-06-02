# ==============================================================================
# Leonardo AI Universal - Terminal Environment Fix
# ==============================================================================
# Description: Ensures TERM variable is set to avoid errors
# Author: Leonardo AI Team
# Version: 6.0.0
# ==============================================================================

# Set default TERM if not defined
if [[ -z "$TERM" ]]; then
    export TERM=xterm-256color
fi
