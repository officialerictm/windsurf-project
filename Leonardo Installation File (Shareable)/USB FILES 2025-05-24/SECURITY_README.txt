================================================================================
🛡️ Leonardo AI USB - IMPORTANT SECURITY & USAGE GUIDELINES 🛡️
================================================================================

Thank you for using the Leonardo AI USB Maker! This portable AI environment
is designed for ease of use and experimentation. However, please be mindful
of the following security and usage considerations:

1.  **Source of Software:**
    *   The Ollama binaries are downloaded from the official Ollama GitHub
      repository (https://github.com/ollama/ollama) or from fallback URLs
      provided in the script if the GitHub API fails.
    *   The AI models are pulled from Ollama's model library (ollama.com/library)
      via your host machine's Ollama instance or imported from a local GGUF file
      you provide.
    *   This script itself (\`$SCRIPT_SELF_NAME\`, Version: $SCRIPT_VERSION) is provided as-is. Review it before running if you
      have any concerns.

2.  **Running on Untrusted Computers:**
    *   BE CAUTIOUS when plugging this USB into computers you do not trust.
      While the scripts aim to be self-contained, the act of running any
      executable carries inherent risks depending on the host system's state.
    *   The Ollama server runs locally on the computer where the USB is used.
      It typically binds to 127.0.0.1 (localhost), meaning it should only be
      accessible from that same computer.

3.  **AI Model Behavior & Content:**
    *   Large Language Models (LLMs) can sometimes produce inaccurate, biased,
      or offensive content. Do not rely on model outputs for critical decisions
      without verification.
    *   The models included are general-purpose or specialized (like coding
      assistants) and reflect the data they were trained on.

4.  **Data Privacy:**
    *   When you interact with the models via the Web UI or CLI, your prompts
      and the AI's responses are processed locally on the computer running
      the Ollama server from the USB.
    *   No data is sent to external servers by the core Ollama software or
      these launcher scripts during model interaction, UNLESS a model itself
      is designed to make external calls (which is rare for standard GGUF models).
    *   The \`OLLAMA_TMPDIR\` is set to the \`Data/tmp\` folder on the USB.
      Temporary files related to model operations might be stored there.

5.  **Filesystem and Permissions:**
    *   The USB is typically formatted as exFAT for broad compatibility.
    *   The script attempts to set appropriate ownership and permissions for
      the files and directories it creates on the USB.
    *   Launcher scripts (.sh, .command) are made executable.

6.  **Integrity Verification:**
    *   A \`verify_integrity.sh\` (for Linux/macOS) and \`verify_integrity.bat\`
      (for Windows) script is included on the USB.
    *   These scripts generate SHA256 checksums for key runtime files and the
      launcher scripts themselves.
    *   You can run these verification scripts to check if the core files have
      been modified since creation.
    *   The initial checksums are stored in \`checksums.sha256.txt\` on the USB.
      PROTECT THIS FILE. If it's altered, verification is meaningless.
      Consider backing it up to a trusted location.

7.  **Script Operation (\`$SCRIPT_SELF_NAME\` - This Script):**
    *   This script requires \`sudo\` (administrator) privileges for:
        *   Formatting the USB drive.
        *   Mounting/unmounting the USB drive.
        *   Copying files (Ollama binaries, models) to the USB, especially if
          the host's Ollama models are in a system location.
        *   Crafting directories and setting permissions on the USB.
    *   It temporarily downloads Ollama binaries to a system temporary directory
      (e.g., via \`mktemp -d\`) which is cleaned up on script exit.

8.  **No Warranty:**
    *   This tool and the resulting USB environment are provided "AS IS,"
      without warranty of any kind, express or implied. Use at your own risk.

**Troubleshooting Common Issues:**

*   **Launcher script doesn't run (Permission Denied on Linux/macOS):**
    Open a terminal in the USB drive's root directory and run:
    \`chmod +x ${USER_LAUNCHER_NAME_BASE}.sh\` (for Linux)
    \`chmod +x ${USER_LAUNCHER_NAME_BASE}.command\` (for macOS)
*   **Ollama Server Fails to Start (in Launcher Window):**
    Check the log file mentioned in the launcher window (usually in Data/logs/ on the USB)
    for error messages from Ollama. The host system might be missing a
    runtime dependency for Ollama (though the main script tries to check these).
    Ensure no other Ollama instance is running and using port 11434 on the host.
*   **macOS: ".command" file from an unidentified developer:**
    If you double-click \`${USER_LAUNCHER_NAME_BASE}.command\` and macOS prevents it from opening,
    you might need to:
    1. Right-click (or Control-click) the \`${USER_LAUNCHER_NAME_BASE}.command\` file.
    2. Select "Open" from the context menu.
    3. A dialog will appear. Click the "Open" button in this dialog.
    Alternatively, you can adjust settings in "System Settings" > "Privacy & Security".
*   **Web UI doesn't open or models aren't listed:**
    Ensure the Ollama server started correctly (check its terminal window if visible,
    or the log file in Data/logs/). If models are missing, they might not have copied correctly,
    or the manifests on the USB are corrupted. Try the "Repair/Refresh" option
    from the main \`$SCRIPT_SELF_NAME\` script.

Stay curious, experiment responsibly, and enjoy your portable AI!

---
(Generated by $SCRIPT_SELF_NAME Version: $SCRIPT_VERSION)
Last Updated: $(date)
