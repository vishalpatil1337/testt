@echo off
setlocal enabledelayedexpansion
cls

echo ===============================================================================
echo                           Scope Splitter and Nmap Scanner
echo                               Created: January 2025
echo ===============================================================================
echo.

REM ===============================================================================
REM                              Configuration Section
REM ===============================================================================
set "IPS_PER_FILE=20"
set "SUBNETS_PER_FILE=3"
set "INPUT_FILE=scope.txt"

REM ===============================================================================
REM                              Initialization Check
REM ===============================================================================
echo [*] Checking environment...
echo [*] Verifying input file...
if not exist "%INPUT_FILE%" (
    echo [!] Error: %INPUT_FILE% not found!
    echo [!] Please ensure %INPUT_FILE% exists in the current directory.
    echo.
    pause
    exit /b 1
)

REM ===============================================================================
REM                              File Preparation
REM ===============================================================================
echo [*] Initializing temporary files...
echo [+] Creating work directories...
if not exist "output" mkdir output
if not exist "temp" mkdir temp

echo [+] Creating temporary sorting files...
type nul > "temp\temp_ips.txt"
type nul > "temp\temp_subnets.txt"

REM ===============================================================================
REM                              IP/Subnet Sorting
REM ===============================================================================
echo [*] Sorting IPs and Subnets...
for /f "tokens=*" %%a in (%INPUT_FILE%) do (
    echo %%a | findstr /r /c:"/" >nul
    if errorlevel 1 (
        echo %%a >> "temp\temp_ips.txt"
    ) else (
        echo %%a >> "temp\temp_subnets.txt"
    )
)

REM ===============================================================================
REM                              File Generation
REM ===============================================================================
echo [*] Generating split files...

REM Initialize counters
set /a ip_file_count=1
set /a subnet_file_count=1
set /a ip_count=0
set /a subnet_count=0

echo [+] Creating IP files (max %IPS_PER_FILE% IPs per file)...
type nul > "output\scope%ip_file_count%.txt"
for /f "tokens=*" %%a in ('type "temp\temp_ips.txt"') do (
    echo %%a >> "output\scope!ip_file_count!.txt"
    set /a ip_count+=1
    if !ip_count! equ %IPS_PER_FILE% (
        echo     - Created scope!ip_file_count!.txt
        set /a ip_file_count+=1
        set /a ip_count=0
        type nul > "output\scope!ip_file_count!.txt"
    )
)

echo [+] Creating subnet files (max %SUBNETS_PER_FILE% subnets per file)...
type nul > "output\subnet%subnet_file_count%.txt"
for /f "tokens=*" %%a in ('type "temp\temp_subnets.txt"') do (
    echo %%a >> "output\subnet!subnet_file_count!.txt"
    set /a subnet_count+=1
    if !subnet_count! equ %SUBNETS_PER_FILE% (
        echo     - Created subnet!subnet_file_count!.txt
        set /a subnet_file_count+=1
        set /a subnet_count=0
        type nul > "output\subnet!subnet_file_count!.txt"
    )
)

REM ===============================================================================
REM                              Cleanup Section
REM ===============================================================================
echo [*] Cleaning up temporary files...
for %%f in ("output\scope*.txt" "output\subnet*.txt") do (
    for /f %%A in ('type "%%f"^|find "" /v /c') do (
        if %%A equ 0 del "%%f"
    )
)
rd /s /q "temp" 2>nul

REM ===============================================================================
REM                              Nmap Configuration
REM ===============================================================================
echo [*] Configuring Nmap...
set "nmap_command=nmap"
if exist "nmap.txt" (
    set /p nmap_command=<nmap.txt
) else (
    where nmap >nul 2>&1
    if errorlevel 1 (
        echo [!] Nmap not found in PATH
        echo [?] Please enter the full path to nmap.exe
        set /p nmap_path="    Path (e.g., C:\Program Files\Nmap\nmap.exe): "
        echo !nmap_path!> nmap.txt
        set "nmap_command=!nmap_path!"
    )
)

REM ===============================================================================
REM                              Scanning Section
REM ===============================================================================
echo [*] Starting Nmap scans...
echo.
for %%f in ("output\scope*.txt" "output\subnet*.txt") do (
    echo [+] Scanning %%~nxf...
    echo [+] Command: %nmap_command% -sS -Pn -p- -T4 -iL "%%f" -oA "output\open_port_%%~nf" --max-rtt-timeout 100ms --max-retries 3 --defeat-rst-ratelimit --min-rate 450 --max-rate 15000
    "%nmap_command%" -sS -Pn -p- -T4 -iL "%%f" -oA "output\open_port_%%~nf" --max-rtt-timeout 100ms --max-retries 3 --defeat-rst-ratelimit --min-rate 450 --max-rate 15000
    echo     - Scan completed for %%~nxf
    echo.
)

REM ===============================================================================
REM                              Completion
REM ===============================================================================
echo ===============================================================================
echo                               Scan Summary
echo ===============================================================================
echo [+] All scans completed successfully
echo [+] Output files are located in the 'output' directory
echo [+] Review the results in the generated .nmap, .xml, and .gnmap files
echo.
echo Press any key to exit...
pause >nul