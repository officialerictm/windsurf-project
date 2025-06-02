#!/bin/bash

# This script tests and fixes ANSI color display issues

# Method 1: Standard escape sequences (may not work in all environments)
echo "Method 1: Standard method"
echo -e "\033[31mThis should be red\033[0m"
echo -e "\033[1;34mThis should be bold blue\033[0m"

# Method 2: $'...' syntax (more reliable)
echo -e "\nMethod 2: Using $'...' syntax"
RED=$'\e[31m'
BLUE=$'\e[1;34m'
RESET=$'\e[0m'
echo "${RED}This should be red${RESET}"
echo "${BLUE}This should be bold blue${RESET}"

# Method 3: Using printf directly (most reliable)
echo -e "\nMethod 3: Using printf directly"
printf "\e[31mThis should be red\e[0m\n"
printf "\e[1;34mThis should be bold blue\e[0m\n"

# Method 4: Using tput (terminal-aware)
echo -e "\nMethod 4: Using tput"
TPUT_RED=$(tput setaf 1)
TPUT_BLUE=$(tput setaf 4)
TPUT_BOLD=$(tput bold)
TPUT_RESET=$(tput sgr0)
echo "${TPUT_RED}This should be red${TPUT_RESET}"
echo "${TPUT_BOLD}${TPUT_BLUE}This should be bold blue${TPUT_RESET}"

echo -e "\nIf you don't see colors above, run this with:"
echo "env TERM=xterm ./color_test.sh"
