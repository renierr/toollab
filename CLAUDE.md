# CLAUDE.md

This project's AI developer guidelines, architecture rules, and conventions live in **AGENTS.md**. They apply in full to every Claude Code session in this repo.

@AGENTS.md

## Environment

- If the env is **Windows with MSYS2**, the `Bash` tool runs `bash`, NOT PowerShell.
- Do NOT use PowerShell here-string syntax (`@'...'@`) for git commit messages or anything else in the `Bash` tool — bash treats the `@` lines literally and corrupts the message. Use bash quoting: multiple `-m` flags, or `$'line1\nline2'`.
