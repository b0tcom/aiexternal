@echo off
echo ========================================
echo    AI Assist External Pipeline
echo ========================================
echo.
echo Select launch mode:
echo [1] GUI Interface (Recommended)
echo [2] Command Line Mode
echo [3] Exit
echo.
set /p choice="Enter your choice (1-3): "

if "%choice%"=="1" goto gui_mode
if "%choice%"=="2" goto cli_mode
if "%choice%"=="3" goto exit
echo Invalid choice. Please select 1, 2, or 3.
pause
goto start

:gui_mode
echo.
echo Starting AI Assist GUI Interface...
echo.
goto setup

:cli_mode
echo.
echo Starting AI Assist Command Line...
echo.
goto setup

:setup
REM Change to the project directory
cd /d "C:\Users\Dorian\code\ai-assist-external"

REM Add cuDNN to PATH for this session
set "PATH=%CD%\_deps\cudnn9\bin;%PATH%"
echo Added cuDNN to PATH: %CD%\_deps\cudnn9\bin

REM Activate the virtual environment
call ".venv\Scripts\activate.bat"

REM Launch the appropriate mode
if "%choice%"=="1" (
    echo Launching GUI...
    python -m src.ui.gui_app
) else (
    echo Launching Command Line...
    python -m src.ui.app --config configs/settings.json
)

echo.
echo AI Assist pipeline has stopped.
pause
goto exit

:exit
