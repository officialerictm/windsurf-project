#!/bin/bash
# ==============================================================================
# Leonardo AI USB Maker - Core Header
# ==============================================================================
# Description: Main script header and initialization
# Author: Leonardo AI Team
# Version: 5.0.0
# License: MIT
# ==============================================================================

# Set umask for secure file creation
umask 077

# Script information
SCRIPT_TITLE="Leonardo AI USB Maker"
SCRIPT_VERSION="5.0.0"
SCRIPT_AUTHOR="Eric™ & The Leonardo AI Team"
SCRIPT_LICENSE="MIT"
SCRIPT_REPO="https://github.com/leonardo-ai/usb-maker"

# Set script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT_NAME}"
