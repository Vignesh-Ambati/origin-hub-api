@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

rem =====================================================================
rem  Origin Hub API - Environment Setup
rem
rem  Usage:
rem     setup.bat                 normal provisioning
rem     setup.bat --no-pause      accepted, no-op (never pauses anyway)
rem     setup.bat --upgrade-pip   also upgrade pip to latest
rem     setup.bat --recreate      wipe .venv first and rebuild it
rem     setup.bat --runtime-only  omit test tools (used by start_up.bat)
rem     setup.bat --skip-install  skip pip when dependencies are verified
rem
rem  Exit codes:
rem     0  success
rem     1  Python not found in PATH
rem     2  venv creation failed
rem     3  pip install failed
rem     4  .env missing and no .env.example to seed from
rem     5  invalid command-line argument
rem     6  pyproject.toml missing or unreadable
rem =====================================================================

set "APP_NAME=Origin Hub API"
set "LOG_DIR=%~dp0logs"
set "SETUP_LOG=%LOG_DIR%\setup.log"
set "PIP_LOG=%LOG_DIR%\pip-install.log"
set "VENV_DIR=.venv"
set "VENV_PY=%VENV_DIR%\Scripts\python.exe"
set "ENV_FILE=.env"
set "ENV_EXAMPLE=.env.example"
set "PYPROJECT=pyproject.toml"

set "UPGRADE_PIP=0"
set "RECREATE_VENV=0"
set "INSTALL_TEST=1"
set "SKIP_INSTALL=0"

rem ---------------------------------------------------------------------
rem  Parse arguments
rem ---------------------------------------------------------------------
:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="--no-pause"     ( shift & goto :parse_args )
if /i "%~1"=="--upgrade-pip"  ( set "UPGRADE_PIP=1"    & shift & goto :parse_args )
if /i "%~1"=="--recreate"     ( set "RECREATE_VENV=1"  & shift & goto :parse_args )
if /i "%~1"=="--runtime-only" ( set "INSTALL_TEST=0"   & shift & goto :parse_args )
if /i "%~1"=="--skip-install" ( set "SKIP_INSTALL=1"   & shift & goto :parse_args )
echo [ERROR] Unknown argument: %~1
echo         Supported: --no-pause  --upgrade-pip  --recreate
echo                    --runtime-only  --skip-install
exit /b 5
:args_done

rem ---------------------------------------------------------------------
rem  Log directory
rem ---------------------------------------------------------------------
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

echo =================================================== >> "%SETUP_LOG%"
echo [%DATE% %TIME%] %APP_NAME% setup starting >> "%SETUP_LOG%"
echo =================================================== >> "%SETUP_LOG%"

echo ===================================================
echo       %APP_NAME% - Environment Setup
echo ===================================================
echo.

rem ---------------------------------------------------------------------
rem  0. pyproject.toml must exist
rem ---------------------------------------------------------------------
if not exist "%PYPROJECT%" (
    echo [FATAL] %PYPROJECT% not found in %CD%.
    echo         Run this script from the project root.
    echo [FATAL] %PYPROJECT% missing >> "%SETUP_LOG%"
    exit /b 6
)

rem ---------------------------------------------------------------------
rem  1. Python must be in PATH
rem     We do NOT check version here. pip is the authoritative checker
rem     against requires-python in pyproject.toml, and its error message
rem     is clearer than anything this script could produce.
rem ---------------------------------------------------------------------
where python >nul 2>&1
if errorlevel 1 (
    echo [FATAL] Python not found in PATH.
    echo         Install Python from python.org and make sure
    echo         "Add Python to PATH" is checked during install.
    echo [FATAL] python not in PATH >> "%SETUP_LOG%"
    exit /b 1
)

for /f "tokens=*" %%V in ('python -V 2^>^&1') do (
    echo [1/6] Detected %%V
    echo [1/6] Detected %%V >> "%SETUP_LOG%"
)
echo.

rem ---------------------------------------------------------------------
rem  2. Create (or recreate) the virtual environment
rem ---------------------------------------------------------------------
if "%RECREATE_VENV%"=="1" (
    if exist "%VENV_DIR%" (
        echo [2/6] --recreate requested: removing existing %VENV_DIR%...
        echo [2/6] Removing %VENV_DIR% >> "%SETUP_LOG%"
        rmdir /s /q "%VENV_DIR%"
        if exist "%VENV_DIR%" (
            echo [FATAL] Could not remove %VENV_DIR%. Close any shell using it.
            echo [FATAL] rmdir failed >> "%SETUP_LOG%"
            exit /b 2
        )
    )
)

if not exist "%VENV_PY%" (
    echo [2/6] Creating virtual environment: %VENV_DIR%...
    echo [2/6] Creating venv >> "%SETUP_LOG%"
    python -m venv "%VENV_DIR%" >> "%SETUP_LOG%" 2>&1
    if errorlevel 1 (
        echo [FATAL] Failed to create virtual environment.
        echo         See %SETUP_LOG% for details.
        echo [FATAL] python -m venv failed >> "%SETUP_LOG%"
        exit /b 2
    )
    if not exist "%VENV_PY%" (
        echo [FATAL] venv command reported success but %VENV_PY% is missing.
        echo [FATAL] venv incomplete >> "%SETUP_LOG%"
        exit /b 2
    )
    echo [2/6] Virtual environment created.
) else (
    echo [2/6] Virtual environment already present: %VENV_DIR%
)
echo.

rem ---------------------------------------------------------------------
rem  3. Upgrade pip only when explicitly requested
rem ---------------------------------------------------------------------
if "%UPGRADE_PIP%"=="1" (
    echo [3/6] Upgrading pip ^(--upgrade-pip specified^)...
    echo [3/6] Upgrading pip >> "%SETUP_LOG%"
    "%VENV_PY%" -m pip install --upgrade pip >> "%SETUP_LOG%" 2>&1
    if errorlevel 1 (
        echo [WARN] Pip upgrade failed - continuing with bundled version.
        echo [WARN] pip upgrade failed >> "%SETUP_LOG%"
    ) else (
        echo [3/6] Pip upgraded.
    )
) else (
    echo [3/6] Skipping pip upgrade ^(pass --upgrade-pip to force^).
)
echo.

rem ---------------------------------------------------------------------
rem  4. Install project and selected dependencies
rem     We write full pip output to %PIP_LOG% and, on failure, echo the
rem     last lines to the console so the user sees the real reason.
rem ---------------------------------------------------------------------
if "%SKIP_INSTALL%"=="1" goto :install_skipped

rem Clear any stale log from a prior failed run.
echo [4/6] Clearing stale pip log...
if exist "%PIP_LOG%" del /f /q "%PIP_LOG%" >nul 2>&1

set "PIP_TARGET=.[test]"
if "%INSTALL_TEST%"=="0" set "PIP_TARGET=."
echo [4/6] Installing project dependencies from %PYPROJECT%...
echo        Pip details: %PIP_LOG%
echo.
echo [4/6] pip install -e %PIP_TARGET% >> "%SETUP_LOG%"
echo --------------------------------------------------- >> "%PIP_LOG%"
echo [%DATE% %TIME%] pip install -e %PIP_TARGET% >> "%PIP_LOG%"
echo --------------------------------------------------- >> "%PIP_LOG%"

"%VENV_PY%" -m pip install --quiet --disable-pip-version-check -e "%PIP_TARGET%" > "%PIP_LOG%" 2>&1
set "PIP_RC=%errorlevel%"

rem Also append pip output into the consolidated setup log.
type "%PIP_LOG%" >> "%SETUP_LOG%" 2>nul

if not "%PIP_RC%"=="0" (
    echo [FATAL] pip install failed with exit code %PIP_RC%.
    echo.
    echo ----- Last 25 lines of pip output -----
    call :tail "%PIP_LOG%" 25
    echo ----------------------------------------
    echo.
    echo Full pip output saved to: %PIP_LOG%
    echo Consolidated log:         %SETUP_LOG%
    echo.
    echo [FATAL] pip install failed ^(exit %PIP_RC%^) >> "%SETUP_LOG%"
    exit /b 3
)

echo [4/6] Dependencies installed successfully.
echo.
goto :install_done

:install_skipped
echo [4/6] Dependencies already verified; skipping pip install.
echo [4/6] Pip install skipped after startup verification >> "%SETUP_LOG%"
echo.
:install_done

rem ---------------------------------------------------------------------
rem  5. Verify that app.main is locatable by the new interpreter
rem ---------------------------------------------------------------------
echo [5/6] Verifying that the application module can be located...
"%VENV_PY%" -c "import importlib.util, sys; sys.exit(0 if importlib.util.find_spec('app.main') else 1)" >> "%SETUP_LOG%" 2>&1
if errorlevel 1 (
    echo [FATAL] Application module 'app.main' cannot be located.
    echo         Check that pyproject.toml declares the 'app' package
    echo         and that app/main.py exists.
    echo [FATAL] app.main not importable >> "%SETUP_LOG%"
    exit /b 3
)
echo [5/6] Application module located OK.
echo.

rem ---------------------------------------------------------------------
rem  6. Ensure .env exists (never overwrite an existing one)
rem ---------------------------------------------------------------------
echo [6/6] Checking for %ENV_FILE%...
if exist "%ENV_FILE%" (
    echo [6/6] %ENV_FILE% already present - leaving untouched.
    echo [6/6] %ENV_FILE% present, not overwritten >> "%SETUP_LOG%"
) else (
    if exist "%ENV_EXAMPLE%" (
        copy /y "%ENV_EXAMPLE%" "%ENV_FILE%" >nul
        echo [6/6] Seeded %ENV_FILE% from %ENV_EXAMPLE%.
        echo       ^>^> EDIT %ENV_FILE% and set real values before starting. ^<^<
        echo [6/6] Seeded %ENV_FILE% from %ENV_EXAMPLE% >> "%SETUP_LOG%"
    ) else (
        echo [FATAL] %ENV_FILE% missing and no %ENV_EXAMPLE% to seed from.
        echo         Create %ENV_FILE% with real settings, then re-run.
        echo [FATAL] No .env and no .env.example >> "%SETUP_LOG%"
        exit /b 4
    )
)
echo.

rem ---------------------------------------------------------------------
rem  Done
rem ---------------------------------------------------------------------
echo ===================================================
echo       Setup completed successfully
echo ===================================================
echo   Virtual environment:  %VENV_DIR%
echo   Setup log:            %SETUP_LOG%
echo.
echo   Next steps:
echo     1. Review %ENV_FILE% and set real values.
echo     2. Run start_up.bat to launch the API server.
echo ===================================================
echo.
echo [%DATE% %TIME%] setup completed successfully >> "%SETUP_LOG%"

endlocal
exit /b 0

rem =====================================================================
rem  Subroutine: tail
rem  Prints the last N lines of a file. Called as:
rem     call :tail "path\to\file" 25
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