@echo off
setlocal
set "GODOT=godot"
if exist "D:\PC-game\tools\godot\Godot_v4.7.2-stable_win64.exe" (
  set "GODOT=D:\PC-game\tools\godot\Godot_v4.7.2-stable_win64.exe"
)
"%GODOT%" --path "%~dp0..\game" %*
