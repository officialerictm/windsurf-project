#!/bin/bash
# ==============================================================================
# Leonardo AI Universal - Core Header
# ==============================================================================
# Description: Main script header and initialization
# Author: Leonardo AI Team
# Version: 6.0.0
# License: MIT
# ==============================================================================

# Set umask for secure file creation
umask 077

# Script information
SCRIPT_TITLE="Leonardo AI Universal"
SCRIPT_VERSION="6.0.0"
SCRIPT_AUTHOR="Eric™ & The Leonardo AI Team"
SCRIPT_LICENSE="MIT"
SCRIPT_REPO="https://github.com/leonardo-ai/universal-deployer"
SCRIPT_SELF_NAME=$(basename "$0")

# Set script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT_NAME}"

# Track installation start time
INSTALL_START_TIME=$(date +%s)

# Welcome message (will be displayed by UI functions later)
WELCOME_MESSAGE="Welcome to Leonardo AI Universal - the multi-environment LLM deployment system"
