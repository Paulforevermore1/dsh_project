# Create a personal GitHub repo — PowerShell wizard.
# PowerShell port of the /wizard bash template. Run from PowerShell:
#   powershell -ExecutionPolicy Bypass -File create-github-repo.ps1

param(
    [string]$RootPath = ""
)

$ErrorActionPreference = 'Stop'

$TOTAL_STAGES = 6
$script:_stageIndex = 0

function Enter-Stage([string]$Name) {
    Clear-Host
    $script:_stageIndex++
    Write-Host ""
    Write-Host ("▸ Stage {0}/{1} · {2}" -f $script:_stageIndex, $TOTAL_STAGES, $Name) -ForegroundColor Blue
}

function Show-Banner([string]$Title) {
    Clear-Host
    Write-Host ""
    Write-Host ("  {0}" -f $Title) -ForegroundColor Blue
    Write-Host ("  {0} stages" -f $TOTAL_STAGES) -ForegroundColor DarkGray
    Write-Host "  You drive the browser; this wizard tells you exactly what to do" -ForegroundColor DarkGray
    Write-Host "  and captures the values you copy back. Stop any time with Ctrl-C" -ForegroundColor DarkGray
    Write-Host "  and re-run later." -ForegroundColor DarkGray
    Read-Pause "Ready to start?"
}

function Write-Say([string]$Msg)  { Write-Host ("  {0}" -f $Msg) }
function Write-Step([string]$Msg) { Write-Host ("  • {0}" -f $Msg) -ForegroundColor Blue }
function Write-Note([string]$Msg) { Write-Host ("  {0}" -f $Msg) -ForegroundColor DarkGray }
function Write-Warn([string]$Msg) { Write-Host ("  ⚠ {0}" -f $Msg) -ForegroundColor Yellow }

function Open-Url([string]$Url) {
    Write-Host ("  ↗ opening {0}" -f $Url) -ForegroundColor Green
    try { Start-Process $Url } catch { Write-Warn ("couldn't open a browser; visit manually: {0}" -f $Url) }
}

function Read-Pause([string]$Msg = "Press Enter to continue") {
    Read-Host ("  {0}" -f $Msg) | Out-Null
}

function Read-Confirm([string]$Question) {
    $r = Read-Host ("  ? {0} [y/N]" -f $Question)
    return ($r -match '^[Yy]')
}

# Repository root: first argument if given, else the current directory.
if ([string]::IsNullOrWhiteSpace($RootPath)) { $RootPath = (Get-Location).Path }
Set-Location $RootPath

Show-Banner "Create a personal GitHub repo"

# ── Stage 1: prerequisites ────────────────────────────────────────────────
Enter-Stage "Prerequisites"
Write-Say ("Repository root: {0}" -f (Get-Location).Path)
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Warn "git not found."
    Open-Url "https://git-scm.com/downloads"
    Write-Note "or: winget install Git.Git"
    Read-Pause "Installed? Press Enter (or Ctrl-C to abort)"
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Warn "GitHub CLI (gh) not found."
    Open-Url "https://cli.github.com"
    Write-Note "or: winget install GitHub.cli"
    Read-Pause "Installed? Press Enter (or Ctrl-C to abort)"
}
try {
    $gitVer = git --version
    Write-Say ("git: {0}" -f $gitVer)
} catch { Write-Warn "git still not available."; exit 1 }
try {
    $ghVer = gh --version 2>$null | Select-Object -First 1
    Write-Say ("gh:  {0}" -f $ghVer)
} catch { Write-Warn "gh still not available."; exit 1 }
Read-Pause "Continue?"

# ── Stage 2: authenticate with GitHub ─────────────────────────────────────
Enter-Stage "GitHub authentication"
gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Say "Already authenticated:"
    gh auth status 2>&1 | ForEach-Object { Write-Host ("  {0}" -f $_) }
    Read-Pause "Continue with this account?"
} else {
    Write-Say "You're not logged into GitHub yet. A browser will open."
    Write-Step "Copy the one-time code gh prints below, paste it in the browser, and authorize."
    gh auth login --hostname github.com --git-protocol https --web
    Read-Pause "Logged in? Press Enter"
}

# ── Stage 3: repository details ───────────────────────────────────────────
Enter-Stage "Repository details"
$RepoName = Read-Host "  Repository name"
if ([string]::IsNullOrWhiteSpace($RepoName)) { $RepoName = Split-Path -Leaf (Get-Location).Path }
Write-Say "Visibility:"
Write-Step "1) public (anyone can read)"
Write-Step "2) private (only you)"
$VisReply = Read-Host "  Choose [1/2] (Enter = public)"
$RepoVis = "public"
if ($VisReply -eq "2") { $RepoVis = "private" }
$RepoDesc = Read-Host "  Description (optional)"

# ── Stage 4: git identity ─────────────────────────────────────────────────
Enter-Stage "Git identity"
$gitName = git config --global --get user.name 2>$null
$gitEmail = git config --global --get user.email 2>$null
if ($gitName -and $gitEmail) {
    Write-Say ("Commit identity: {0} <{1}>" -f $gitName, $gitEmail)
    Read-Pause "Use it? (Ctrl-C to change)"
} else {
    Write-Say "No commit name/email configured globally yet."
    $gitName = Read-Host "  Your name"
    $gitEmail = Read-Host "  Your email"
    git config --global user.name $gitName
    git config --global user.email $gitEmail
    Write-Note "set globally (applies to all your repos)."
}

# ── Stage 5: initialize & first commit ────────────────────────────────────
Enter-Stage "Initialize & first commit"
git rev-parse --git-dir 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Say "Already a git repository; skipping init."
} else {
    git init
}
git rev-parse --verify HEAD 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Say "Commits already exist; skipping first commit."
} else {
    git add -A
    git commit -m "Initial commit" --quiet
    if ($LASTEXITCODE -eq 0) {
        Write-Note "created the initial commit."
    } else {
        Write-Warn "nothing to commit, or the commit failed (see above)."
        Read-Pause "Continue anyway?"
    }
}

# ── Stage 6: create & push to GitHub ──────────────────────────────────────
Enter-Stage "Create & push to GitHub"
Write-Say ("Repository: {0}  ·  visibility: {1}" -f $RepoName, $RepoVis)
if ($RepoDesc) { Write-Say ("Description: {0}" -f $RepoDesc) }
$Owner = (gh api user --jq .login).Trim()
git remote remove origin 2>$null
gh repo view $RepoName 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Warn ("'{0}' already exists under your account." -f $RepoName)
    if (-not (Read-Confirm "Point origin at it and push?")) { Write-Note "Nothing pushed."; exit 0 }
    git remote add origin ("https://github.com/{0}/{1}.git" -f $Owner, $RepoName)
} else {
    if (-not (Read-Confirm ("Create '{0}' ({1}) and push your files?" -f $RepoName, $RepoVis))) { Write-Note "Nothing pushed."; exit 0 }
    $descArgs = @()
    if ($RepoDesc) { $descArgs = @('--description', $RepoDesc) }
    gh repo create $RepoName ("--{0}" -f $RepoVis) --source=. --remote=origin @descArgs
}
git branch -M main 2>$null
git push -u origin main
if ($LASTEXITCODE -eq 0) {
    Write-Say ("Pushed. Repo: https://github.com/{0}/{1}" -f $Owner, $RepoName)
} else {
    Write-Warn "push failed (see above)."
}

Write-Host ""
Write-Host "  ✓ Setup complete" -ForegroundColor Green
Write-Host ""
