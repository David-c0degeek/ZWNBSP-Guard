# ZWNBSP Pre-Commit Hook Installer
# Usage: irm https://raw.githubusercontent.com/<you>/gist/.../install.ps1 | iex

$ErrorActionPreference = "Stop"

# Find git root
$gitRoot = git rev-parse --show-toplevel 2>$null
if (-not $gitRoot) {
    Write-Host "❌ Not in a git repository" -ForegroundColor Red
    return
}

$hooksDir = Join-Path $gitRoot ".git/hooks"
if (-not (Test-Path $hooksDir)) {
    New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
}

# Bash shim (Git on Windows uses bash by default)
$shimPath = Join-Path $hooksDir "pre-commit"
$shimContent = @'
#!/bin/sh
exec powershell.exe -ExecutionPolicy Bypass -NoProfile -File "$(dirname "$0")/pre-commit.ps1"
'@

# PowerShell hook
$ps1Path = Join-Path $hooksDir "pre-commit.ps1"
$ps1Content = @'
$ErrorActionPreference = "Stop"
$files = git diff --cached --name-only --diff-filter=ACMR
if (-not $files) { exit 0 }

$fixedAny = $false
$badAny = $false
$badFiles = @()

foreach ($f in $files) {
    if (-not (Test-Path $f)) { continue }
    
    # Skip common binary extensions
    if ($f -match '\.(exe|dll|png|jpg|jpeg|gif|ico|woff|woff2|ttf|eot|pdf|zip|7z|rar)$') { continue }
    
    $bytes = [System.IO.File]::ReadAllBytes($f)
    
    # --- Fix UTF-8 BOM at start (EF BB BF) ---
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $bytes = $bytes[3..($bytes.Length-1)]
        [System.IO.File]::WriteAllBytes($f, $bytes)
        git add $f 2>$null
        Write-Host "✅ Removed UTF-8 BOM: $f" -ForegroundColor Green
        $fixedAny = $true
    }
    
    # --- Check for U+FEFF (ZWNBSP) inside file ---
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ($text.Contains([char]0xFEFF)) {
        # Find positions for debugging
        $positions = @()
        for ($i = 0; $i -lt $text.Length; $i++) {
            if ($text[$i] -eq [char]0xFEFF) { $positions += $i }
        }
        Write-Host "❌ U+FEFF (ZWNBSP) in: $f at positions: $($positions -join ', ')" -ForegroundColor Red
        $badFiles += $f
        $badAny = $true
    }
}

if ($badAny) {
    Write-Host ""
    Write-Host "⛔ Commit blocked. Files contain literal U+FEFF characters." -ForegroundColor Red
    Write-Host "   Tip: Open in hex editor or run:" -ForegroundColor Yellow
    Write-Host "   `$content = Get-Content -Raw 'file'; `$content -replace [char]0xFEFF,'' | Set-Content 'file' -NoNewline" -ForegroundColor DarkGray
    exit 1
}

if ($fixedAny) {
    Write-Host "✅ BOM cleanup complete. Files re-staged." -ForegroundColor Green
}

exit 0
'@

# Write files
[System.IO.File]::WriteAllText($shimPath, $shimContent.Replace("`r`n", "`n"))  # Unix line endings for bash
Set-Content -Path $ps1Path -Value $ps1Content -Encoding UTF8

Write-Host ""
Write-Host "✅ Pre-commit hook installed to: $hooksDir" -ForegroundColor Green
Write-Host "   - pre-commit (bash shim)" -ForegroundColor DarkGray
Write-Host "   - pre-commit.ps1 (PowerShell script)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Hook will:" -ForegroundColor Cyan
Write-Host "   • Auto-remove UTF-8 BOM from staged files" -ForegroundColor White
Write-Host "   • Block commits containing U+FEFF (ZWNBSP) characters" -ForegroundColor White
