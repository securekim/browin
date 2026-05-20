@echo off
setlocal enabledelayedexpansion

set "pattern=%~1"
set "src_arg=%~2"
set "dst_arg=%~3"

if "%pattern%"=="" (
    echo "패턴에 맞는 파일을 해당 위치 기준으로 폴더명까지 _로 연결해서 복사해옵니다."
	echo "사용법: getFiles [파일패턴] (소스경로) (대상경로)"
	echo "예시: getFiles *tflite (현재위치에서 찾아서 현재 위치로 복사)"
	echo "예시: getFiles *tflite D:\Destination (현재위치에서 찾아서 Destination으로 복사)"
    echo "예시: getFiles *tflite C:\Source D:\Destination (Source에서 찾아서 Destination으로 복사)"
    exit /b
)

if "%src_arg%"=="" (set "src=%cd%") else (set "src=%src_arg%")
if "%dst_arg%"=="" (set "dst=%cd%") else (set "dst=%dst_arg%")

for %%A in ("%src%") do set "src=%%~fA"
for %%A in ("%dst%") do set "dst=%%~fA"

if not exist "%dst%" mkdir "%dst%"

for /f "delims=" %%i in ('dir /s /b /a-d "%src%\%pattern%" 2^>nul') do (
    set "fullPath=%%~fi"
    set "fileDir=%%~dpi"
    set "fileName=%%~nxi"

    set "rel=!fileDir:%src%=!"

    if "!rel!"=="\" (
        set "finalName=!fileName!"
    ) else (
        set "relPath=!rel:~1!"
        set "prefix=!relPath:\=_!"
        set "finalName=!prefix!!fileName!"
    )

    echo 복사 중: !finalName!
    copy /y "%%i" "%dst%\!finalName!"
)

endlocal