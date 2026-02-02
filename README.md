# ZWNBSP Guard 🛡️

A Git pre-commit hook that protects your codebase from invisible Unicode characters that can break builds, cause subtle bugs, and drive you crazy.

## The Problem

AI coding assistants (Copilot, Claude Code, Cursor, etc.) occasionally insert invisible **U+FEFF** (Zero-Width No-Break Space) characters into your code. These characters:

- Are completely invisible in most editors
- Can break compilers, interpreters, and parsers
- Cause "it works on my machine" syndrome
- Are extremely difficult to diagnose
- Often appear at the start of lines or inside string literals

The UTF-8 BOM (`EF BB BF`) at file starts is a related issue that can cause similar problems.

## The Solution

This pre-commit hook automatically:

| Issue | Action |
|-------|--------|
| UTF-8 BOM at file start | Auto-removes and re-stages |
| U+FEFF inside file content | Blocks commit with location info |

## Installation

### Remote (one-liner)

```powershell
irm https://raw.githubusercontent.com/David-c0degeek/ZWNBSP-Guard/main/install.ps1 | iex
```

### Local

```powershell
.\install.ps1
```

Same script, both methods. Installs **globally** — every git repo on your machine is protected.

## Uninstall

```powershell
git config --global --unset core.hooksPath
Remove-Item -Recurse "$env:USERPROFILE\.git-hooks"
```

## Requirements

- Windows with PowerShell 5.1+
- Git for Windows

## How It Works

```
┌─────────────────────────────────────────────────────────┐
│                    git commit                           │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│              pre-commit hook triggers                   │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│         Get list of staged files (ACMR)                 │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│              For each text file:                        │
│  ┌────────────────────────────────────────────────────┐ │
│  │ 1. Check for UTF-8 BOM → Auto-fix & re-stage      │ │
│  │ 2. Scan for U+FEFF → Report positions             │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────┬───────────────────────────────────┘
                      │
          ┌───────────┴───────────┐
          │                       │
          ▼                       ▼
┌─────────────────┐     ┌─────────────────┐
│   No issues     │     │  U+FEFF found   │
│   [COMMIT]      │     │  [BLOCKED]      │
└─────────────────┘     └─────────────────┘
```

## Example Output

### Clean commit
```
[OK] Removed UTF-8 BOM: src/Program.cs
[OK] BOM cleanup complete.
[main abc1234] Your commit message
```

### Blocked commit
```
[ERROR] U+FEFF (ZWNBSP) in: src/Service.cs at positions: 0, 847, 1203

[BLOCKED] Commit blocked. Files contain U+FEFF characters.
Fix: $c = Get-Content -Raw 'file'; $c -replace [char]0xFEFF,'' | Set-Content 'file' -NoNewline
```

## Manual Cleanup

If the hook blocks your commit, you can fix the file manually:

### PowerShell
```powershell
$file = "path/to/file.cs"
$content = Get-Content -Raw $file
$content -replace [char]0xFEFF, '' | Set-Content $file -NoNewline
```

### Find all ZWNBSP in a directory
```powershell
Get-ChildItem -Recurse -File | ForEach-Object {
    $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ($text.Contains([char]0xFEFF)) {
        Write-Host "Found in: $($_.FullName)"
    }
}
```

## Skipped Files

The hook automatically skips binary files with these extensions:

```
.exe .dll .png .jpg .jpeg .gif .ico .woff .woff2 .ttf .eot .pdf .zip .7z .rar .bin .obj .pdb
```

## FAQ

### Why not just auto-fix ZWNBSP too?

Unlike the BOM (which is always at position 0), ZWNBSP characters inside files might occasionally be intentional (e.g., in test data or documentation about Unicode). The hook reports exact positions so you can make an informed decision.

### Does this work with WSL?

The hook is designed for Git for Windows with PowerShell. For WSL, you'd want a bash-native version.

### How do I disable this for a single repo?

```powershell
cd your-repo
git config --local core.hooksPath .git/hooks
```

### What about other invisible characters?

This hook focuses on U+FEFF specifically because it's the most common culprit from AI tools. You could extend the `$text.Contains()` check to include other problematic characters like:

- U+200B (Zero-Width Space)
- U+200C (Zero-Width Non-Joiner)  
- U+200D (Zero-Width Joiner)
- U+2060 (Word Joiner)

## Contributing

Issues and PRs welcome! If you encounter other invisible character problems from AI coding tools, please open an issue.

## License

MIT License - Use freely, attribution appreciated.

---

*Built out of frustration with invisible characters breaking builds at 2 AM.* 🌙
