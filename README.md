# ZWNBSP Guard 🛡️

A global Git pre-commit hook that protects your codebase from invisible Unicode characters inserted by AI coding assistants.

## The Problem

AI coding tools (Copilot, Claude Code, Cursor, etc.) occasionally insert invisible **U+FEFF** (Zero-Width No-Break Space) characters into your code. These characters:

- Are completely invisible in most editors
- Break compilers, interpreters, and parsers
- Cause "it works on my machine" syndrome
- Are extremely difficult to diagnose

## The Solution

| Issue | Action |
|-------|--------|
| UTF-8 BOM at file start | ✅ Auto-removes and re-stages |
| U+FEFF inside file content | ⛔ Blocks commit with location info |

## Installation

**One command, works for ALL your git repos:**

```powershell
.\Install-ZwnbspHook.ps1
```

That's it. Every git commit on your machine is now protected.

## Uninstall

```powershell
git config --global --unset core.hooksPath
Remove-Item -Recurse "$env:USERPROFILE\.git-hooks"
```

## Example Output

### Blocked commit
```
❌ U+FEFF (ZWNBSP) in: src/Service.cs at positions: 0, 847

⛔ Commit blocked. Files contain U+FEFF characters.
   Fix: $c = Get-Content -Raw 'file'; $c -replace [char]0xFEFF,'' | Set-Content 'file' -NoNewline
```

### Auto-fixed BOM
```
✅ Removed UTF-8 BOM: src/Program.cs
✅ BOM cleanup complete.
```

## Manual Cleanup

```powershell
# Fix a single file
$c = Get-Content -Raw "path/to/file.cs"
$c -replace [char]0xFEFF, '' | Set-Content "path/to/file.cs" -NoNewline

# Find all ZWNBSP in current directory
Get-ChildItem -Recurse -File | ForEach-Object {
    $text = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($_.FullName))
    if ($text.Contains([char]0xFEFF)) { Write-Host $_.FullName }
}
```

## Skipped Files

Binary extensions are ignored: `.exe .dll .png .jpg .jpeg .gif .ico .woff .woff2 .ttf .eot .pdf .zip .7z .rar .bin .obj .pdb`

## Disable for a Single Repo

If a specific repo needs different hooks:

```powershell
cd your-repo
git config --local core.hooksPath .git/hooks
```

---

*Built out of frustration with invisible characters breaking builds.* 🌙
