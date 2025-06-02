@ECHO OFF
REM Leonardo AI USB Windows Launcher
TITLE Leonardo AI USB Launcher
COLOR 0A
CLS
ECHO ^<--------------------------------------------------------------------^>
ECHO ^|         Leonardo AI USB Environment (Windows) - Starting...        ^|
ECHO ^<--------------------------------------------------------------------^>
CD /D "%~dp0"

ECHO Setting up environment variables...
SET OLLAMA_MODELS=%~dp0.ollama\models\r\nSET OLLAMA_TMPDIR=%~dp0Data\tmp\r\nMKDIR "%~dp0Data\tmp" 2>NUL\r\nMKDIR "%~dp0Data\logs" 2>NUL
SET OLLAMA_HOST=127.0.0.1:11434

SET OLLAMA_BIN=%~dp0runtimes\win\bin\ollama.exe
IF NOT EXIST "%OLLAMA_BIN%" (
    COLOR 0C
    ECHO ^>^> ERROR: Ollama binary not found at %OLLAMA_BIN%
    PAUSE
    EXIT /B 1
)
ECHO Available models:\r\nECHO   1) llama3:8b\r\nECHO   2) phi3:mini\r\nSET /P MODEL_CHOICE_NUM="Select model (number) or press Enter for default (llama3:8b): "\r\nSET SELECTED_MODEL=llama3:8b\r\nIF "%MODEL_CHOICE_NUM%"=="1" SET SELECTED_MODEL=llama3:8b\r\nIF "%MODEL_CHOICE_NUM%"=="2" SET SELECTED_MODEL=phi3:mini\r\nECHO Using model: %SELECTED_MODEL%\r\nSET LEONARDO_DEFAULT_MODEL=%SELECTED_MODEL%\r\n

ECHO Starting Ollama server in a new window...
START "Ollama Server (Leonardo AI USB)" /D "%~dp0runtimes\win\bin" "%OLLAMA_BIN%" ollama serve

ECHO Waiting a few seconds for the server to initialize...
PING 127.0.0.1 -n 8 > NUL

ECHO Checking if Ollama server process is running...
TASKLIST /FI "IMAGENAME eq ollama.exe" /NH | FIND /I "ollama.exe" > NUL
IF ERRORLEVEL 1 (
    COLOR 0C
    ECHO ^>^> ERROR: Ollama server process not detected after startup.
    ECHO    Check the new "Ollama Server" window for error messages.
    ECHO    Ensure no other Ollama instance is conflicting on port 11434.
    PAUSE
    EXIT /B 1
)
COLOR 0A
ECHO Ollama server process found. ^<^<

SET WEBUI_PATH_RAW=%~dp0webui\index.html
SET WEBUI_PATH_URL=%WEBUI_PATH_RAW:\=/%
ECHO Attempting to open Web UI: file:///%WEBUI_PATH_URL%
START "" "file:///%WEBUI_PATH_URL%"

ECHO.
ECHO ^<--------------------------------------------------------------------^>
ECHO ^|                 ✨ Leonardo AI USB is now running! ✨              ^|
ECHO ^|--------------------------------------------------------------------^|
ECHO ^| - Ollama Server is running in a separate window.                   ^|
ECHO ^| - Default Model for CLI/WebUI: %SELECTED_MODEL%                    ^|
ECHO ^|   (WebUI allows changing this from available models on USB)        ^|
ECHO ^| - Web UI should be open in your browser.                           ^|
ECHO ^|   (If not, manually open: file:///%WEBUI_PATH_URL%)                ^|
ECHO ^| - To stop: Close the "Ollama Server" window AND this window.     ^|
ECHO ^<--------------------------------------------------------------------^>
ECHO.
ECHO This launcher window can be closed. The Ollama server will continue
ECHO running in its own window until that "Ollama Server" window is closed.
PAUSE
EXIT /B 0
