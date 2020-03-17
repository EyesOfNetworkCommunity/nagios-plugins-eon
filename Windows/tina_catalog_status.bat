@Echo OFF

set TINA_HOME=C:\Program Files\Atempo\TimeNavigator\tina
set TINA=tina
set TINA_SERVICE_TCP_NUM=2525
set TINA_SERVICE_UDP_NUM=2526
set PATH=%TINA_HOME%\Bin;%PATH%

tina_catalog_ctrl -status | find "Actif" > NUL
IF %ERRORLEVEL% NEQ 0 goto exitKO

echo OK - Catalogue TiNa Actif
exit /b 0

:exitKO
echo CRITICAL - Catalogue TiNa Inactif
exit /b 2
