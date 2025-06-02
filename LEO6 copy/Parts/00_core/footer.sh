# ==============================================================================
# Leonardo AI Universal - Core Footer
# ==============================================================================
# Description: Script footer that ensures main function is called at the end
# Author: Leonardo AI Team
# Version: 6.0.0
# ==============================================================================

# Call main function if script is executed directly (moved to end of script)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
