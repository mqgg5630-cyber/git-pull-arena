@echo off
set URL=https://official-package.wpscdn.cn/wps/download/WPS_Setup_X64_22525.exe
set PART=F:\fig1_rebuild\wps_setup.partial
set OUT=F:\fig1_rebuild\wps_setup.exe
del /f /q %PART% 2>nul
echo start %DATE% %TIME% >> F:\fig1_rebuild\wps_download.log
set TRIES=0
:loop
set /a TRIES+=1
curl.exe -L -C - -o %PART% --max-time 1500 --connect-timeout 30 -s %URL%
for %%A in (%PART%) do set SZ=%%~zA
echo try %TRIES% size=%SZ% %DATE% %TIME% >> F:\fig1_rebuild\wps_download.log
if %SZ% GEQ 305000000 goto done
if %TRIES% GEQ 60 goto giveup
timeout /t 15 /nobreak >nul
goto loop
:done
move /y %PART% %OUT%
echo done size=%SZ% %DATE% %TIME% >> F:\fig1_rebuild\wps_download.log
exit /b 0
:giveup
echo gave up after %TRIES% tries size=%SZ% %DATE% %TIME% >> F:\fig1_rebuild\wps_download.log
exit /b 1
