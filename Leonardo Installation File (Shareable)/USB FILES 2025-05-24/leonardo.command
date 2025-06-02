        print_error "Failed to create macOS launcher script. Check permissions on USB drive."
        return 1
    fi
#!/usr/bin/env bash
SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)";
cd "\$SCRIPT_DIR" || { printf "%s\\n" "ERROR: Could not change to script directory. Exiting."; exit 1; };

C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN="";
if command -v tput >/dev/null 2>&1 && tput setaf 1 >/dev/null 2>&1; then
    C_RESET=\$(tput sgr0); C_BOLD=\$(tput bold); C_RED=\$(tput setaf 1); C_GREEN=\$(tput setaf 2);
    C_YELLOW=\$(tput setaf 3); C_BLUE=\$(tput setaf 4); C_CYAN=\$(tput setaf 6);
fi;

printf "%b\\n" "\${C_BOLD}\${C_GREEN}🚀 Starting Leonardo AI USB Environment (macOS)...\${C_RESET}";

printf "%b\\n" "\${C_BLUE}Setting up environment variables...\${C_RESET}";
${common_mac_linux_data_dir_setup}
export OLLAMA_HOST="127.0.0.1:11434";

OLLAMA_BIN="\$SCRIPT_DIR/runtimes/mac/bin/ollama";
if [ ! -f "\$OLLAMA_BIN" ]; then printf "%b\\n" "\${C_RED}❌ Error: Ollama binary not found at \$OLLAMA_BIN\${C_RESET}"; read -p "Press Enter to exit."; exit 1; fi;
if [ ! -x "\$OLLAMA_BIN" ]; then
    printf "%b\\n" "\${C_YELLOW}⏳ Ollama binary not executable, attempting to chmod +x...\${C_RESET}";
    chmod +x "\$OLLAMA_BIN" || { printf "%b\\n" "\${C_RED}❌ Error: Failed to make Ollama binary executable. Check permissions.\${C_RESET}"; read -p "Press Enter to exit."; exit 1; };
fi;

# Model selection logic - written directly for bash 3.x compatibility
if [ ${#model_array_for_bash_heredoc[@]} -gt 1 ]; then
    printf "%b\\n" "\${C_BLUE}Available models:\${C_RESET}"
    ${model_options_for_select_heredoc}
    read -r -p "\$(printf "%b" "\${C_CYAN}➡️  Select model (number) or press Enter for default ($first_model_for_cli_default): \${C_RESET}")" MODEL_CHOICE_NUM
    SELECTED_MODEL="$first_model_for_cli_default"

    # Initialize array in bash 3.x compatible way
    _models_for_selection=()
    for model in "${model_array_for_bash_heredoc[@]}"; do
        _models_for_selection+=("$model")
    done

    if [[ "\$MODEL_CHOICE_NUM" =~ ^[0-9]+$ ]] && [ "\$MODEL_CHOICE_NUM" -ge 1 ] && [ "\$MODEL_CHOICE_NUM" -le ${#model_array_for_bash_heredoc[@]} ]; then
        idx=\$((MODEL_CHOICE_NUM-1))
        SELECTED_MODEL="\${_models_for_selection[\$idx]}"
    fi
    printf "%b\\n" "\${C_GREEN}Using model: \$SELECTED_MODEL\${C_RESET}"
    export LEONARDO_DEFAULT_MODEL="\$SELECTED_MODEL"
elif [ ${#model_array_for_bash_heredoc[@]} -eq 1 ]; then
    SELECTED_MODEL="${model_array_for_bash_heredoc[0]}"
    printf "%b\\n" "\${C_GREEN}Using model (only one available): \$SELECTED_MODEL\${C_RESET}"
    export LEONARDO_DEFAULT_MODEL="\$SELECTED_MODEL"
else
    printf "%b\\n" "\${C_RED}No models found or configured. Cannot select a model.\${C_RESET}"
    read -p "Press Enter to exit."
    exit 1
fi

printf "%b\\n" "\${C_BLUE}Starting Ollama server in the background...\${C_RESET}";
LOG_FILE="\$SCRIPT_DIR/Data/logs/ollama_server_mac.log";
env -i HOME="\$HOME" USER="\$USER" PATH="\$PATH:/usr/local/bin:/opt/homebrew/bin" OLLAMA_MODELS="\$OLLAMA_MODELS" OLLAMA_TMPDIR="\$OLLAMA_TMPDIR" OLLAMA_HOST="\$OLLAMA_HOST" "\$OLLAMA_BIN" $common_ollama_serve_command > "\$LOG_FILE" 2>&1 &
OLLAMA_PID=\$!;
printf "%b\\n" "\${C_GREEN}Ollama server started with PID \$OLLAMA_PID. Log: \$LOG_FILE\${C_RESET}";
printf "%b\\n" "\${C_BLUE}Waiting a few seconds for the server to initialize...\${C_RESET}"; sleep 5;

if ! curl --silent --fail "http://\${OLLAMA_HOST}/api/tags" > /dev/null 2>&1 && ! ps -p \$OLLAMA_PID > /dev/null; then
    printf "%b\\n" "\${C_RED}❌ Error: Ollama server failed to start or is not responding. Check \$LOG_FILE for details.\${C_RESET}";
    printf "%b\\n" "   Ensure no other Ollama instance is conflicting on port 11434.";
    read -p "Press Enter to exit."; exit 1;
fi;
printf "%b\\n" "\${C_GREEN}Ollama server seems to be running. ✅\${C_RESET}";

WEBUI_PATH="\$SCRIPT_DIR/webui/index.html";
printf "%b\\n" "\${C_BLUE}Attempting to open Web UI: file://\$WEBUI_PATH\${C_RESET}";
open "file://\$WEBUI_PATH" &

printf "\\n";
printf "%b\\n" "\${C_BOLD}\${C_GREEN}✨ Leonardo AI USB is now running! ✨\${C_RESET}";
printf "%b\\n" "  - Ollama Server PID: \${C_BOLD}\$OLLAMA_PID\${C_RESET}";
printf "%b\\n" "  - Default Model for CLI/WebUI: \${C_BOLD}\$SELECTED_MODEL\${C_RESET} (WebUI allows changing this)";
printf "%b\\n" "  - Web UI should be open in your browser (or open manually: \${C_GREEN}file://\$WEBUI_PATH\${C_RESET}).";
printf "%b\\n" "  - To stop the Ollama server, close this terminal window or run: \${C_YELLOW}kill \$OLLAMA_PID\${C_RESET}";
printf "\\n";
printf "%b\\n" "\${C_YELLOW}This terminal window is keeping the Ollama server alive.";
printf "%b\\n" "Close this window or press Ctrl+C to stop the server.\${C_RESET}";

trap 'printf "\\n%b\\n" "\${C_BLUE}Shutting down Ollama server (PID \$OLLAMA_PID)..."; kill \$OLLAMA_PID 2>/dev/null; wait \$OLLAMA_PID 2>/dev/null; printf "%b\\n" "\${C_GREEN}Ollama server stopped.\${C_RESET}"' EXIT TERM INT;

wait \$OLLAMA_PID;
printf "%b\\n" "\${C_BLUE}Ollama server (PID \$OLLAMA_PID) has been stopped.\${C_RESET}";
printf "%b\\n" "\${C_GREEN}Leonardo AI USB session ended.\${C_RESET}";
