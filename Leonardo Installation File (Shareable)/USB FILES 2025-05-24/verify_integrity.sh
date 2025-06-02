#!/usr/bin/env bash
# Initialize console colors with safe fallbacks
C_RESET=$(tput sgr0 2>/dev/null || echo "") 
C_BOLD=$(tput bold 2>/dev/null || echo "") 
C_RED=$(tput setaf 1 2>/dev/null || echo "") 
C_GREEN=$(tput setaf 2 2>/dev/null || echo "") 
C_YELLOW=$(tput setaf 3 2>/dev/null || echo "") 
C_CYAN=$(tput setaf 6 2>/dev/null || echo "")
C_DIM=$(tput dim 2>/dev/null || echo "")

printf "%b\n" "${C_BOLD}${C_GREEN}Verifying integrity of key files on Leonardo AI USB...${C_RESET}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || { printf "%b\n" "${C_RED}ERROR: Could not change to script directory.${C_RESET}"; exit 1; }

CHECKSUM_FILE="checksums.sha256.txt"
if [ ! -f "$CHECKSUM_FILE" ]; then 
    printf "%b\n" "${C_RED}ERROR: $CHECKSUM_FILE not found! Cannot verify integrity.${C_RESET}"
    exit 1
fi

TEMP_CURRENT_CHECKSUMS="$(mktemp)"
trap 'rm -f "$TEMP_CURRENT_CHECKSUMS"' EXIT

# Find appropriate SHA256 command
SHA_CMD=""
if command -v shasum &>/dev/null; then 
    SHA_CMD="shasum -a 256"
elif command -v sha256sum &>/dev/null; then 
    SHA_CMD="sha256sum"
else 
    printf "%b\n" "${C_RED}ERROR: Neither shasum nor sha256sum found. Cannot verify.${C_RESET}"
    exit 1
fi

printf "%b\n" "${C_YELLOW}Reading stored checksums and calculating current ones...${C_RESET}"
all_ok=true
files_checked=0
files_failed=0
files_missing=0

while IFS= read -r line || [[ -n "$line" ]]; do
    expected_checksum=$(echo "$line" | awk '{print $1}')
    filepath_raw=$(echo "$line" | awk '{print $2}')
    filepath=${filepath_raw#\*}

    if [ -z "$filepath" ]; then continue; fi

    printf "  Verifying ${C_CYAN}%s${C_RESET}..." "$filepath"
    if [ -f "$filepath" ]; then
        # This was the critical missing part - execute SHA_CMD on the file
        current_checksum_line=$($SHA_CMD "$filepath" 2>/dev/null)
        current_checksum=$(echo "$current_checksum_line" | awk '{print $1}')

        if [ "$current_checksum" == "$expected_checksum" ]; then
            printf "\r  Verifying ${C_CYAN}%s${C_RESET}... ${C_GREEN}OK${C_RESET}          \n" "$filepath"
        else
            printf "\r  Verifying ${C_CYAN}%s${C_RESET}... ${C_RED}FAIL${C_RESET}        \n" "$filepath"
            printf "    ${C_DIM}Expected: %s${C_RESET}\n" "$expected_checksum"
            printf "    ${C_DIM}Current:  %s${C_RESET}\n" "$current_checksum"
            all_ok=false
            ((files_failed++))
        fi
        ((files_checked++))
    else
        printf "\r  Verifying ${C_CYAN}%s${C_RESET}... ${C_YELLOW}MISSING${C_RESET}    \n" "$filepath"
        all_ok=false
        ((files_missing++))
    fi
done < "$CHECKSUM_FILE"

# Summary report
if $all_ok; then
    printf "\n%b\n" "${C_GREEN}✅ SUCCESS: All $files_checked files verified successfully.${C_RESET}"
else
    printf "\n%b\n" "${C_RED}❌ FAILURE: Integrity check failed.${C_RESET}"
    if [ $files_failed -gt 0 ]; then
        printf "    - %d file(s) had checksum mismatches.\n" $files_failed
    fi
    if [ $files_missing -gt 0 ]; then
        printf "    - %d file(s) are missing.\n" $files_missing
    fi
    printf "   Some files may have been altered or are missing.\n"
fi

printf "Verification complete.\n"
