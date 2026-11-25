# Workspace Rules & Instructions

## Project Directory Structure (Single Source of Truth)
- **Always develop the game exclusively under the `VSCode/` folder.**
- **Do NOT create or recreate an `app/` folder**, and never duplicate the Flutter project files anywhere else in the repository.

## Engineering & Platform SDK Guardrails (Mandatory)
1. **No Fake Mocks or Simulated Fallbacks:** Never generate mock accounts, fake IDs (e.g., `gpg_<hash>`), simulated data, or deceptive UI workarounds when an official SDK or OS API restricts a feature.
2. **SDK & Store Policy Verification First:** Before editing any code, verify whether the requested feature is officially supported by Android, Flutter, and Google Play Services/Store policies (for example, Google Play Games Services v2 does not allow in-app account switching or in-app sign-out).
3. **Abort & Advise on Conflicts:** If a user prompt asks for something unsupported or prohibited by the platform SDK, do NOT modify any code. Instead, stop immediately, explain the exact SDK/platform limitation clearly, and propose the official compliant UX alternative.

## Mandatory Git Workflow (Every Prompt)
Upon completing any code, asset, configuration, test, or documentation changes in this repository, **before every `git commit` and `git push origin main`**, you must:
1. Run `python3 scripts/update_push_meta.py --summary "<concise bulleted Summary of Changes>"` summarizing what was implemented or fixed.
2. Stage all changes and include `.github/last_push_meta.json` in `git add` (e.g., `git add .` or explicitly including `.github/last_push_meta.json` with modified files) so it is pushed with the commit.
3. Commit with a descriptive Conventional Commits message (e.g., `git commit -m "feat: ..."` or `fix: ...`).
4. Push immediately to the remote branch: `git push origin main`.

This rule applies to all agents, tools, chats, and CLI sessions working in this repository on any machine. Do not complete a task turn with uncommitted/unpushed changes.
