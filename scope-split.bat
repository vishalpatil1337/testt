@echo off
setlocal enabledelayedexpansion
cls
color 0B

REM ===============================================================================
REM                        Nmap Automation Framework
REM                           Version 2.1
REM ===============================================================================

:INITIALIZE_VARS
set "VERSION=2.1"
set "TOOL_NAME=Nmap Automation Framework"
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

:VERIFY_NMAP_FIRST
echo [*] Verifying Nmap Installation...
for %%n in (
    "C:\Program Files\Nmap"
    "C:\Program Files (x86)\Nmap"
) do (
    if exist "%%~n\nmap.exe" (
        set "NMAP_PATH=%%~n"
        goto :NMAP_FOUND
    )
)

:NMAP_PATH_INPUT
echo [!] Nmap not found in default locations
echo [?] Please enter the path where nmap.exe is located
echo     Example: C:\Security\Nmap
echo     Note: Do not include nmap.exe in the path
echo     Note: Do not use quotes in the path
set /p "NMAP_PATH=Path: "

if not exist "!NMAP_PATH!\nmap.exe" (
    echo [!] Invalid path. nmap.exe not found in specified directory.
    goto :NMAP_PATH_INPUT
)

:NMAP_FOUND
echo [+] Using Nmap from: %NMAP_PATH%\nmap.exe
echo.

:CHECK_INPUT_FILE
echo [*] Validating Input File...
if not exist "%INPUT_FILE%" (
    echo [!] Error: %INPUT_FILE% not found!
    echo [i] Example format for scope.txt:
    echo    IP Addresses:        Subnets:
    echo    192.168.1.1         192.168.0.0/24
    echo    10.0.0.1            10.0.0.0/16
    echo.
    pause
    exit /b 1
)

:PROCESS_AND_COUNT
echo [*] Processing input file...
type nul > "%TEMP_DIR%\temp_ips.txt"
type nul > "%TEMP_DIR%\temp_subnets.txt"

for /f "tokens=*" %%a in (%INPUT_FILE%) do (
    echo %%a | findstr /r /c:"/" >nul
    if errorlevel 1 (
        echo %%a >> "%TEMP_DIR%\temp_ips.txt"
    ) else (
        echo %%a >> "%TEMP_DIR%\temp_subnets.txt"
    )
)

for /f %%a in ('type "%TEMP_DIR%\temp_ips.txt"^|find /c /v ""') do set "TOTAL_IPS=%%a"
for /f %%a in ('type "%TEMP_DIR%\temp_subnets.txt"^|find /c /v ""') do set "TOTAL_SUBNETS=%%a"

echo    ^> Found %TOTAL_IPS% IP addresses
echo    ^> Found %TOTAL_SUBNETS% subnets
echo.

:GET_PARTITION_INFO
echo [*] Partition Configuration
echo ===============================================================================

if %TOTAL_IPS% gtr 0 (
    :IP_PARTITION_INPUT
    echo [?] How many IP addresses would you like per partition file?
    echo    (Total IPs: %TOTAL_IPS%)
    set /p "IPS_PER_FILE=Enter number (recommended: 20): "
    
    echo !IPS_PER_FILE!| findstr /r "^[1-9][0-9]*$" >nul
    if errorlevel 1 (
        echo [!] Please enter a valid positive number
        goto :IP_PARTITION_INPUT
    )
    if !IPS_PER_FILE! gtr %TOTAL_IPS% (
        echo [!] Number cannot be greater than total IPs
        goto :IP_PARTITION_INPUT
    )
)

if %TOTAL_SUBNETS% gtr 0 (
    :SUBNET_PARTITION_INPUT
    echo.
    echo [?] How many subnets would you like per partition file?
    echo    (Total Subnets: %TOTAL_SUBNETS%)
    set /p "SUBNETS_PER_FILE=Enter number (recommended: 3): "
    
    echo !SUBNETS_PER_FILE!| findstr /r "^[1-9][0-9]*$" >nul
    if errorlevel 1 (
        echo [!] Please enter a valid positive number
        goto :SUBNET_PARTITION_INPUT
    )
    if !SUBNETS_PER_FILE! gtr %TOTAL_SUBNETS% (
        echo [!] Number cannot be greater than total subnets
        goto :SUBNET_PARTITION_INPUT
    )
)

echo.
echo [*] Configuration Summary:
if %TOTAL_IPS% gtr 0 (
    set /a "IP_FILES=(%TOTAL_IPS%+%IPS_PER_FILE%-1)/%IPS_PER_FILE%"
    echo    ^> IPs: %TOTAL_IPS% IPs will be split into %IP_FILES% files
)
if %TOTAL_SUBNETS% gtr 0 (
    set /a "SUBNET_FILES=(%TOTAL_SUBNETS%+%SUBNETS_PER_FILE%-1)/%SUBNETS_PER_FILE%"
    echo    ^> Subnets: %TOTAL_SUBNETS% subnets will be split into %SUBNET_FILES% files
)
echo.

REM Rest of the script continues with the existing functionality...
