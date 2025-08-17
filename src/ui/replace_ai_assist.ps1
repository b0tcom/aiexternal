param(
  [string]$SourcePath = "C:\Users\Dorian\code\ai-assist-external",
  [string]$RemoteUrl  = "https://github.com/b0tcom/ai.assist.git",
  [string]$Branch     = "main",
  [switch]$FreshHistory,   # if set: remove .git and start fresh
  [switch]$Yes            # if set: skip confirmation prompt
)

function Fail($msg) { Write-Error $msg; exit 1 }

# --- Preconditions ---
if (-not (Test-Path $SourcePath)) { Fail "SourcePath not found: $SourcePath" }
$git = (Get-Command git -ErrorAction SilentlyContinue)
if (-not $git) { Fail "git is not available in PATH. Install Git and retry." }

# Show plan
Write-Host "SourcePath : $SourcePath"
Write-Host "RemoteUrl  : $RemoteUrl"
Write-Host "Branch     : $Branch"
Write-Host "Mode       : " -NoNewline; if ($FreshHistory) { Write-Host "FRESH history" } else { Write-Host "KEEP local history" }

if (-not $Yes) {
  $resp = Read-Host "About to FORCE PUSH and replace remote '$RemoteUrl' branch '$Branch'. Continue? (yes/no)"
  if ($resp -notin @("y","Y","yes","YES")) { Write-Host "Aborted."; exit 0 }
}

# --- Move to project ---
Set-Location $SourcePath

# --- Fresh history option ---
if ($FreshHistory -and (Test-Path ".git")) {
  Write-Host "[INFO] Removing existing .git to start fresh..."
  Remove-Item -Recurse -Force ".git"
}

# --- Initialize / ensure repo ---
if (-not (Test-Path ".git")) {
  Write-Host "[INFO] git init"
  git init | Out-Null
}

# --- Remote origin (reset if exists) ---
$hasOrigin = (git remote | Select-String -SimpleMatch "origin") -ne $null
if ($hasOrigin) {
  git remote remove origin | Out-Null
}
git remote add origin $RemoteUrl

# --- Fetch remote (ignore errors if it’s empty/new) ---
git fetch origin 2>$null | Out-Null

# --- Checkout/reset branch locally ---
Write-Host "[INFO] Setting branch to $Branch"
git checkout -B $Branch | Out-Null

# --- Stage and commit everything ---
Write-Host "[INFO] Staging files..."
git add -A
# Commit only if there are changes (fresh or not)
$changes = git status --porcelain
if ($changes) {
  $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  git commit -m "Replace repo with ai-assist-external ($stamp)" | Out-Null
} else {
  Write-Host "[INFO] No changes to commit (working tree clean)."
}

# --- Force push to remote ---
Write-Host "[INFO] Force pushing $Branch to $RemoteUrl ..."
git push -u origin $Branch --force

Write-Host "[SUCCESS] Remote repository has been replaced with current project."
