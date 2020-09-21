@echo off
set myPath=%cd%
echo %myPath%
setx PATH "%PATH%;%myPath%"
pause