# ZWNBSP Guard - Global Git Hook Installer
# Run: .\Install-ZwnbspHook.ps1

$ErrorActionPreference = "Stop"

$globalHooks = "$env:USERPROFILE\.git-hooks"

# Create directory
if (-not (Test-Path $globalHooks)) {
    New-Item -ItemType Directory -Path $globalHooks -Force | Out-Null
}

# Bash shim (Git uses bash by default)
$shimPath = Join-Path $globalHooks "pre-commit"
$shimContent = @'
#!/bin/sh
exec powershell.exe -ExecutionPolicy Bypass -NoProfile -File "$(dirname "$0")/pre-commit.ps1"
'@

# PowerShell hook
$ps1Path = Join-Path $globalHooks "pre-commit.ps1"
$ps1Content = @'
$ErrorActionPreference = "Stop"
$files = git diff --cached --name-only --diff-filter=ACMR
if (-not $files) { exit 0 }

$fixedAny = $false
$badAny = $false

foreach ($f in $files) {
    if (-not (Test-Path $f)) { continue }
    
    # Skip binary extensions
    if ($f -match '\.(exe|dll|png|jpg|jpeg|gif|ico|woff|woff2|ttf|eot|pdf|zip|7z|rar|bin|obj|pdb)$') { continue }
    
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
        $positions = @()
        for ($i = 0; $i -lt $text.Length; $i++) {
            if ($text[$i] -eq [char]0xFEFF) { $positions += $i }
        }
        Write-Host "❌ U+FEFF (ZWNBSP) in: $f at positions: $($positions -join ', ')" -ForegroundColor Red
        $badAny = $true
    }
}

if ($badAny) {
    Write-Host ""
    Write-Host "⛔ Commit blocked. Files contain U+FEFF characters." -ForegroundColor Red
    Write-Host "   Fix: " -ForegroundColor Yellow -NoNewline
    Write-Host "`$c = Get-Content -Raw 'file'; `$c -replace [char]0xFEFF,'' | Set-Content 'file' -NoNewline" -ForegroundColor DarkGray
    exit 1
}

if ($fixedAny) {
    Write-Host "✅ BOM cleanup complete." -ForegroundColor Green
}

exit 0
'@

# Write files
[System.IO.File]::WriteAllText($shimPath, $shimContent.Replace("`r`n", "`n"))
Set-Content -Path $ps1Path -Value $ps1Content -Encoding UTF8

# Configure git globally
git config --global core.hooksPath $globalHooks

Write-Host ""
Write-Host "✅ ZWNBSP Guard installed globally!" -ForegroundColor Green
Write-Host ""
Write-Host "   Hooks directory: $globalHooks" -ForegroundColor DarkGray
Write-Host "   Applies to:      ALL git repositories" -ForegroundColor DarkGray
Write-Host ""
Write-Host "To uninstall: " -ForegroundColor Yellow -NoNewline
Write-Host "git config --global --unset core.hooksPath" -ForegroundColor White
