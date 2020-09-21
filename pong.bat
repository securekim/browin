@echo off
title %1
:start
color
set t=%time:~-5%
set pingIP=%1
set cnt=0
:re
set /a cnt+=1
cls
echo -^> %pingIP%
if %cnt% EQU 1 echo State : ／
if %cnt% EQU 2 echo State : ―
if %cnt% EQU 3 echo State : ＼
if %cnt% EQU 4 (
echo State : ｜
set cnt=0
)

ping %pingIP% -n 1 >nul
if %errorlevel% EQU 0 (
color 03
) else (
color 04
)
ENDLOCAL
goto re



:: 여러줄 리턴 :: https://stackoverflow.com/questions/6359820/how-to-set-commands-output-as-a-variable-in-a-batch-file
::set COMMAND="ping %pingIP% -n 1"
::SETLOCAL ENABLEDELAYEDEXPANSION
::SET count=1
::FOR /F "tokens=* USEBACKQ" %%F IN (`%COMMAND%`) DO (
::  SET var!count!=%%F
::  SET /a count=!count!+1
::)
::echo %var5%
::ECHO %var5% | findstr "손실 = 1"