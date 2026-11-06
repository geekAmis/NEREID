@echo off
setlocal
set "GODOT=godot"
if exist "D:\PC-game\tools\godot\Godot_v4.7.2-stable_win64_console.exe" (
  set "GODOT=D:\PC-game\tools\godot\Godot_v4.7.2-stable_win64_console.exe"
)
"%GODOT%" --headless --path "%~dp0..\game" --import
"%GODOT%" --headless --path "%~dp0..\game" --script res://tests/run_tests.gd
