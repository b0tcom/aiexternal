# Requires: Windows 10/11, NVIDIA driver supporting CUDA 12.8+, TensorRT installed
# Run as:  powershell -ExecutionPolicy Bypass -File .\train_fortnite_5080.ps1

<#
CHANGES:
  * Replaced invalid bash style 'python - << PY' heredocs with PowerShell here-strings piped to python.
  * Added Install-TorchGpu function that attempts (cu128 nightly -> cu124 stable) and validates CUDA build.
  * Added Test-TorchGpu function that runs a GPU smoke test (tensor op on CUDA) and checks device capability.
  * Dynamic selection of device; clear diagnostics if CUDA unavailable.
  * Force GPU-only training (device=0) and fail fast if CUDA cannot be used.
  * Skip dataset re-extraction if already extracted & data.yaml present (use -Force to refresh).
  * Removed unused DATASET_URL (dataset already local) to avoid any accidental re-download logic.
  * Added --batch auto when on GPU; script no longer falls back to CPU.
  * Added more explicit output coloring & summary.
  * Added optional -ForceExtract and -ForceReinstall switches.
#>

param(
  [switch]$ForceExtract,
  [switch]$ForceReinstall,
  [int]$EpochsOverride
)

$ErrorActionPreference = "Stop"

# ---- SETTINGS ----
$WORKDIR     = "$PWD\fortnite_yolo12"
$IMGSZ       = 1280
$EPOCHS      = if ($EpochsOverride) { $EpochsOverride } else { 60 }
$MODEL       = "yolo12s.pt"
$TRTEXEC     = "trtexec.exe"   # e.g. "C:\Program Files\NVIDIA Corporation\TensorRT\bin\trtexec.exe"

# ---- PRECHECK: NVIDIA / Driver ----
if (-not (Get-Command nvidia-smi -ErrorAction SilentlyContinue)) {
  throw "nvidia-smi not found. Install NVIDIA driver (CUDA 12.8+ support) and make sure it's on PATH."
}
Write-Host "GPU info:" -ForegroundColor Cyan
nvidia-smi

# ---- SETUP ----
Write-Host "Creating work dir: $WORKDIR"
New-Item -ItemType Directory -Force -Path $WORKDIR | Out-Null
Set-Location $WORKDIR

# Prefer parent venv if it exists
$parentVenv = "..\.venv\Scripts\Activate.ps1"
if (Test-Path $parentVenv) {
  Write-Host "Activating existing parent virtual environment..."
  & $parentVenv
} else {
  Write-Host "Creating new Python venv in work dir..."
  python -m venv .venv
  .\.venv\Scripts\Activate.ps1
}

# Make sure this Python/pip are the venv ones
Write-Host "Python:" (Get-Command python).Source
Write-Host "Pip   :" (Get-Command pip).Source

function Invoke-Py {
  param([Parameter(Mandatory=$true)][string]$Code)
  $out = $Code | python
  $global:LASTPY = $out
  return $out
}

function Test-TorchGpu {
  Write-Host "(Torch) Probing GPU capability..." -ForegroundColor Cyan
  $probe = Invoke-Py -Code @'
import json, os
info = {
  "has_cuda_build": False,
  "cuda_available": False,
  "device_count": 0,
  "name_0": None,
  "capability_0": None,
  "smoke_ok": False,
  "smoke_err": "",
}
try:
    import torch
    info["has_cuda_build"] = bool(getattr(torch.version, "cuda", None))
    info["cuda_available"] = torch.cuda.is_available()
    if info["cuda_available"]:
        info["device_count"] = torch.cuda.device_count()
        info["name_0"] = torch.cuda.get_device_name(0)
        info["capability_0"] = tuple(torch.cuda.get_device_capability(0))
        try:
            x = torch.randn(1024, device='cuda')
            y = (x @ x.T).sum().item()
            info["smoke_ok"] = True
        except Exception as e:
            info["smoke_err"] = str(e)
except Exception as e:
    info["smoke_err"] = f"import_failed: {e}"
print(json.dumps(info))
'@
  try { return $probe | ConvertFrom-Json } catch { return $null }
}

function Install-TorchGpu {
  param([switch]$Force)
  Write-Host "(Torch) Ensuring GPU build..." -ForegroundColor Cyan
  if ($Force) {
    pip uninstall -y torch torchvision torchaudio 2>$null | Out-Null
  } else {
    $t = Test-TorchGpu
    if ($t -and $t.has_cuda_build -and $t.cuda_available -and $t.smoke_ok) {
      Write-Host "GPU torch is usable on device: $($t.name_0) (cap=$($t.capability_0))" -ForegroundColor Green
      return
    } else {
      Write-Host "Existing torch is not usable for CUDA (will reinstall). Details: $($t | ConvertTo-Json -Compress)" -ForegroundColor Yellow
    }
  }
  $attempts = @(
    @{ label = 'Nightly cu128 (preferred)'; cmd = 'pip install --pre --force-reinstall torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128' },
    @{ label = 'Stable cu124';           cmd = 'pip install --force-reinstall torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124' }
  )
  foreach ($a in $attempts) {
    Write-Host "Trying ${($a.label)}..." -ForegroundColor DarkCyan
    Invoke-Expression $a.cmd
    if ($LASTEXITCODE -ne 0) { Write-Host "Failed: $($a.label)" -ForegroundColor Yellow; continue }
    $t2 = Test-TorchGpu
    if ($LASTEXITCODE -eq 0 -and $t2 -and $t2.has_cuda_build -and $t2.cuda_available -and $t2.smoke_ok) {
      Write-Host ("Installed GPU torch ok: {0}" -f ($t2 | ConvertTo-Json -Compress)) -ForegroundColor Green
      return
    } else {
      Write-Host "Torch still not usable for CUDA after ${($a.label)}." -ForegroundColor Yellow
    }
  }
  throw "Could not install a CUDA-enabled torch that runs on your GPU."
}

Write-Host "Installing dependencies (Torch GPU first)..." -ForegroundColor Cyan
python -m pip install --upgrade pip wheel setuptools
Install-TorchGpu -Force:$ForceReinstall
pip install --upgrade numpy pillow tqdm pyyaml opencv-python
pip install --no-deps ultralytics
pip install onnx onnxruntime-gpu

$cudaCheck = Invoke-Py -Code @'
import torch, os, json
info = {
  "torch_version": torch.__version__,
  "compiled_cuda": torch.version.cuda,
  "cuda_available": torch.cuda.is_available(),
  "device_count": torch.cuda.device_count() if torch.cuda.is_available() else 0,
}
if torch.cuda.is_available():
  info['devices'] = {i: {"name": torch.cuda.get_device_name(i), "capability": torch.cuda.get_device_capability(i)} for i in range(torch.cuda.device_count())}
print(json.dumps(info, indent=2))
'@
if ($LASTEXITCODE -ne 0) { throw "Torch import failed." }
Write-Host $cudaCheck -ForegroundColor Green

# Force GPU only
$t = Test-TorchGpu
if (-not $t -or -not $t.cuda_available -or -not $t.smoke_ok) {
  throw "CUDA/GPU not usable from this Python env. Aborting (GPU-only). Details: $($t | ConvertTo-Json -Compress)"
}
$env:CUDA_VISIBLE_DEVICES = "0"
$DEVICE = '0'
Write-Host "Selected training device: GPU $DEVICE ($($t.name_0), cap=$($t.capability_0))" -ForegroundColor Cyan

# ---- DATASET ----
Write-Host "Using existing dataset zip..." -ForegroundColor Cyan
$zipPath = "$PWD\..\models\fortnite.v1i.yolov12.zip"
if (-not (Test-Path $zipPath)) { throw "Dataset zip not found at $zipPath" }

$dst = "$WORKDIR\dataset"
if (-not (Test-Path $dst) -or $ForceExtract) {
  if ($ForceExtract -and (Test-Path $dst)) { Write-Host "Force extracting: removing old dataset" -ForegroundColor Yellow; Remove-Item -Recurse -Force $dst }
  Write-Host "Extracting dataset..." -ForegroundColor Cyan
  Expand-Archive -Path $zipPath -DestinationPath $dst -Force
} else {
  Write-Host "Dataset already extracted (use -ForceExtract to refresh)" -ForegroundColor DarkGray
}

Write-Host "Locating data.yaml..." -ForegroundColor Cyan
$yamlCandidates = Get-ChildItem -Path $dst -Recurse -Filter *.yaml
$yaml = $null
foreach ($f in $yamlCandidates) {
  try {
    $t = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction Stop
    if ($t -match 'train:\s' -and $t -match 'val:\s') { $yaml = $f.FullName; break }
  } catch {}
}
if (-not $yaml) {
  Write-Host "YAML candidates scanned:" -ForegroundColor Yellow
  $yamlCandidates | ForEach-Object { Write-Host " - $_" -ForegroundColor DarkGray }
  throw "Could not find data.yaml with 'train:' and 'val:' entries under $dst."
}
Write-Host "Using data file: $yaml" -ForegroundColor Green

# Optional: allocator tuning to reduce fragmentation at large imgsz
$env:PYTORCH_CUDA_ALLOC_CONF = "max_split_size_mb:128,expandable_segments:True"

# ---- TRAIN ----
${BATCH} = -1    # auto tune on GPU
${WORKERS} = 8
Write-Host "Training $MODEL (epochs=$EPOCHS img=$IMGSZ device=$DEVICE batch=$BATCH workers=$WORKERS)" -ForegroundColor Cyan
python -m ultralytics detect train model=$MODEL data="$yaml" imgsz=$IMGSZ epochs=$EPOCHS device=$DEVICE batch=$BATCH workers=$WORKERS project="$WORKDIR\runs" name="fortnite_yolo12"

if ($LASTEXITCODE -ne 0) { throw "Training failed (exit code $LASTEXITCODE)." }

# ---- ARTIFACTS ----
$runsDetect = Join-Path $WORKDIR 'runs\detect'
if (-not (Test-Path $runsDetect)) { throw "Runs folder not created at $runsDetect" }

$best = Get-ChildItem $runsDetect -Recurse -Filter best.pt | Sort-Object LastWriteTime -Descending | Select-Object -ExpandProperty FullName -First 1
if (-not $best) { throw "best.pt not found" }
Write-Host "Best weights: $best" -ForegroundColor Green

# ---- EXPORT ONNX ----
Write-Host "Exporting ONNX..." -ForegroundColor Cyan
python -m ultralytics export model="$best" format=onnx opset=17 dynamic=True imgsz=$IMGSZ device=$DEVICE
$onnx = Join-Path (Split-Path $best -Parent) "best.onnx"
if (-not (Test-Path $onnx)) {
  $onnx = (Get-ChildItem -Recurse -Filter best.onnx | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
Write-Host "ONNX: $onnx"

# ---- TENSORRT BUILD (FP16; try FP8 manually later if your TRT supports it) ----
Write-Host "Building TensorRT FP16 engine..." -ForegroundColor Cyan
$engine = Join-Path (Split-Path $best -Parent) "best_fp16.engine"
& $TRTEXEC `
  --onnx="$onnx" `
  --saveEngine="$engine" `
  --fp16 `
  --workspace=4096 `
  --minShapes=images:1x3x640x640 `
  --optShapes=images:1x3x960x960 `
  --maxShapes=images:1x3x$IMGSZx$IMGSZ

if (-not (Test-Path $engine)) {
  throw "TensorRT engine not created. Check TensorRT install and trtexec path."
}

Write-Host ""
Write-Host "All done ✅"
Write-Host "PT  : $best"
Write-Host "ONNX: $onnx"
Write-Host "TRT : $engine"
