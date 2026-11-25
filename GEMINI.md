# Workspace Rules & Instructions

## Project Directory Structure (Single Source of Truth)
- **Always develop the game exclusively under the `VSCode/` folder.**
- **Do NOT create or recreate an `app/` folder**, and never duplicate the Flutter project files anywhere else in the repository.

## Engineering & Platform SDK Guardrails (Mandatory)
1. **No Fake Mocks or Simulated Fallbacks:** Never generate mock accounts, fake IDs (e.g., `gpg_<hash>`), simulated data, or deceptive UI workarounds when an official SDK or OS API restricts a feature.
2. **SDK & Store Policy Verification First:** Before editing any code, verify whether the requested feature is officially supported by Android, Flutter, and Google Play Services/Store policies (for example, Google Play Games Services v2 does not allow in-app account switching or in-app sign-out).
3. **Abort & Advise on Conflicts:** If a user prompt asks for something unsupported or prohibited by the platform SDK, do NOT modify any code. Instead, stop immediately, explain the exact SDK/platform limitation clearly, and propose the official compliant UX alternative.

## Android Activity Task & Display Scaling Guardrails (Prevention)
1. **Never set `android:taskAffinity=""` on `.MainActivity`:** Keep the default package task affinity together with `android:launchMode="singleTask"` and `setIntent(intent)` in `onNewIntent()` so Play Core `completeUpdate()`, `flutter_local_notifications`, Play Store "Open", and OEM game launchers reuse a single Recents task instead of spawning duplicate windows.
2. **Never include `density` in `android:configChanges`:** Allow Android to cleanly recreate `.MainActivity` with fresh `Resources`, `DisplayMetrics`, `FlutterView`, and native AdMob `AdView` instances whenever display density changes.
3. **Keep Android Game Mode downscaling opted out:** Maintain `android:appCategory="game"` and `res/xml/game_mode_config.xml` (`android:allowGameDownscaling="false"`, `android:allowGameFpsOverride="false"`) so OEM Game Boosters do not apply 75% backbuffer downscaling.
4. **Never mutate `SurfaceView` buffers or visibility as a viewport workaround:** Do not call `surfaceView.holder.setSizeFromLayout()` or toggle `SurfaceView` visibility (`INVISIBLE`/`VISIBLE`) in `MainActivity.kt`; restrict native viewport sync to edge-to-edge `WindowCompat` / `ViewCompat.requestApplyInsets()`.
5. **Never finish/remove the foreground Activity before `completeUpdate()`:** Keep `UpdateService.completeFlexibleUpdate()` strictly foreground-gated so Play Core displays its install UI and auto-relaunches cleanly; purge any stale orphan tasks post-launch via `ActivityManager.appTasks` in `MainActivity.onCreate()`.

## Mandatory Git Workflow (Every Prompt)
Upon completing any code, asset, configuration, test, or documentation changes in this repository:
1. Stage all changes: `git add .` (or specific modified files).
2. Commit with a descriptive Conventional Commits message (e.g., `git commit -m "feat: ..."` or `fix: ...`).
3. Push immediately to the remote branch: `git push origin main`.

This rule applies to all agents, tools, chats, and CLI sessions working in this repository on any machine. Do not complete a task turn with uncommitted/unpushed changes.
