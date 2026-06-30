# setup-git.ps1
# Connects the "Curaleaf integration" folder to the GitHub remote so you can
# freely switch between branches (main, branchMihir) for reviews and tweaks.
#
# HOW TO RUN:
#   1. Open File Explorer to this folder.
#   2. Right-click setup-git.ps1  ->  "Run with PowerShell"
#   (or, in a PowerShell window:  cd to this folder, then:  .\setup-git.ps1 )

$ErrorActionPreference = "Stop"
$repo = "https://github.com/spatel-collab/hhh-curaleaf-platform.git"

# Always operate in the folder this script lives in
Set-Location -Path $PSScriptRoot
Write-Host "Working in: $PSScriptRoot" -ForegroundColor Cyan

# 0. Make sure Git is available. If it's installed but not on PATH,
#    find it in the usual locations and add it for this session.
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    $candidates = @(
        "$env:ProgramFiles\Git\cmd\git.exe",
        "${env:ProgramFiles(x86)}\Git\cmd\git.exe",
        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe"
    )
    $found = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($found) {
        $env:PATH = (Split-Path $found) + ";" + $env:PATH
        Write-Host "Found Git at: $found" -ForegroundColor Cyan
    } else {
        Write-Host "`nGit is not installed on this machine (or not on PATH)." -ForegroundColor Red
        Write-Host "Install 'Git for Windows' from https://git-scm.com/download/win" -ForegroundColor Yellow
        Write-Host "then re-run this script." -ForegroundColor Yellow
        Read-Host "`nPress Enter to close"
        exit 1
    }
}

# 1. Remove any broken/partial .git folder from the earlier attempt
if (Test-Path ".git") {
    Write-Host "Removing existing .git folder..." -ForegroundColor Yellow
    # Clear read-only/hidden attributes so removal succeeds
    attrib -r -h ".git" /s /d 2>$null
    Remove-Item -Recurse -Force ".git"
}

# 2. Initialize a fresh repo with 'main' as the current branch
git init | Out-Null
git symbolic-ref HEAD refs/heads/main

# 3. Connect to the remote and download all branches
git remote add origin $repo
git fetch origin

# 4. Adopt your existing local files onto 'main' WITHOUT overwriting them.
git reset --mixed origin/main
git branch --set-upstream-to=origin/main main 2>$null

# 5. Commit your local changes onto main and push them up to date.
git add -A
git reset -- setup-git.ps1 2>$null   # don't commit this helper script
$changes = git status --porcelain
if ($changes) {
    Write-Host "`nCommitting and pushing your local changes to main..." -ForegroundColor Cyan
    git commit -m "Sync local working files to main"
    git push origin main
} else {
    Write-Host "`nNo local changes to push; main already up to date." -ForegroundColor Cyan
}

# 6. Switch into Mihir's branch to review his work.
Write-Host "`nSwitching to branchMihir..." -ForegroundColor Cyan
git checkout branchMihir

Write-Host "`nNow on branch:" -ForegroundColor Green
git branch --show-current
Write-Host "`nRecent commits on this branch:" -ForegroundColor Green
git log --oneline -8

Read-Host "`nDone. Press Enter to close"
