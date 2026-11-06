# Workspace Rules & Instructions

## Project Directory Structure (Single Source of Truth)
- **Always develop the game exclusively under the `VSCode/` folder.**
- **Do NOT create or recreate an `app/` folder**, and never duplicate the Flutter project files anywhere else in the repository.

## Mandatory Git Workflow (Every Prompt)
Upon completing any code, asset, configuration, test, or documentation changes in this repository:
1. Stage all changes: `git add .` (or specific modified files).
2. Commit with a descriptive Conventional Commits message (e.g., `git commit -m "feat: ..."` or `fix: ...`).
3. Push immediately to the remote branch: `git push origin main`.

This rule applies to all agents, tools, chats, and CLI sessions working in this repository on any machine. Do not complete a task turn with uncommitted/unpushed changes.
