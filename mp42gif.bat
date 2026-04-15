@echo off
setlocal

:: 1. 첫 번째 인자(입력 파일)가 없는 경우 안내 메시지 출력
if "%~1" == "" (
    echo "Usage: mp42gif [input] (output)"
    exit /b
)

:: 2. 입력 파일 변수 설정
set "INPUT=%~1"

:: 3. 출력 파일명 결정 로직
:: 두 번째 인자(%2)가 비어 있는지 직접 확인하여 변수를 할당합니다.
if "%~2" == "" (
    set "OUTPUT=%~n1.gif"
) else (
    set "OUTPUT=%~2"
)

:: 4. 실제 변환 실행
ffmpeg -i "%INPUT%" -vf "fps=10,scale=iw*0.5:-1:flags=lanczos" "%OUTPUT%"

endlocal