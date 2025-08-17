@echo off
setlocal enableextensions enabledelayedexpansion

rem ========= CONFIG =========
set "PROJECT_DIR=%~dp0"
set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"
set "DEPS_DIR=%PROJECT_DIR%\\_deps\\cudnn9"
set "BIN_DIR=%DEPS_DIR%\\bin"
set "INC_DIR=%DEPS_DIR%\\include"
set "LIB_DIR=%DEPS_DIR%\\lib"
set "VENV_PY=%PROJECT_DIR%\\.venv\\Scripts\\python.exe"
set "LOCAL_ZIP=%PROJECT_DIR%\\cudnn-windows-x86_64-9.zip"
rem Optional env flags when running:
rem   set INSTALL_CUDA=1     (also copy into %CUDA_PATH%\bin if writable)
rem   set PERSIST_PATH=1     (append BIN_DIR to User PATH)
rem   set CUDNN_URL=...      (direct, non-interactive link)

echo [INFO] Project: %PROJECT_DIR%

rem ========= PREP =========
if not exist "%DEPS_DIR%" mkdir "%DEPS_DIR%"
if not exist "%BIN_DIR%"  mkdir "%BIN_DIR%"
if not exist "%INC_DIR%"  mkdir "%INC_DIR%"
if not exist "%LIB_DIR%"  mkdir "%LIB_DIR%"

rem ========= GET ZIP =========
set "ZIP_PATH="
if exist "%LOCAL_ZIP%" (
  set "ZIP_PATH=%LOCAL_ZIP%"
  echo [OK] Using local cuDNN zip: %ZIP_PATH%
) else if defined CUDNN_URL (
  set "TMPD=%TEMP%\\cudnn9_%RANDOM%"
  mkdir "%TMPD%" 1>nul 2>nul
  echo [INFO] Downloading cuDNN 9...
  powershell -NoProfile -Command "Invoke-WebRequest -Uri $env:CUDNN_URL -OutFile '%TMPD%\\cudnn.zip'"
  if exist "%TMPD%\\cudnn.zip" ( set "ZIP_PATH=%TMPD%\\cudnn.zip" ) else (
    echo [ERROR] Download failed. Place the zip as "%LOCAL_ZIP%".
    exit /b 1
  )
) else (
  echo [ERROR] Provide cuDNN 9 zip as "%LOCAL_ZIP%" or set CUDNN_URL.
  exit /b 1
)

rem ========= EXTRACT to project-local deps =========
echo [INFO] Extracting to %DEPS_DIR% ...
powershell -NoProfile -Command ^
  "$ErrorActionPreference='Stop';" ^
  "Expand-Archive -Force '%ZIP_PATH%' '%DEPS_DIR%\\unz';" ^
  "$dlls = Get-ChildItem -Recurse '%DEPS_DIR%\\unz' -Include cudnn64_9.dll,cudnn*_infer64_9.dll,cudnn*_train64_9.dll;" ^
  "foreach($d in $dlls){ Copy-Item $d.FullName '%BIN_DIR%' -Force }" ^
  "$hdrs = Get-ChildItem -Recurse '%DEPS_DIR%\\unz' -Include cudnn*.h;" ^
  "foreach($h in $hdrs){ Copy-Item $h.FullName '%INC_DIR%' -Force }" ^
  "$libs = Get-ChildItem -Recurse '%DEPS_DIR%\\unz' -Include *.lib;" ^
  "foreach($l in $libs){ Copy-Item $l.FullName '%LIB_DIR%' -Force }"

if not exist "%BIN_DIR%\\cudnn64_9.dll" (
  echo [ERROR] cudnn64_9.dll not found after extraction.
  exit /b 1
)
echo [OK] Project-local cuDNN ready in %BIN_DIR%

rem ========= OPTIONAL: also copy into CUDA (no deletes, skip if exists) =========
if not defined INSTALL_CUDA goto :skip_cuda
if not defined CUDA_PATH (
  for /f "delims=" %%D in ('dir /ad /b "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA" 2^>nul ^| sort /r') do (
    set "CUDA_PATH=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\%%D"
    goto :got_cuda
  )
)
:got_cuda
if defined CUDA_PATH (
  set "CUDA_BIN=%CUDA_PATH%\\bin"
  echo [INFO] Attempting non-destructive copy to %CUDA_BIN%
  for %%F in ("%BIN_DIR%\\cudnn64_9.dll") do if not exist "%CUDA_BIN%\\%%~nxF" copy /y "%%~fF" "%CUDA_BIN%" >nul
  for %%F in ("%BIN_DIR%\\cudnn*_infer64_9.dll") do if not exist "%CUDA_BIN%\\%%~nxF" copy /y "%%~fF" "%CUDA_BIN%" >nul
  for %%F in ("%BIN_DIR%\\cudnn*_train64_9.dll") do if not exist "%CUDA_BIN%\\%%~nxF" copy /y "%%~fF" "%CUDA_BIN%" >nul
  echo [OK] (Optional) CUDA bin updated if missing files; nothing removed or overwritten.
) else (
  echo [WARN] CUDA not found; skipping CUDA install.
)
:skip_cuda

rem ========= VENV-aware loader: sitecustomize + PATH prepend (session-only) =========
set "SITE_PACK=%PROJECT_DIR%\\.venv\\Lib\\site-packages"
if exist "%SITE_PACK%" (
  echo [INFO] Writing sitecustomize.py to add DLL directory...
  >"%SITE_PACK%\\sitecustomize.py" (
    echo import os, sys
    echo _p = r"%BIN_DIR%"
    echo try:
    echo ^    os.add_dll_directory(_p)
    echo except Exception:
    echo ^    pass
  )
) else (
  echo [WARN] Could not find venv site-packages, skipping sitecustomize.py
)

rem Session-only PATH so you can run immediately:
set "PATH=%BIN_DIR%;%PATH%"
echo [OK] Prepending project-local cuDNN to PATH for this session only.

rem ========= Fallback: co-locate DLLs next to ORT CUDA provider (no deletions) =========
set "ORTDLLDIR="
for /f "delims=" %%P in ('dir /b /s "%PROJECT_DIR%\\.venv\\Lib\\site-packages\\onnxruntime\\capi\\onnxruntime_providers_cuda.dll" 2^>nul') do set "ORTDLLDIR=%%~dpP"
if not defined ORTDLLDIR (
  for /f "delims=" %%P in ('dir /b /s "%PROJECT_DIR%\\.venv\\lib\\site-packages\\onnxruntime\\capi\\onnxruntime_providers_cuda.dll" 2^>nul') do set "ORTDLLDIR=%%~dpP"
)
if defined ORTDLLDIR (
  echo [INFO] Co-locating cuDNN DLLs next to onnxruntime_providers_cuda.dll (safe add)...
  for %%F in ("%BIN_DIR%\\cudnn64_9.dll" "%BIN_DIR%\\cudnn*_infer64_9.dll" "%BIN_DIR%\\cudnn*_train64_9.dll") do (
    for %%G in (%%~F) do if exist "%%~fG" copy /y "%%~fG" "%ORTDLLDIR%" >nul
  )
) else (
  echo [WARN] onnxruntime CUDA provider not found in venv; ensure onnxruntime-gpu is installed.
)

rem ========= Optional: persist PATH (non-destructive append) =========
if not defined PERSIST_PATH goto :verify
for /f "tokens=2* delims= " %%A in ('reg query "HKCU\\Environment" /v PATH 2^>nul ^| find /i "PATH"') do set "USERPATH=%%B"
echo %USERPATH% | find /i "%BIN_DIR%" >nul
if errorlevel 1 (
  set "NEWPATH=%USERPATH%;%BIN_DIR%"
  setx PATH "%NEWPATH%" >nul
  echo [OK] Appended project cuDNN bin to User PATH (no removals).
) else (
  echo [OK] User PATH already includes project cuDNN bin.
)

rem ========= Verify =========
:verify
set "PYEXE=%VENV_PY%"
if not exist "%PYEXE%" for %%X in (python.exe) do set "PYEXE=%%~$PATH:X"
if not exist "%PYEXE%" (
  echo [WARN] Python not found for verification; done.
  goto :done
)

"%PYEXE%" - <<PYCODE
import os, sys
try:
    import onnxruntime as ort
    print("[PY] onnxruntime:", ort.__version__)
    print("[PY] providers:", ort.get_available_providers())
except Exception as e:
    print("[PY][ERROR]", e)
    sys.exit(1)
else:
    sys.exit(0)
PYCODE

if errorlevel 1 (
  echo [ERROR] Verification failed. Try a new terminal so session PATH refreshes, or confirm venv activation.
  exit /b 1
)

:done
echo [SUCCESS] Project-local cuDNN 9 installed without touching existing global installs.
exit /b 0
