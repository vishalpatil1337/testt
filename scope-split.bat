@echo off
setlocal enabledelayedexpansion
cls
color 0B

REM ===============================================================================
REM                        Nmap Automation Framework
REM                           Version 2.0
REM ===============================================================================

:INITIALIZE_VARS
set "VERSION=2.0"
set "TOOL_NAME=Nmap Automation Framework"
set "IPS_PER_FILE=20"
set "SUBNETS_PER_FILE=3"
set "INPUT_FILE=scope.txt"
set "BASE_DIR=%~dp0"
set "OUTPUT_DIR=%BASE_DIR%output"
set "TEMP_DIR=%BASE_DIR%temp"
set "LOGS_DIR=%OUTPUT_DIR%\logs"
set "COMMANDS_DIR=%OUTPUT_DIR%\commands"
set "CONFIG_DIR=%BASE_DIR%config"

:SHOW_BANNER
echo ===============================================================================
echo                          %TOOL_NAME% v%VERSION%
echo ===============================================================================
echo.

:CREATE_DIRECTORIES
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"
if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%"
if not exist "%COMMANDS_DIR%" mkdir "%COMMANDS_DIR%"
if not exist "%CONFIG_DIR%" mkdir "%CONFIG_DIR%"

:CHECK_INPUT_FILE
echo [*] Validating Environment...
echo    ^> Checking for input file: %INPUT_FILE%
if not exist "%INPUT_FILE%" (
    echo.
    echo [!] Error: %INPUT_FILE% not found!
    echo [i] Example format for scope.txt:
    echo    IP Addresses:        Subnets:
    echo    192.168.1.1         192.168.0.0/24
    echo    10.0.0.1            10.0.0.0/16
    echo.
    pause
    exit /b 1
)

:PROCESS_DUPLICATES
echo [*] Processing input file...
echo    ^> Removing duplicates and sorting entries
type nul > "%TEMP_DIR%\temp_ips.txt"
type nul > "%TEMP_DIR%\temp_subnets.txt"
type nul > "%TEMP_DIR%\unique_ips.txt"
type nul > "%TEMP_DIR%\unique_subnets.txt"

for /f "tokens=*" %%a in (%INPUT_FILE%) do (
    echo %%a | findstr /r /c:"/" >nul
    if errorlevel 1 (
        echo %%a >> "%TEMP_DIR%\temp_ips.txt"
    ) else (
        echo %%a >> "%TEMP_DIR%\temp_subnets.txt"
    )
)

sort "%TEMP_DIR%\temp_ips.txt" /unique > "%TEMP_DIR%\unique_ips.txt"
sort "%TEMP_DIR%\temp_subnets.txt" /unique > "%TEMP_DIR%\unique_subnets.txt"

:COUNT_ENTRIES
for /f %%a in ('type "%TEMP_DIR%\unique_ips.txt"^|find /c /v ""') do set "UNIQUE_IPS=%%a"
for /f %%a in ('type "%TEMP_DIR%\unique_subnets.txt"^|find /c /v ""') do set "UNIQUE_SUBNETS=%%a"

echo    ^> Found %UNIQUE_IPS% unique IP addresses
echo    ^> Found %UNIQUE_SUBNETS% unique subnets
echo.

:VERIFY_NMAP
echo [*] Verifying Nmap Installation...
call :FIND_NMAP
if defined NMAP_ERROR (
    echo [!] Nmap verification failed
    goto :NMAP_INPUT
) else (
    echo    ^> Using Nmap from: %NMAP_PATH%
    echo.
)

:GENERATE_SCAN_FILES
echo [*] Generating scan files...
set /a "ip_file_count=1"
set /a "subnet_file_count=1"
set /a "ip_count=0"
set /a "subnet_count=0"

REM Generate IP files
for /f "tokens=*" %%a in ('type "%TEMP_DIR%\unique_ips.txt"') do (
    if !ip_count! equ 0 (
        echo    ^> Creating scope!ip_file_count!.txt
    )
    echo %%a>> "%OUTPUT_DIR%\scope!ip_file_count!.txt"
    set /a "ip_count+=1"
    if !ip_count! equ %IPS_PER_FILE% (
        set /a "ip_file_count+=1"
        set /a "ip_count=0"
    )
)

REM Generate subnet files
for /f "tokens=*" %%a in ('type "%TEMP_DIR%\unique_subnets.txt"') do (
    if !subnet_count! equ 0 (
        echo    ^> Creating subnet!subnet_file_count!.txt
    )
    echo %%a>> "%OUTPUT_DIR%\subnet!subnet_file_count!.txt"
    set /a "subnet_count+=1"
    if !subnet_count! equ %SUBNETS_PER_FILE% (
        set /a "subnet_file_count+=1"
        set /a "subnet_count=0"
    )
)

:GENERATE_SCAN_SCRIPTS
echo [*] Generating scan scripts...

REM Create master scan control script
echo @echo off > "%COMMANDS_DIR%\master_scan.bat"
echo color 0A >> "%COMMANDS_DIR%\master_scan.bat"
echo echo =============================================================================== >> "%COMMANDS_DIR%\master_scan.bat"
echo echo                        Nmap Automation - Master Scanner >> "%COMMANDS_DIR%\master_scan.bat"
echo echo =============================================================================== >> "%COMMANDS_DIR%\master_scan.bat"
echo echo. >> "%COMMANDS_DIR%\master_scan.bat"

REM Generate individual scan scripts
for %%f in ("%OUTPUT_DIR%\scope*.txt" "%OUTPUT_DIR%\subnet*.txt") do (
    REM Create individual scan script
    call :CREATE_SCAN_SCRIPT "%%f"
    
    REM Add to master script
    echo echo [+] Launching scan for %%~nxf >> "%COMMANDS_DIR%\master_scan.bat"
    echo start "Nmap Scan - %%~nf" cmd /k "cd /d "%%~dp0" ^& call scan_%%~nf.bat" >> "%COMMANDS_DIR%\master_scan.bat"
    echo timeout /t 2 >> "%COMMANDS_DIR%\master_scan.bat"
)

echo echo. >> "%COMMANDS_DIR%\master_scan.bat"
echo echo [i] All scans have been launched. Check individual windows for progress. >> "%COMMANDS_DIR%\master_scan.bat"
echo pause >> "%COMMANDS_DIR%\master_scan.bat"

:CLEANUP_AND_MENU
echo [*] Cleaning up temporary files...
rd /s /q "%TEMP_DIR%" 2>nul

echo.
echo [*] Setup Complete!
echo.
echo Choose your next action:
echo [1] Run all scans now
echo [2] Run specific scan files
echo [3] Exit (run scans later)
echo.
set /p "choice=Enter your choice (1-3): "

if "%choice%"=="1" (
    cd "%COMMANDS_DIR%"
    call master_scan.bat
) else if "%choice%"=="2" (
    call :SHOW_SCAN_MENU
) else (
    echo.
    echo [i] You can run scans later by:
    echo     1. Navigate to: %COMMANDS_DIR%
    echo     2. Run individual scans: scan_scope1.bat, scan_subnet1.bat, etc.
    echo     3. Run all scans: master_scan.bat
    echo.
)

echo [*] Operation completed
pause
exit /b 0

REM ===============================================================================
REM                              Functions
REM ===============================================================================

:FIND_NMAP
REM Check if path is stored
if exist "%CONFIG_DIR%\nmap.txt" (
    set /p NMAP_PATH=<"%CONFIG_DIR%\nmap.txt"
    "!NMAP_PATH!" -h >nul 2>&1
    if !errorlevel! equ 0 (
        exit /b 0
    )
)

REM Check common locations
for %%n in (
    "nmap.exe"
    "C:\Program Files\Nmap\nmap.exe"
    "C:\Program Files (x86)\Nmap\nmap.exe"
) do (
    %%n -h >nul 2>&1
    if !errorlevel! equ 0 (
        set "NMAP_PATH=%%n"
        echo !NMAP_PATH!> "%CONFIG_DIR%\nmap.txt"
        exit /b 0
    )
)
set NMAP_ERROR=1
exit /b 1

:NMAP_INPUT
echo [!] Nmap not found in common locations
echo [?] Please enter the full path to nmap.exe
echo     Example: C:\Program Files\Nmap\nmap.exe
set /p "NMAP_PATH=Path: "

if not exist "!NMAP_PATH!" (
    echo [!] Invalid path. File does not exist.
    goto :NMAP_INPUT
)

"!NMAP_PATH!" -h >nul 2>&1
if !errorlevel! equ 0 (
    echo !NMAP_PATH!> "%CONFIG_DIR%\nmap.txt"
    echo [+] Nmap path verified and saved
    set "NMAP_ERROR="
) else (
    echo [!] Invalid nmap executable. Please try again.
    goto :NMAP_INPUT
)
exit /b 0

:CREATE_SCAN_SCRIPT
set "target_file=%~1"
set "script_name=scan_%~n1.bat"

echo @echo off > "%COMMANDS_DIR%\%script_name%"
echo color 0A >> "%COMMANDS_DIR%\%script_name%"
echo echo =============================================================================== >> "%COMMANDS_DIR%\%script_name%"
echo echo                    Nmap Scan for %~nx1 >> "%COMMANDS_DIR%\%script_name%"
echo echo =============================================================================== >> "%COMMANDS_DIR%\%script_name%"
echo echo. >> "%COMMANDS_DIR%\%script_name%"
echo echo [*] Starting scan at: %%date%% %%time%% >> "%COMMANDS_DIR%\%script_name%"
echo echo [*] Target file: %~nx1 >> "%COMMANDS_DIR%\%script_name%"
echo echo. >> "%COMMANDS_DIR%\%script_name%"
echo "%NMAP_PATH%" -sS -Pn -p- -T4 -iL "%target_file%" -oA "%OUTPUT_DIR%\results\%~n1" --max-rtt-timeout 100ms --max-retries 3 --defeat-rst-ratelimit --min-rate 450 --max-rate 15000 >> "%COMMANDS_DIR%\%script_name%"
echo echo. >> "%COMMANDS_DIR%\%script_name%"
echo echo [*] Scan completed at: %%date%% %%time%% >> "%COMMANDS_DIR%\%script_name%"
echo echo [*] Results saved to: %OUTPUT_DIR%\results\%~n1.* >> "%COMMANDS_DIR%\%script_name%"
echo pause >> "%COMMANDS_DIR%\%script_name%"
exit /b 0

:SHOW_SCAN_MENU
cls
echo ===============================================================================
echo                            Available Scan Files
echo ===============================================================================
echo.
set "file_count=0"
for %%f in ("%OUTPUT_DIR%\scope*.txt" "%OUTPUT_DIR%\subnet*.txt") do (
    set /a "file_count+=1"
    echo [!file_count!] %%~nxf
)
echo.
set /p "scan_choice=Enter the number of the scan to run (1-%file_count%): "

set "current_count=0"
for %%f in ("%OUTPUT_DIR%\scope*.txt" "%OUTPUT_DIR%\subnet*.txt") do (
    set /a "current_count+=1"
    if !current_count! equ %scan_choice% (
        cd "%COMMANDS_DIR%"
        call scan_%%~nf.bat
        exit /b 0
    )
)
echo [!] Invalid selection
goto :SHOW_SCAN_MENU
