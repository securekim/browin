@echo off
:: ==================================================
:: Author: securekim (https://securekim.com)
:: License: MIT License
:: ==================================================
setlocal enabledelayedexpansion

set "VERSION=1.0.0"

:: 설정 경로 설정
set "CONFIG_BASE_DIR=%~dp0claude_configs"
if not exist "!CONFIG_BASE_DIR!" mkdir "!CONFIG_BASE_DIR!"
set "GLOBAL_PATH_FILE=!CONFIG_BASE_DIR!\last_path.txt"
set "LAST_ALIAS_FILE=!CONFIG_BASE_DIR!\last_alias.txt"
set "PS_SCRIPT=!CONFIG_BASE_DIR!\get_session.ps1"
set "ARG1=%~1"
set "ARG2=%~2"
set "ARG3=%~3"
set "NEW_PATH="
set "TARGET_ALIAS="

:: PowerShell 스크립트 생성
(
echo param^($ConfigDir, $CurrentPath, $MaxSessions^)
echo if ^([string]::IsNullOrEmpty^($MaxSessions^)^) { $MaxSessions = 1 }
echo $accName = ""; $accEmail = ""; $sessionId = ""
echo $claudeFile = Join-Path $ConfigDir ".claude.json"
echo $credFile = Join-Path $ConfigDir ".credentials.json"
echo if ^(Test-Path $claudeFile^) {
echo     $cData = Get-Content $claudeFile -Encoding UTF8 -Raw -ErrorAction SilentlyContinue ^| ConvertFrom-Json -ErrorAction SilentlyContinue
echo     if ^($null -ne $cData -and $null -ne $cData.oauthAccount^) {
echo         $accName = $cData.oauthAccount.displayName; $accEmail = $cData.oauthAccount.emailAddress
echo     }
echo }
echo if ^(Test-Path $credFile^) {
echo     $credData = Get-Content $credFile -Encoding UTF8 -Raw -ErrorAction SilentlyContinue ^| ConvertFrom-Json -ErrorAction SilentlyContinue
echo     if ^($null -ne $credData -and $null -ne $credData.sessionId^) { $sessionId = $credData.sessionId }
echo }
echo Write-Output "ACC_NAME=$accName"; Write-Output "ACC_EMAIL=$accEmail"; Write-Output "S_ID=$sessionId"
echo $files = $null
echo if ^([string]::IsNullOrEmpty^($CurrentPath^)^) {
echo     $files = Get-ChildItem -Path "$ConfigDir" -Filter "*.jsonl" -Recurse -ErrorAction SilentlyContinue ^| Sort-Object LastWriteTime -Descending ^| Select-Object -First $MaxSessions
echo } else {
echo     $encodedPath = $CurrentPath -replace ':', '-' -replace '\\', '-'
echo     $projectDir = Join-Path $ConfigDir "projects\$encodedPath"
echo     if ^(Test-Path $projectDir^) { $files = Get-ChildItem -Path $projectDir -Filter "*.jsonl" -ErrorAction SilentlyContinue ^| Sort-Object LastWriteTime -Descending ^| Select-Object -First $MaxSessions }
echo }
echo $count = 0
echo if ^($null -ne $files^) {
echo     foreach ^($file in $files^) {
echo         $count++; $cwd = "세션 정보 없음"; $branch = "세션 정보 없음"; $time = "세션 정보 없음"; $userMsg = "세션 정보 없음"; $assistantMsg = "세션 정보 없음"
echo         $currentSessionId = $file.BaseName
echo         if ^($count -eq 1 -and -not [string]::IsNullOrEmpty^($sessionId^)^) { $currentSessionId = $sessionId }
echo         foreach ^($line in Get-Content $file.FullName -Encoding UTF8^) {
echo             try {
echo                 $obj = $line ^| ConvertFrom-Json -ErrorAction SilentlyContinue
echo                 if ^($null -ne $obj^) {
echo                     if ^($null -ne $obj.cwd^) { $cwd = $obj.cwd }
echo                     if ^($null -ne $obj.gitBranch^) { $branch = $obj.gitBranch }
echo                     if ^($null -ne $obj.timestamp^) { $time = $obj.timestamp }
echo                     if ^($obj.type -eq 'last-prompt' -and $null -ne $obj.lastPrompt^) { $userMsg = $obj.lastPrompt }
echo                     if ^($obj.type -eq 'assistant' -and $null -ne $obj.message.content^) { $assistantMsg = $obj.message.content }
echo                 }
echo             } catch {}
echo         }
echo         if ^($userMsg.Length -gt 50^) { $userMsg = $userMsg.Substring^(0, 47^) + '...' }
echo         if ^($assistantMsg.Length -gt 50^) { $assistantMsg = $assistantMsg.Substring^(0, 47^) + '...' }
echo         $userMsg = $userMsg -replace "\r", " " -replace "\n", " "
echo         $assistantMsg = $assistantMsg -replace "\r", " " -replace "\n", " "
echo         if ^($count -eq 1^) {
echo             Write-Output "S_ID=$currentSessionId"; Write-Output "S_PATH=$cwd"; Write-Output "S_BRANCH=$branch"; Write-Output "S_TIME=$time"; Write-Output "S_USER=$userMsg"; Write-Output "S_ASSISTANT=$assistantMsg"
echo         }
echo         Write-Output "S_ID_$count=$currentSessionId"; Write-Output "S_PATH_$count=$cwd"; Write-Output "S_BRANCH_$count=$branch"; Write-Output "S_TIME_$count=$time"; Write-Output "S_USER_$count=$userMsg"; Write-Output "S_ASSISTANT_$count=$assistantMsg"
echo     }
echo }
echo Write-Output "S_COUNT=$count"
) > "!PS_SCRIPT!"

:: 명령어 분기
if /i "!ARG1!"=="-h" goto :SHOW_HELP
if /i "!ARG1!"=="--help" goto :SHOW_HELP
if /i "!ARG1!"=="login" goto :DO_LOGIN
if /i "!ARG1!"=="copy" goto :DO_COPY
if /i "!ARG1!"=="reset" goto :DO_RESET
if /i "!ARG1!"=="logout" goto :DO_LOGOUT
if /i "!ARG1!"=="info" goto :DO_INFO
if /i "!ARG1!"=="version" goto :DO_VERSION

:START_PARSE
if not "!ARG1!"=="" (
    if exist "!ARG1!\" ( set "NEW_PATH=!ARG1!" ) else (
        set "TARGET_ALIAS=!ARG1!"
        if not "!ARG2!"=="" if exist "!ARG2!\" set "NEW_PATH=!ARG2!"
    )
)

if "!TARGET_ALIAS!"=="" if exist "!LAST_ALIAS_FILE!" set /p TARGET_ALIAS=<"!LAST_ALIAS_FILE!"

if not "!TARGET_ALIAS!"=="" (
    if exist "!CONFIG_BASE_DIR!\!TARGET_ALIAS!" (
        set "CLAUDE_CONFIG_DIR=!CONFIG_BASE_DIR!\!TARGET_ALIAS!"
        echo !TARGET_ALIAS!>"!LAST_ALIAS_FILE!"
        echo [계정 정보] 계정 Alias '!TARGET_ALIAS!' 프로파일로 진행합니다.
    ) else ( echo [오류] '!TARGET_ALIAS!' 계정 Alias가 없습니다. & goto :EOF )
) else ( echo [오류] 설정된 프로파일이 없습니다. & goto :EOF )

set "PROFILE_PATH_FILE=!CLAUDE_CONFIG_DIR!\last_path.txt"
if not "!NEW_PATH!"=="" (
    echo !NEW_PATH!>"!PROFILE_PATH_FILE!"
    echo !NEW_PATH!>"!GLOBAL_PATH_FILE!"
)

set "LAST_PATH="
if exist "!PROFILE_PATH_FILE!" set /p LAST_PATH=<"!PROFILE_PATH_FILE!"
if "!LAST_PATH!"=="" if exist "!GLOBAL_PATH_FILE!" set /p LAST_PATH=<"!GLOBAL_PATH_FILE!"
if "!LAST_PATH!"=="" (
    set /p LAST_PATH="이동할 경로를 입력하세요: "
    echo !LAST_PATH!>"!PROFILE_PATH_FILE!"
    echo !LAST_PATH!>"!GLOBAL_PATH_FILE!"
)

powershell -NoProfile -ExecutionPolicy Bypass -File "!PS_SCRIPT!" "!CLAUDE_CONFIG_DIR!" "!LAST_PATH!" > "!CONFIG_BASE_DIR!\temp_session.txt"
for /f "tokens=1,* delims==" %%A in ('type "!CONFIG_BASE_DIR!\temp_session.txt"') do (
    if "%%A"=="S_ID" set "S_ID=%%B"
    if "%%A"=="S_PATH" set "S_PATH=%%B"
    if "%%A"=="S_BRANCH" set "S_BRANCH=%%B"
    if "%%A"=="S_TIME" set "S_TIME=%%B"
    if "%%A"=="S_USER" set "S_USER=%%B"
)

if not "!S_ID!"=="" (
    echo --------------------------------------------------
    echo [최근 세션 정보]
    echo  - 작업 위치: !S_PATH!
    echo  - 세션 시간: !S_TIME!
    echo  - 최근 입력: !S_USER!
    echo --------------------------------------------------
    :ASK_SESSION
    set /p USE_SESSION="최근 세션을 이어서 시작할까요? (y/n) 또는 이전 세션 검색 개수 입력(숫자): "
    if /i "!USE_SESSION!"=="y" ( set "RESUME_ARG=--resume !S_ID!" & goto :RUN_CLAUDE )
    if /i "!USE_SESSION!"=="n" goto :RUN_CLAUDE
    set /a NUM_CHECK=!USE_SESSION! 2>nul
    if "!NUM_CHECK!"=="!USE_SESSION!" if !USE_SESSION! GTR 0 goto :FETCH_MULTIPLE_SESSIONS
    goto :ASK_SESSION
    :FETCH_MULTIPLE_SESSIONS
    set "FOUND_COUNT=0"
    for /f "tokens=1,* delims==" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -File "!PS_SCRIPT!" "!CLAUDE_CONFIG_DIR!" "!LAST_PATH!" "!USE_SESSION!"') do (
        if "%%A"=="S_COUNT" set "FOUND_COUNT=%%B"
        for /l %%I in (1,1,!USE_SESSION!) do (
            if "%%A"=="S_ID_%%I" set "M_ID_%%I=%%B"
            if "%%A"=="S_TIME_%%I" set "M_TIME_%%I=%%B"
            if "%%A"=="S_USER_%%I" set "M_USER_%%I=%%B"
            if "%%A"=="S_ASSISTANT_%%I" set "M_ASSISTANT_%%I=%%B"
        )
    )
    if "!FOUND_COUNT!"=="0" echo 이전 세션이 없습니다. & goto :ASK_SESSION
    echo --------------------------------------------------
    for /l %%I in (1,1,!FOUND_COUNT!) do ( echo [%%I] 시간: !M_TIME_%%I! ^| 입력: !M_USER_%%I! ^| 응답: !M_ASSISTANT_%%I! & echo. )
    echo --------------------------------------------------
    :SELECT_SESSION
    set /p SEL_INDEX="연결할 번호 (취소: c): "
    if /i "!SEL_INDEX!"=="c" goto :ASK_SESSION
    for /l %%I in (1,1,!FOUND_COUNT!) do if "!SEL_INDEX!"=="%%I" set "RESUME_ARG=--resume !M_ID_%%I!" & goto :RUN_CLAUDE
    echo 잘못된 번호. & goto :SELECT_SESSION
) else ( echo [안내] 발견된 세션 정보 없음. )

:RUN_CLAUDE
del "!CONFIG_BASE_DIR!\temp_session.txt" 2>nul
cd /d "!LAST_PATH!"
claude !RESUME_ARG!
pause
goto :EOF

:DO_VERSION
echo Claude Code 실행기 v!VERSION!
goto :EOF
:DO_LOGIN
set /p NEW_ALIAS="Alias 입력: "
if not exist "!CONFIG_BASE_DIR!\!NEW_ALIAS!" mkdir "!CONFIG_BASE_DIR!\!NEW_ALIAS!"
echo !NEW_ALIAS!>"!LAST_ALIAS_FILE!"
claude login
goto :EOF
:DO_COPY
set /p SRC_ALIAS="원본 Alias: "
set /p NEW_ALIAS="신규 Alias: "
mkdir "!CONFIG_BASE_DIR!\!NEW_ALIAS!"
for %%F in ("!CONFIG_BASE_DIR!\!SRC_ALIAS!\*") do if /i not "%%~nxF"=="last_path.txt" copy /Y "%%F" "!CONFIG_BASE_DIR!\!NEW_ALIAS!\" >nul
echo !NEW_ALIAS!>"!LAST_ALIAS_FILE!"
goto :EOF
:DO_RESET
rmdir /s /q "!CONFIG_BASE_DIR!"
mkdir "!CONFIG_BASE_DIR!"
goto :EOF
:DO_LOGOUT
set "LOGOUT_ALIAS=%~2"
if exist "!CONFIG_BASE_DIR!\!LOGOUT_ALIAS!" rmdir /s /q "!CONFIG_BASE_DIR!\!LOGOUT_ALIAS!"
goto :EOF
:DO_INFO
echo ==================================================
echo                저장된 계정 정보 목록
echo ==================================================
for /d %%D in ("!CONFIG_BASE_DIR!\*") do (
    powershell -NoProfile -ExecutionPolicy Bypass -File "!PS_SCRIPT!" "%%D" "" > "!CONFIG_BASE_DIR!\temp_info.txt"
    set "A_NAME=Unknown" & set "A_EMAIL=Unknown"
    for /f "tokens=1,* delims==" %%A in ('type "!CONFIG_BASE_DIR!\temp_info.txt"') do (
        if "%%A"=="ACC_NAME" if not "%%B"=="" set "A_NAME=%%B"
        if "%%A"=="ACC_EMAIL" if not "%%B"=="" set "A_EMAIL=%%B"
    )
    set "A_PATH=전용경로없음"
    if exist "%%D\last_path.txt" set /p A_PATH=<"%%D\last_path.txt"
    echo [계정 Alias: %%~nxD] !A_NAME! - !A_EMAIL!
    echo  - 경로: !A_PATH!
    
    :: 세션 정보 확인
    for /f "tokens=1,* delims==" %%A in ('type "!CONFIG_BASE_DIR!\temp_info.txt"') do if "%%A"=="S_ID" set "SI=%%B"
    if "!SI!"=="" ( echo  - 세션: 세션 정보 없음 ) else ( echo  - 세션: !SI! )
    echo.
)
del "!CONFIG_BASE_DIR!\temp_info.txt"
goto :EOF
:SHOW_HELP
echo [사용법] c [Alias] [경로]
goto :EOF