@echo off
rem ============================================================
rem  EFG - compilar.bat
rem  1) Copia el schema y Helix a la carpeta gamemodes de GMod.
rem  2) Empaqueta el contenido propio (content\) en un .gma con gmad.exe
rem     para subirlo al Workshop o servirlo por FastDL.
rem  Uso: compilar.bat            (copia y empaqueta)
rem       compilar.bat copiar     (solo copia)
rem ============================================================
setlocal

set "REPO=%~dp0.."
set "HELIX=%REPO%\..\helix"
set "GMOD=C:\Program Files (x86)\Steam\steamapps\common\GarrysMod"
set "GAMEMODES=%GMOD%\garrysmod\gamemodes"
set "GMAD=%GMOD%\bin\gmad.exe"
set "OUT=%REPO%\_build"

echo [EFG] Copiando schema a %GAMEMODES%\escapefromgmod ...
robocopy "%REPO%" "%GAMEMODES%\escapefromgmod" /E /NFL /NDL /NJH /NJS /XD .git .claude .github .vscode _retirados _build tools
echo [EFG] Copiando Helix a %GAMEMODES%\helix ...
if exist "%HELIX%" robocopy "%HELIX%" "%GAMEMODES%\helix" /E /NFL /NDL /NJH /NJS /XD .git .github

if /I "%1"=="copiar" goto fin

if not exist "%GMAD%" (
	echo [EFG] No encuentro gmad.exe en %GMAD%
	goto fin
)

echo [EFG] Empaquetando contenido ...
if not exist "%OUT%\efg_content" mkdir "%OUT%\efg_content"
robocopy "%REPO%\content" "%OUT%\efg_content" /E /NFL /NDL /NJH /NJS
> "%OUT%\efg_content\addon.json" echo {"title": "EFG Content", "type": "ServerContent", "tags": ["build"], "ignore": ["*.psd", "*.txt"]}
"%GMAD%" create -folder "%OUT%\efg_content" -out "%OUT%\efg_content.gma"

echo [EFG] Listo: %OUT%\efg_content.gma
echo        Subelo con: "%GMOD%\bin\gmpublish.exe" create -addon "%OUT%\efg_content.gma" -icon icono.jpg

:fin
endlocal
