@ECHO OFF\r
REM Leonardo AI USB - Integrity Verification (Windows)\r
TITLE Leonardo AI USB - Integrity Check\r
COLOR 0A\r
CLS\r
ECHO Verifying integrity of key files on Leonardo AI USB...\r
CD /D "%~dp0"\r
\r
SET CHECKSUM_FILE=checksums.sha256.txt\r
IF NOT EXIST "%CHECKSUM_FILE%" (\r
    COLOR 0C\r
    ECHO ERROR: %CHECKSUM_FILE% not found! Cannot verify integrity.\r
    PAUSE\r
    EXIT /B 1\r
)\r
\r
WHERE certutil >nul 2>nul\r
IF %ERRORLEVEL% NEQ 0 (\r
    COLOR 0C\r
    ECHO ERROR: certutil.exe not found. Cannot verify checksums on Windows.\r
    ECHO Certutil is usually part of Windows. If missing, your system might have issues.\r
    PAUSE\r
    EXIT /B 1\r
)\r
\r
ECHO Reading stored checksums and calculating current ones...\r
SETLOCAL ENABLEDELAYEDEXPANSION\r
SET ALL_OK=1\r
SET FILES_CHECKED=0\r
SET FILES_FAILED=0\r
SET FILES_MISSING=0\r
\r
FOR /F "usebackq tokens=1,*" %%A IN ("%CHECKSUM_FILE%") DO (\r
    SET EXPECTED_CHECKSUM=%%A\r
    SET FILEPATH_RAW=%%B\r
    IF "!FILEPATH_RAW:~0,1!"=="*" (SET FILEPATH_CLEAN=!FILEPATH_RAW:~1!) ELSE (SET FILEPATH_CLEAN=!FILEPATH_RAW!)\r
    FOR /F "tokens=* delims= " %%F IN ("!FILEPATH_CLEAN!") DO SET FILEPATH_TRIMMED=%%F\r
    \r
    IF DEFINED FILEPATH_TRIMMED (\r
        ECHO Verifying !FILEPATH_TRIMMED!...\r
        IF EXIST "!FILEPATH_TRIMMED!" (\r
            SET CURRENT_CHECKSUM=\r
            FOR /F "skip=1 tokens=*" %%S IN ('certutil -hashfile "!FILEPATH_TRIMMED!" SHA256 2^>NUL') DO (\r
                IF NOT DEFINED CURRENT_CHECKSUM SET "CURRENT_CHECKSUM=%%S"\r
            )\r
            SET CURRENT_CHECKSUM=!CURRENT_CHECKSUM: =!\r
            \r
            IF DEFINED CURRENT_CHECKSUM (\r
                IF /I "!CURRENT_CHECKSUM!"=="!EXPECTED_CHECKSUM!" (\r
                    ECHO   OK: !FILEPATH_TRIMMED!\r
                ) ELSE (\r
                    COLOR 0C\r
                    ECHO   FAIL: !FILEPATH_TRIMMED!\r
                    ECHO     Expected: !EXPECTED_CHECKSUM!\r
                    ECHO     Current:  !CURRENT_CHECKSUM!\r
                    COLOR 0A\r
                    SET ALL_OK=0\r
                    SET /A FILES_FAILED+=1\r
                )\r
            ) ELSE (\r
                COLOR 0E\r
                ECHO   ERROR: Could not calculate checksum for !FILEPATH_TRIMMED!.\r
                COLOR 0A\r
                SET ALL_OK=0\r
                SET /A FILES_FAILED+=1\r
            )\r
            SET /A FILES_CHECKED+=1\r
        ) ELSE (\r
            COLOR 0E\r
            ECHO   WARNING: File '!FILEPATH_TRIMMED!' listed in checksums not found. Skipping.\r
            COLOR 0A\r
            SET ALL_OK=0\r
            SET /A FILES_MISSING+=1\r
        )\r
    )\r
)\r
\r
ECHO.\r
IF "%ALL_OK%"=="1" (\r
    COLOR 0A\r
    ECHO ✅ SUCCESS: All %FILES_CHECKED% key files verified successfully!\r
) ELSE (\r
    COLOR 0C\r
    ECHO ❌ FAILURE: Integrity check failed.\r
    IF %FILES_FAILED% GTR 0 ECHO    - %FILES_FAILED% file(s) had checksum mismatches or errors.\r
    IF %FILES_MISSING% GTR 0 ECHO    - %FILES_MISSING% file(s) listed in checksums.sha256.txt were not found.\r
)\r
ECHO Verification complete.\r
ENDLOCAL\r
PAUSE\r
EXIT /B 0\r
