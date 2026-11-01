@echo off
rem Genera dist\EFG_Launcher.exe (un solo archivo, sin consola).
rem Requiere Python 3.9+ en el PATH. Ejecutar desde cualquier carpeta.
setlocal
cd /d "%~dp0"
set RAIZ=%~dp0..\..

python -m pip install --upgrade pyinstaller || goto :error

python -m PyInstaller --noconfirm --clean --onefile --windowed ^
	--name EFG_Launcher ^
	--icon efg.ico ^
	--paths .. ^
	--hidden-import parche_menu_gmod ^
	--add-data "efg.ico;." ^
	--add-data "launcher.json;." ^
	--add-data "..\menu_gmod\efg_menu.css;menu_gmod" ^
	--add-data "..\menu_gmod\main.html;menu_gmod" ^
	--add-data "%RAIZ%\content\resource\fonts\mbender.ttf;menu_gmod" ^
	--add-data "%RAIZ%\content\materials\efgui\logo32028.png;menu_gmod" ^
	--add-data "%RAIZ%\content\materials\efg\menu\main_art.jpg;menu_gmod" ^
	efg_launcher.py || goto :error

rem PyInstaller deja el logo con su nombre original: el parche lo busca como logo.png.
echo.
echo Listo: %~dp0dist\EFG_Launcher.exe
exit /b 0

:error
echo Ha fallado la compilacion.
exit /b 1
