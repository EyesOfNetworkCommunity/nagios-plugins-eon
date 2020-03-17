@echo off
SETLOCAL
rem ***************************************************
rem Check_Windows_Time.bat
rem
rem Author: Michael van den Berg
rem Copyright 2012 - PCS-IT Services B.V. (www.pcs-it.nl)
rem
rem This Nagios plugin will check the time offset
rem against a specified time server.
rem ***************************************************

if [%1]==[] (goto usage) else (set time_server=%1)
if [%1]==[/?] (goto usage) else (set time_server=%1)
if [%2]==[] (set warn_offset=nul) else (set warn_offset=%2)
if [%2]==[$ARG2$] set warn_offset=nul
if [%3]==[] (set crit_offset=nul) else (set crit_offset=%3)
if [%3]==[$ARG3$] set crit_offset=nul

for /f "tokens=*" %%t in ('w32tm /stripchart /computer:%time_server% /samples:1 /dataonly') do set output=%%t

if not "x%output:0x80072af9=%"=="x%output%" goto host_error
if not "x%output:0x800705B4=%"=="x%output%" goto comm_error
if not "x%output:error=%"=="x%output%" goto unknown_error
if not "x%output:)=%"=="x%output%" goto unknown_error

set time_org=%output:*, =%
set time=%time_org:~1,-9%

if %warn_offset% == nul (set warn_perf=0) else (set warn_perf=%warn_offset%)
if %crit_offset% == nul (set crit_perf=0) else (set crit_perf=%crit_offset%)
set perf_data='Offset'=%time%s;%warn_perf%;%crit_perf%;0

if %time% geq %crit_offset% goto threshold_crit
if %time% geq %warn_offset% goto threshold_warn
if %time% lss %warn_offset% goto okay
goto unknown_error

:usage
echo %0 - Nagios plugin that checks time offset against a specified ntp server.
echo.
echo Usage:    %0 ^<timeserver^> ^<warning threshold in seconds^> ^<critical threshold in seconds^>
echo Examples: %0 pool.ntp.org 120 300
echo           %0 my-domain-controller.local 120 300
exit /b 3

:host_error
echo UNKNOWN: Lookup failure for host %time_server%
exit /b 3

:comm_error
echo UNKNOWN: Unable to query NTP service at %time_server% (Port 123 blocked/closed)
exit /b 3

:threshold_crit
echo CRITICAL: Time is %time_org% from %time_server%^|%perf_data%
exit /b 2

:threshold_warn
echo WARNING: Time is %time_org% from %time_server%^|%perf_data%
exit /b 1

:okay
echo OK: Time is %time_org% from %time_server%^|%perf_data%
exit /b 0

:unknown_error
echo UNKNOWN: Unable to check time (command error)
exit /b 3


