@echo off
setlocal
set "GODOT=godot"
if exist "D:\PC-game\tools\godot\Godot_v4.7.2-stable_win64_console.exe" (
  set "GODOT=D:\PC-game\tools\godot\Godot_v4.7.2-stable_win64_console.exe"
)
if not exist "%~dp0..\build" mkdir "%~dp0..\build"
"%GODOT%" --headless --path "%~dp0..\game" --export-release "Windows Desktop" "%~dp0..\build\NEREID.exe"
