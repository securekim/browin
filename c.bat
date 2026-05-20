@echo off
:: ==================================================
:: Author: securekim (https://securekim.com)
:: License: MIT License
:: 누구나 자유롭게 수정 및 배포할 수 있으며, 원본 표기만 유지해 주시면 됩니다.
:: ==================================================
setlocal enabledelayedexpansion

set "VERSION=1.0.0"

:: 설정 경로 설정 (모든 부산물은 claude_configs 내부에 위치)
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

:: JSONL 및 계정/세션 정보 다중 파싱용 PowerShell 스크립트 생성
(
echo param^($ConfigDir, $CurrentPath, $MaxSessions^)
echo if ^([string]::IsNullOrEmpty^($MaxSessions^)^) { $MaxSessions = 1 }
echo $accName = ""
echo $accEmail = ""
echo $sessionId = ""
echo $claudeFile = Join-Path $ConfigDir ".claude.json"
echo $credFile = Join-Path $ConfigDir ".credentials.json"
echo if ^(Test-Path $claudeFile^) {
echo     $cData = Get-Content $claudeFile -Encoding UTF8 -Raw -ErrorAction SilentlyContinue ^| ConvertFrom-Json -ErrorAction SilentlyContinue
echo     if ^($null -ne $cData^) {
echo         if ^($null -ne $cData.oauthAccount^) {
echo             if ^($null -ne $cData.oauthAccount.displayName^) { $accName = $cData.oauthAccount.displayName }
echo             if ^($null -ne $cData.oauthAccount.emailAddress^) { $accEmail = $cData.oauthAccount.emailAddress }
echo         }
echo     }
echo }
echo if ^(Test-Path $credFile^) {
echo     $credData = Get-Content $credFile -Encoding UTF8 -Raw -ErrorAction SilentlyContinue ^| ConvertFrom-Json -ErrorAction SilentlyContinue
echo     if ^($null -ne $credData^) {
echo         if ^($null -ne $credData.sessionId^) { $sessionId = $credData.sessionId }
echo     }
echo }
echo Write-Output "ACC_NAME=$accName"
echo Write-Output "ACC_EMAIL=$accEmail"
echo $files = $null
echo if ^([string]::IsNullOrEmpty^($CurrentPath^)^) {
echo     $files = Get-ChildItem -Path "$ConfigDir" -Filter "*.jsonl" -Recurse -ErrorAction SilentlyContinue ^| Sort-Object LastWriteTime -Descending ^| Select-Object -First $MaxSessions
echo } else {
echo     $encodedPath = $CurrentPath -replace ':', '-' -replace '\\', '-'
echo     $projectDir = Join-Path $ConfigDir "projects\$encodedPath"
echo     if ^(Test-Path $projectDir^) {
echo         $files = Get-ChildItem -Path $projectDir -Filter "*.jsonl" -ErrorAction SilentlyContinue ^| Sort-Object LastWriteTime -Descending ^| Select-Object -First $MaxSessions
echo     }
echo }
echo $count = 0
echo if ^($null -ne $files^) {
echo     foreach ^($file in $files^) {
echo         $count++
echo         $cwd = "없음"
echo         $branch = "없음"
echo         $time = "없음"
echo         $userMsg = "없음"
echo         $assistantMsg = "없음"
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
echo             Write-Output "S_ID=$currentSessionId"
echo             Write-Output "S_PATH=$cwd"
echo             Write-Output "S_BRANCH=$branch"
echo             Write-Output "S_TIME=$time"
echo             Write-Output "S_USER=$userMsg"
echo             Write-Output "S_ASSISTANT=$assistantMsg"
echo         }
echo         Write-Output "S_ID_$count=$currentSessionId"
echo         Write-Output "S_PATH_$count=$cwd"
echo         Write-Output "S_BRANCH_$count=$branch"
echo         Write-Output "S_TIME_$count=$time"
echo         Write-Output "S_USER_$count=$userMsg"
echo         Write-Output "S_ASSISTANT_$count=$assistantMsg"
echo     }
echo }
echo Write-Output "S_COUNT=$count"
) > "!PS_SCRIPT!"

:: 1. 특수 명령어 처리
if /i "!ARG1!"=="" goto :START_PARSE
if /i "!ARG1!"=="-h" goto :SHOW_HELP
if /i "!ARG1!"=="--help" goto :SHOW_HELP
if /i "!ARG1!"=="login" goto :DO_LOGIN
if /i "!ARG1!"=="copy" goto :DO_COPY
if /i "!ARG1!"=="reset" goto :DO_RESET
if /i "!ARG1!"=="logout" goto :DO_LOGOUT
if /i "!ARG1!"=="info" goto :DO_INFO
if /i "!ARG1!"=="version" goto :DO_VERSION

:START_PARSE
:: 2. 인수 분석: 경로 문자열인지 계정 Alias인지 구분
if not "!ARG1!"=="" (
    echo !ARG1! | findstr /R "\\" >nul
    if not errorlevel 1 (
        set "NEW_PATH=!ARG1!"
    ) else (
        set "TARGET_ALIAS=!ARG1!"
        if not "!ARG2!"=="" (
            echo !ARG2! | findstr /R "\\" >nul
            if not errorlevel 1 (
                set "NEW_PATH=!ARG2!"
            )
        )
    )
)

:: 3. 계정 프로파일 설정
if "!TARGET_ALIAS!"=="" (
    if exist "!LAST_ALIAS_FILE!" set /p TARGET_ALIAS=<"!LAST_ALIAS_FILE!"
)

if not "!TARGET_ALIAS!"=="" (
    if exist "!CONFIG_BASE_DIR!\!TARGET_ALIAS!" (
        set "CLAUDE_CONFIG_DIR=!CONFIG_BASE_DIR!\!TARGET_ALIAS!"
        echo !TARGET_ALIAS!>"!LAST_ALIAS_FILE!"
        echo.
        echo [계정 정보] 계정 Alias '!TARGET_ALIAS!' 프로파일로 진행합니다.
    ) else (
        echo.
        echo [오류] '!TARGET_ALIAS!' 계정 Alias에 해당하는 프로파일이 없습니다. %~n0 login을 먼저 진행하세요.
        goto :EOF
    )
) else (
    echo.
    echo [오류] 설정된 프로파일이 없습니다. %~n0 login을 먼저 진행하세요.
    goto :EOF
)

:: 4. 경로 처리
set "PROFILE_PATH_FILE=!CLAUDE_CONFIG_DIR!\last_path.txt"

if not "!NEW_PATH!"=="" (
    if exist "!NEW_PATH!" (
        echo !NEW_PATH!>"!PROFILE_PATH_FILE!"
        echo !NEW_PATH!>"!GLOBAL_PATH_FILE!"
    )
)

set "LAST_PATH="
if exist "!PROFILE_PATH_FILE!" set /p LAST_PATH=<"!PROFILE_PATH_FILE!"
if "!LAST_PATH!"=="" (
    if exist "!GLOBAL_PATH_FILE!" set /p LAST_PATH=<"!GLOBAL_PATH_FILE!"
)

if "!LAST_PATH!"=="" (
    echo.
    set /p LAST_PATH="이동할 경로를 입력하세요: "
    echo !LAST_PATH!>"!PROFILE_PATH_FILE!"
    echo !LAST_PATH!>"!GLOBAL_PATH_FILE!"
)

:: 5. 자동 세션 정보 확인 및 재개 여부 질문
set "RESUME_ARG="
set "S_ID="
set "S_PATH="
set "S_BRANCH="
set "S_TIME="
set "S_USER="
set "S_ASSISTANT="

for /f "tokens=1,* delims==" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -File "!PS_SCRIPT!" "!CLAUDE_CONFIG_DIR!" "!LAST_PATH!"') do (
    if "%%A"=="S_ID" set "S_ID=%%B"
    if "%%A"=="S_PATH" set "S_PATH=%%B"
    if "%%A"=="S_BRANCH" set "S_BRANCH=%%B"
    if "%%A"=="S_TIME" set "S_TIME=%%B"
    if "%%A"=="S_USER" set "S_USER=%%B"
    if "%%A"=="S_ASSISTANT" set "S_ASSISTANT=%%B"
)

if not "!S_ID!"=="" (
    echo.
    echo --------------------------------------------------
    echo [발견된 이전 세션 정보]
    echo  - 작업 위치: !S_PATH!
    echo  - Git 브랜치: !S_BRANCH!
    echo  - 세션 시간: !S_TIME!
    echo  - 세션 ID  : !S_ID!
    echo  - 최근 입력: !S_USER!
    echo --------------------------------------------------
    
    :ASK_SESSION
    set "USE_SESSION="
    set /p USE_SESSION="최근 세션을 이어서 시작할까요? (y/n) 또는 이전 세션 검색 개수 입력(숫자): "
    
    if /i "!USE_SESSION!"=="y" (
        set "RESUME_ARG=--resume !S_ID!"
        goto :RUN_CLAUDE
    )
    if /i "!USE_SESSION!"=="n" (
        goto :RUN_CLAUDE
    )
    
    if "!USE_SESSION!"=="" goto :ASK_SESSION

    set /a NUM_CHECK=!USE_SESSION! 2>nul
    if "!NUM_CHECK!"=="!USE_SESSION!" (
        if !USE_SESSION! GTR 0 (
            goto :FETCH_MULTIPLE_SESSIONS
        )
    )
    goto :ASK_SESSION
    
    :FETCH_MULTIPLE_SESSIONS
    echo.
    echo 최근 !USE_SESSION!개의 세션을 검색합니다...
    set "FOUND_COUNT=0"
    for /f "tokens=1,* delims==" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -File "!PS_SCRIPT!" "!CLAUDE_CONFIG_DIR!" "!LAST_PATH!" "!USE_SESSION!"') do (
        if "%%A"=="S_COUNT" set "FOUND_COUNT=%%B"
        for /l %%I in (1,1,!USE_SESSION!) do (
            if "%%A"=="S_ID_%%I" set "M_ID_%%I=%%B"
            if "%%A"=="S_PATH_%%I" set "M_PATH_%%I=%%B"
            if "%%A"=="S_BRANCH_%%I" set "M_BRANCH_%%I=%%B"
            if "%%A"=="S_TIME_%%I" set "M_TIME_%%I=%%B"
            if "%%A"=="S_USER_%%I" set "M_USER_%%I=%%B"
            if "%%A"=="S_ASSISTANT_%%I" set "M_ASSISTANT_%%I=%%B"
        )
    )
    
    if "!FOUND_COUNT!"=="0" (
        echo 이전 세션이 없습니다.
        goto :ASK_SESSION
    )
    
    echo.
    echo --------------------------------------------------
    for /l %%I in (1,1,!FOUND_COUNT!) do (
        echo [%%I] 세션 시간: !M_TIME_%%I!
        echo     세션 ID  : !M_ID_%%I!
        echo     최근 입력: !M_USER_%%I!
        echo     AI의 답변: !M_ASSISTANT_%%I!
        echo.
    )
    echo --------------------------------------------------
    
    :SELECT_SESSION
    set "SEL_INDEX="
    set /p SEL_INDEX="연결할 세션 번호를 입력하세요 (취소: c): "
    if /i "!SEL_INDEX!"=="c" goto :ASK_SESSION
    
    set "SELECTED_ID="
    for /l %%I in (1,1,!FOUND_COUNT!) do (
        if "!SEL_INDEX!"=="%%I" set "SELECTED_ID=!M_ID_%%I!"
    )
    
    if not "!SELECTED_ID!"=="" (
        set "RESUME_ARG=--resume !SELECTED_ID!"
        goto :RUN_CLAUDE
    ) else (
        echo 잘못된 번호입니다.
        goto :SELECT_SESSION
    )
)

:RUN_CLAUDE
:: 6. Claude 실행
echo.
echo "!LAST_PATH!" 위치에서 Claude를 실행합니다...
echo.

cd /d "!LAST_PATH!"
claude !RESUME_ARG!

pause
goto :EOF

:: ==================================================
:: 명령어 처리 함수 모음
:: ==================================================

:DO_VERSION
echo Claude Code 실행기 버전: !VERSION!
goto :EOF

:DO_LOGIN
set /p NEW_ALIAS="로그인할 계정 Alias를 입력하세요: "
if not exist "!CONFIG_BASE_DIR!\!NEW_ALIAS!" mkdir "!CONFIG_BASE_DIR!\!NEW_ALIAS!"
set "CLAUDE_CONFIG_DIR=!CONFIG_BASE_DIR!\!NEW_ALIAS!"
echo !NEW_ALIAS!>"!LAST_ALIAS_FILE!"
echo [안내] '!NEW_ALIAS!' 계정 Alias 프로파일 환경에서 로그인을 진행합니다.
claude login
goto :EOF

:DO_COPY
set "SRC_ALIAS=!ARG2!"
set "NEW_ALIAS=!ARG3!"
if "!SRC_ALIAS!"=="" (
    set /p SRC_ALIAS="원본 계정 Alias를 입력하세요: "
)
if "!NEW_ALIAS!"=="" (
    set /p NEW_ALIAS="생성할 복제 계정 Alias를 입력하세요: "
)

if not exist "!CONFIG_BASE_DIR!\!SRC_ALIAS!" (
    echo [오류] 원본 계정 '!SRC_ALIAS!'가 존재하지 않습니다.
    goto :EOF
)
if exist "!CONFIG_BASE_DIR!\!NEW_ALIAS!" (
    echo [오류] 대상 계정 '!NEW_ALIAS!'가 이미 존재합니다.
    goto :EOF
)

mkdir "!CONFIG_BASE_DIR!\!NEW_ALIAS!"
for %%F in ("!CONFIG_BASE_DIR!\!SRC_ALIAS!\*") do (
    if /i not "%%~nxF"=="last_path.txt" (
        copy /Y "%%F" "!CONFIG_BASE_DIR!\!NEW_ALIAS!\" >nul
    )
)

set "CLAUDE_CONFIG_DIR=!CONFIG_BASE_DIR!\!NEW_ALIAS!"
echo !NEW_ALIAS!>"!LAST_ALIAS_FILE!"

echo [안내] '!SRC_ALIAS!' 계정의 인증 정보를 복제하여 독립적인 새 계정 '!NEW_ALIAS!'를 생성했습니다.
goto :EOF

:DO_RESET
echo claude_configs 내부의 모든 데이터를 초기화합니다.
if exist "!CONFIG_BASE_DIR!" rmdir /s /q "!CONFIG_BASE_DIR!"
mkdir "!CONFIG_BASE_DIR!"
echo 초기화가 완료되었습니다.
goto :EOF

:DO_LOGOUT
set "LOGOUT_ALIAS=!ARG2!"
if "!LOGOUT_ALIAS!"=="" (
    echo [오류] 로그아웃할 계정 Alias를 입력하세요. 예: %~n0 logout a
    goto :EOF
)
if exist "!CONFIG_BASE_DIR!\!LOGOUT_ALIAS!" (
    rmdir /s /q "!CONFIG_BASE_DIR!\!LOGOUT_ALIAS!"
    echo [안내] '!LOGOUT_ALIAS!' 계정 정보가 삭제되었습니다.
    if exist "!LAST_ALIAS_FILE!" (
        set /p CUR_LAST_ALIAS=<"!LAST_ALIAS_FILE!"
        if "!CUR_LAST_ALIAS!"=="!LOGOUT_ALIAS!" del "!LAST_ALIAS_FILE!"
    )
) else (
    echo [오류] '!LOGOUT_ALIAS!' 계정 Alias를 찾을 수 없습니다.
)
goto :EOF

:DO_INFO
echo.
echo ==================================================
echo                저장된 계정 정보 목록
echo ==================================================
if not exist "!CONFIG_BASE_DIR!" (
    echo 저장된 계정 정보가 없습니다.
    goto :EOF
)

set "GLOBAL_LAST_PATH="
if exist "!GLOBAL_PATH_FILE!" set /p GLOBAL_LAST_PATH=<"!GLOBAL_PATH_FILE!"

if not "!GLOBAL_LAST_PATH!"=="" (
    echo [공통 마지막 경로]: !GLOBAL_LAST_PATH!
    echo --------------------------------------------------
)

for /d %%D in ("!CONFIG_BASE_DIR!\*") do (
    set "ALIAS_NAME=%%~nxD"
    set "ALIAS_PATH="
    set "ACC_NAME="
    set "ACC_EMAIL="
    set "S_ID="
    set "S_PATH="
    set "S_BRANCH="
    set "S_TIME="
    set "S_USER="
    set "S_ASSISTANT="
    
    if exist "%%D\last_path.txt" set /p ALIAS_PATH=<"%%D\last_path.txt"
    
    if "!ALIAS_PATH!"=="" (
        set "ALIAS_PATH=전용경로없음"
    )
    
    for /f "tokens=1,* delims==" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -File "!PS_SCRIPT!" "%%D" ""') do (
        if "%%A"=="ACC_NAME" set "ACC_NAME=%%B"
        if "%%A"=="ACC_EMAIL" set "ACC_EMAIL=%%B"
        if "%%A"=="S_ID" set "S_ID=%%B"
        if "%%A"=="S_PATH" set "S_PATH=%%B"
        if "%%A"=="S_BRANCH" set "S_BRANCH=%%B"
        if "%%A"=="S_TIME" set "S_TIME=%%B"
        if "%%A"=="S_USER" set "S_USER=%%B"
        if "%%A"=="S_ASSISTANT" set "S_ASSISTANT=%%B"
    )
    
    if not "!ACC_NAME!"=="" (
        echo [계정 Alias: !ALIAS_NAME! ^(!ACC_NAME! - !ACC_EMAIL!^)]
    ) else (
        echo [계정 Alias: !ALIAS_NAME!]
    )
    echo  - 마지막 위치: !ALIAS_PATH!
    if not "!S_ID!"=="" (
        echo  - 세션 위치: !S_PATH!
        echo  - Git 브랜치: !S_BRANCH!
        echo  - 세션 시간: !S_TIME!
        echo  - 세션 ID  : !S_ID!
        echo  - 최근 입력: !S_USER!
    ) else (
        echo  - 이전 세션  : 없음
    )
    echo.
)
echo ==================================================
goto :EOF

:SHOW_HELP
echo.
echo ==================================================
echo                Claude Code 실행기 v!VERSION!
echo ==================================================
echo.
echo [사용법]
echo  %~n0                        : 마지막으로 사용한 계정과 마지막 경로에서 실행
echo  %~n0 login                  : 새로운 계정 프로파일 생성 및 로그인
echo  %~n0 copy [원본Alias] [신규Alias] : 기존 계정의 인증 정보를 복제하여 독립적인 새 계정 생성
echo  %~n0 logout [Alias]         : 특정 계정 Alias 정보 및 세션 삭제
echo  %~n0 reset                  : 저장된 모든 계정, 경로, 세션 정보 초기화
echo  %~n0 info                   : 저장된 계정 목록 및 세션 정보 출력
echo  %~n0 version                : 현재 스크립트 버전 출력
echo  %~n0 [계정 Alias]           : 지정한 계정의 마지막 경로 또는 전체 마지막 경로에서 실행
echo  %~n0 [경로]                 : 마지막 계정으로 지정한 경로에서 실행
echo  %~n0 [계정 Alias] [경로]    : 지정한 계정으로 지정한 경로에서 실행
echo  %~n0 -h, --help             : 현재 도움말 표시
echo.
echo [기능 설명]
echo  - 계정 프로파일 기능: 설정 디렉토리를 활용하여 계정별로 독립된 환경 제공
echo  - 계정 복제 기능: copy 명령어를 통해 인증 정보는 공유하면서 작업 내역은 분리된 새로운 환경 생성
echo  - 작업 경로 독립: 계정별로 마지막 작업 경로를 기억
echo  - 자동 세션 복구: 종료 시 수동 입력 없이 Claude가 생성한 jsonl 파일에서 자동으로 마지막 작업 내역 추출
echo.
echo [예시]
echo  %~n0 login              -^> 계정 Alias a로 로그인
echo  %~n0 copy a a1              -^> a 계정 인증을 복제하여 작업 내역이 독립적인 a1 계정 생성
echo  %~n0 a D:\workspace         -^> a 계정으로 D:\workspace 에서 작업 후 종료 시 자동 세션 저장
echo  %~n0 a1 E:\project          -^> a1 계정으로 E:\project 에서 작업
echo  %~n0 logout a1              -^> a1 계정 정보 삭제
echo  %~n0 reset              -^> 전체 정보 초기화
echo.
echo ==================================================
goto :EOF