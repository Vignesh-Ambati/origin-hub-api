@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

rem =====================================================================
rem  Origin Hub API - Startup Script
rem
rem  Behaviour:
rem    1. Verifies venv, .env, and dependencies.
rem    2. If anything is missing, runs setup.bat automatically.
rem    3. If setup fails, shows the real reason and drops into a shell.
rem    4. If everything is OK, asks whether to start the server.
rem         [Enter]  -> start the server
rem         anything -> stay in the venv with instructions
rem    5. The window NEVER closes on its own (unless --no-pause).
rem
rem  Usage:
rem     start_up.bat              normal interactive run
rem     start_up.bat --no-pause   non-interactive (for services/CI)
rem =====================================================================

set "PROJECT_NAME=Origin Hub API"
set "VENV_DIR=.venv"
set "VENV_PY=%VENV_DIR%\Scripts\python.exe"
set "VENV_ACT=%VENV_DIR%\Scripts\activate.bat"
set "ENV_FILE=.env"
set "SETUP_SCRIPT=setup.bat"
set "PYPROJECT=pyproject.toml"
set "PIP_LOG=logs\pip-install.log"
set "SETUP_LOG=logs\setup.log"
set "HOST=127.0.0.1"
set "PORT=8000"

set "NO_PAUSE=0"
if /i "%~1"=="--no-pause" set "NO_PAUSE=1"

echo ===================================================
echo       %PROJECT_NAME% - Startup
echo ===================================================
echo.

rem =====================================================================
rem  STEP 1 - Decide whether setup is needed
rem =====================================================================
set "NEED_SETUP=0"
set "DEPENDENCIES_OK=0"

if not exist "%VENV_PY%" (
    echo [CHECK] Virtual environment not found.
    set "NEED_SETUP=1"
)

if not exist "%ENV_FILE%" (
    echo [CHECK] Configuration file %ENV_FILE% not found.
    set "NEED_SETUP=1"
)

if not exist "%PYPROJECT%" (
    echo [CHECK] %PYPROJECT% not found.
    set "NEED_SETUP=1"
)

if "%NEED_SETUP%"=="0" (
    echo [CHECK] Verifying installed dependencies...
    "%VENV_PY%" -c "import tomllib, importlib.metadata, re, sys; deps = tomllib.load(open('pyproject.toml','rb')).get('project',{}).get('dependencies',[]); missing=[d for d in deps if not list(importlib.metadata.distributions(name=re.split(r'[><=~!\s;\[]', d)[0].strip()))]; sys.exit(0 if not missing else 1)" >nul 2>&1
    if errorlevel 1 (
        echo [CHECK] One or more dependencies are missing.
        set "NEED_SETUP=1"
    ) else (
        set "DEPENDENCIES_OK=1"
    )
)

if "%NEED_SETUP%"=="0" (
    echo [CHECK] Environment looks good.
    echo.
    goto :prompt_user
)

rem =====================================================================
rem  STEP 2 - Run setup
rem =====================================================================
echo.
echo [INFO] Running setup to prepare the environment.
echo        This may take a minute the first time.
echo.

if not exist "%SETUP_SCRIPT%" (
    echo [ERROR] %SETUP_SCRIPT% not found in %CD%.
    goto :fail_shell
)

if "%DEPENDENCIES_OK%"=="1" (
    call "%SETUP_SCRIPT%" --no-pause --skip-install
) else (
    call "%SETUP_SCRIPT%" --no-pause --runtime-only
)
set "SETUP_RC=%errorlevel%"

if not "%SETUP_RC%"=="0" (
    echo.
    echo ===================================================
    echo   [ERROR] Setup failed with exit code %SETUP_RC%.
    echo ===================================================
    echo.
    call :explain_setup_failure %SETUP_RC%
    echo.
    echo   Full logs:
    echo     %SETUP_LOG%
    echo     %PIP_LOG%
    goto :fail_shell
)

echo.
echo [INFO] Setup completed successfully.
echo.

if not exist "%VENV_PY%" (
    echo [ERROR] Setup returned 0 but %VENV_PY% does not exist.
    goto :fail_shell
)
if not exist "%ENV_FILE%" (
    echo [ERROR] Setup returned 0 but %ENV_FILE% does not exist.
    goto :fail_shell
)

echo [CHECK] Post-setup verification passed.
echo.

rem =====================================================================
rem  STEP 3 - Prompt the user
rem =====================================================================
:prompt_user
call "%VENV_ACT%"

echo ===================================================
echo       %PROJECT_NAME% - Ready
echo ===================================================
echo   Virtual environment: %VENV_DIR%  ^(activated^)
echo   Bind address:        %HOST%:%PORT%
echo.
echo   Press [Enter]        to start the API server now.
echo   Press any other key  to stay in the shell without starting it.
echo ===================================================
echo.

if "%NO_PAUSE%"=="1" goto :run_server

set "START_CHOICE="
set /p "START_CHOICE=Start server? [Enter = Yes / anything else = No]: "

if not "!START_CHOICE!"=="" goto :stay_in_venv

rem =====================================================================
rem  STEP 4 - Start the server
rem =====================================================================
:run_server
echo.
echo ===================================================
echo       %PROJECT_NAME% - Server Running
echo ===================================================
echo   Local URL:      http://%HOST%:%PORT%
echo   API Docs:       http://%HOST%:%PORT%/docs
echo   Alternative:    http://%HOST%:%PORT%/redoc
echo.
echo   Press Ctrl+C to stop the server.
echo ===================================================
echo.

uvicorn app.main:app --reload --host %HOST% --port %PORT%
set "UVICORN_RC=%errorlevel%"

echo.
if not "%UVICORN_RC%"=="0" (
    echo [ERROR] Server exited with code %UVICORN_RC%.
    echo         Read the output above to see what went wrong.
    echo         The virtual environment is still active below.
) else (
    echo [INFO] Server stopped normally.
)
echo.

rem =====================================================================
rem  STEP 5 - Stay in the venv
rem =====================================================================
:stay_in_venv
echo ===================================================
echo       %PROJECT_NAME% - Shell ^(%VENV_DIR% active^)
echo ===================================================
echo   You are inside the activated virtual environment.
echo.
echo   Start the API server:
echo     uvicorn app.main:app --reload --host %HOST% --port %PORT%
echo   or simply run:
echo     start_up.bat
echo.
echo   Re-run setup if the environment is ever broken:
echo     setup.bat
echo.
echo   Run the test suite:
echo     pytest
echo.
echo   Leave this shell:
echo     exit
echo ===================================================
echo.

if "%NO_PAUSE%"=="1" (
    endlocal
    exit /b 0
)

cmd /k
endlocal
exit /b 0

rem =====================================================================
rem  Failure path
rem =====================================================================
:fail_shell
echo ===================================================
echo       %PROJECT_NAME% - Setup Incomplete
echo ===================================================
echo   The environment is not ready.
echo   The reason is shown above. Read it before scrolling.
echo   This shell stays open so you can investigate.
echo.
echo   Useful commands:
echo     setup.bat              re-run environment setup
echo     type %SETUP_LOG%       view the setup log
echo     type %PIP_LOG%         view the pip install log
echo     dir .env*              list configuration files
echo     dir .venv              check the virtual environment
echo     python -V              check Python version
echo ===================================================
echo.

if "%NO_PAUSE%"=="1" (
    endlocal
    exit /b 1
)

cmd /k
endlocal
exit /b 1

rem =====================================================================
rem  Subroutine: explain_setup_failure
rem  Maps a setup.bat exit code to a plain-language explanation and,
rem  for install failures, dumps the tail of the pip log to the console.
rem =====================================================================
:explain_setup_failure
setlocal EnableDelayedExpansion
set "RC=%~1"

if "%RC%"=="1" (
    echo   Python was not found in PATH.
    echo   Install Python from python.org and make sure
    echo   "Add Python to PATH" is checked during install.
    endlocal
    exit /b 0
)
if "%RC%"=="2" (
    echo   Failed to create the virtual environment ^(.venv^).
    echo   Common causes:
    echo     - No disk space.
    echo     - Antivirus blocking python -m venv.
    echo     - The .venv folder is locked by another process.
    endlocal
    exit /b 0
)
if "%RC%"=="3" (
    echo   Dependency installation failed.
    echo   The actual pip error is shown below.
    echo.
    if exist "%PIP_LOG%" (
        echo   ----- Last 25 lines of pip output -----
        call :tail "%PIP_LOG%" 25
        echo   ----------------------------------------
    ) else (
        echo   ^(pip log not found: %PIP_LOG%^)
    )
    echo.
    echo   Common causes:
    echo     - Python version outside requires-python in pyproject.toml.
    echo       Fix: widen the range in pyproject.toml to include your
    echo       Python version, then run: setup.bat --recreate
    echo     - No network access to PyPI.
    echo     - A dependency version conflicts with another dependency.
    endlocal
    exit /b 0
)
if "%RC%"=="4" (
    echo   .env is missing and .env.example is not available to seed it.
    echo   Create a .env file manually with the values your app needs.
    endlocal
    exit /b 0
)
if "%RC%"=="5" (
    echo   setup.bat was called with an argument it does not understand.
    echo   This is likely a bug in start_up.bat, not something you did.
    endlocal
    exit /b 0
)
if "%RC%"=="6" (
    echo   pyproject.toml is missing from the project root.
    echo   Make sure you are running this script from the project folder.
    endlocal
    exit /b 0
)

echo   Unknown setup failure. See the logs for details.
endlocal
exit /b 0

rem =====================================================================
rem  Subroutine: tail
rem  Prints the last N lines of a file.
rem =====================================================================
:tail
setlocal EnableDelayedExpansion
set "TAIL_FILE=%~1"
set "TAIL_N=%~2"
if not exist "%TAIL_FILE%" (
    echo ^(file not found: %TAIL_FILE%^)
    endlocal
    exit /b 0
)
set /a TAIL_SKIP=0
for /f %%C in ('find /c /v "" ^< "%TAIL_FILE%"') do set /a TAIL_TOTAL=%%C
set /a TAIL_SKIP=TAIL_TOTAL-TAIL_N
if %TAIL_SKIP% lss 0 set /a TAIL_SKIP=0
set /a TAIL_LINE=0
for /f "usebackq delims=" %%L in ("%TAIL_FILE%") do (
    set /a TAIL_LINE+=1
    if !TAIL_LINE! gtr %TAIL_SKIP% echo %%L
)
endlocal
exit /b 0