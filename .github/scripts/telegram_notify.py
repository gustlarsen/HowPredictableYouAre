#!/usr/bin/env python3
"""
Telegram Notification Script for GitHub Actions CI/CD
Handles sending APK releases and build failure alerts to a Telegram Channel.
"""

import argparse
import html
import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

# Ensure UTF-8 output even on constrained Windows console encodings
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
if hasattr(sys.stderr, "reconfigure"):
    try:
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


def send_telegram_message(token: str, chat_id: str, message: str) -> dict:
    """Send text message to Telegram using Bot API sendMessage."""
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    payload = {
        "chat_id": chat_id,
        "text": message,
        "parse_mode": "HTML",
        "disable_web_page_preview": True,
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8", errors="replace")
        print(f"HTTPError sending Telegram message: {e.code} - {error_body}", file=sys.stderr)
        return {"ok": False, "error": error_body}
    except Exception as e:
        print(f"Error sending Telegram message: {e}", file=sys.stderr)
        return {"ok": False, "error": str(e)}


def send_telegram_document(token: str, chat_id: str, file_path: str, caption: str) -> dict:
    """Send document (APK) to Telegram using curl for robust multipart upload."""
    url = f"https://api.telegram.org/bot{token}/sendDocument"
    cmd = [
        "curl",
        "-s",
        "-S",
        "-X", "POST", url,
        "-F", f"chat_id={chat_id}",
        "-F", f"document=@{file_path}",
        "-F", f"caption={caption}",
        "-F", "parse_mode=HTML",
    ]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
        if proc.returncode != 0:
            print(f"curl exited with code {proc.returncode}: {proc.stderr}", file=sys.stderr)
            return {"ok": False, "error": proc.stderr}
        try:
            return json.loads(proc.stdout)
        except json.JSONDecodeError:
            print(f"Unexpected response from Telegram API: {proc.stdout}", file=sys.stderr)
            return {"ok": False, "error": proc.stdout}
    except Exception as e:
        print(f"Error executing curl for sendDocument: {e}", file=sys.stderr)
        return {"ok": False, "error": str(e)}


def get_git_changes_summary(current_tag: str) -> str:
    """Extract commit messages between previous tag and HEAD."""
    try:
        res = subprocess.run(
            ["git", "tag", "--sort=-creatordate"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=False,
        )
        tags = [t.strip() for t in res.stdout.splitlines() if t.strip()]
        prev_tag = None
        for t in tags:
            if t != current_tag:
                prev_tag = t
                break

        if prev_tag:
            res = subprocess.run(
                ["git", "log", f"{prev_tag}..HEAD", "--pretty=format:• %s (%h)", "--no-merges"],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                check=False,
            )
            logs = res.stdout.strip()
            if logs:
                return logs
    except Exception as e:
        print(f"Notice: unable to query git log range: {e}", file=sys.stderr)

    try:
        res = subprocess.run(
            ["git", "log", "-n", "3", "--pretty=format:• %s (%h)", "--no-merges"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=False,
        )
        logs = res.stdout.strip()
        if logs:
            return logs
    except Exception:
        pass

    return "• Incremental update and release build."


def handle_success(args):
    token = os.environ.get("TELEGRAM_BOT_TOKEN")
    chat_id = os.environ.get("TELEGRAM_CHAT_ID")

    if not token or not chat_id:
        print("TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID is not configured. Skipping Telegram notification.")
        return

    apk_path = args.apk
    if not os.path.isfile(apk_path):
        print(f"Error: APK file not found at '{apk_path}'", file=sys.stderr)
        sys.exit(1)

    file_size_bytes = os.path.getsize(apk_path)
    file_size_mb = file_size_bytes / (1024 * 1024)

    commit_sha = args.commit or "Unknown"
    short_commit = commit_sha[:7]
    commit_url = f"{args.server_url}/{args.repo}/commit/{commit_sha}"
    release_url = f"{args.server_url}/{args.repo}/releases/tag/{args.tag}"

    raw_summary = get_git_changes_summary(args.tag)
    # Escape summary for HTML safety
    escaped_summary = "\n".join(
        html.escape(line) for line in raw_summary.splitlines()
    )

    apk_filename = os.path.basename(apk_path)
    if "arm64" in apk_filename.lower():
        arch_label = "arm64-v8a (modern Android)"
    elif "v7a" in apk_filename.lower():
        arch_label = "armeabi-v7a (legacy 32-bit)"
    elif "x86" in apk_filename.lower():
        arch_label = "x86_64 (emulators)"
    else:
        arch_label = "Universal"

    full_message = (
        f"🚀 <b>New Release: How Predictable You Are</b>\n\n"
        f"🏷️ <b>Version:</b> <code>{html.escape(args.version_name)}</code> (Build <code>{html.escape(str(args.version_code))}</code>)\n"
        f"🔖 <b>Tag:</b> <code>{html.escape(args.tag)}</code>\n"
        f"🔗 <b>Commit:</b> <a href=\"{commit_url}\">{short_commit}</a>\n"
        f"📦 <b>Size:</b> {file_size_mb:.2f} MB ({arch_label})\n\n"
        f"📝 <b>Summary of Changes:</b>\n{escaped_summary}\n\n"
        f"📥 <a href=\"{release_url}\">Other architectures available on GitHub Releases</a>"
    )

    # Telegram limit for documents via Bot API is 50MB
    if file_size_mb > 50.0:
        print(f"APK size is {file_size_mb:.2f}MB, exceeding Telegram's 50MB bot upload limit.")
        oversize_message = (
            f"{full_message}\n\n"
            f"⚠️ <i>APK size exceeds Telegram's 50MB bot upload limit.</i>\n"
            f"📥 <a href=\"{release_url}\">Download APK from GitHub Release</a>"
        )
        resp = send_telegram_message(token, chat_id, oversize_message)
        print("Telegram oversize notification response:", resp)
        return

    # Telegram caption length limit is 1024 characters
    if len(full_message) <= 1024:
        print("Sending APK with full caption...")
        resp = send_telegram_document(token, chat_id, apk_path, full_message)
        print("Telegram sendDocument response:", resp)
        if not resp.get("ok"):
            # Fallback: send message separately, then document with short caption
            print("Retrying with split message and document...")
            send_telegram_message(token, chat_id, full_message)
            short_caption = f"📦 <b>How Predictable You Are</b> v{html.escape(args.version_name)} ({short_commit})"
            resp = send_telegram_document(token, chat_id, apk_path, short_caption)
            print("Fallback sendDocument response:", resp)
    else:
        print("Caption exceeds 1024 characters. Sending full details as message first...")
        msg_resp = send_telegram_message(token, chat_id, full_message)
        print("Telegram sendMessage response:", msg_resp)
        short_caption = f"📦 <b>How Predictable You Are</b> v{html.escape(args.version_name)} ({short_commit})"
        doc_resp = send_telegram_document(token, chat_id, apk_path, short_caption)
        print("Telegram sendDocument response:", doc_resp)


def extract_error_snippet(log_path: str, max_lines: int = 18) -> str:
    """Extract informative error lines from a build log."""
    if not os.path.isfile(log_path):
        return "No specific log file recorded for this step."

    try:
        with open(log_path, "r", encoding="utf-8", errors="replace") as f:
            lines = [line.rstrip() for line in f.readlines() if line.strip()]
    except Exception as e:
        return f"Unable to read log file: {e}"

    if not lines:
        return "Log file was empty."

    # Search for common error indicators
    error_indices = [
        i for i, line in enumerate(lines)
        if any(marker in line.lower() for marker in [
            "error:", "fatal:", "failed", "failure", "exception",
            "could not resolve", "build failed", "compilation failed"
        ])
    ]

    if error_indices:
        last_error = error_indices[-1]
        start_idx = max(0, last_error - 10)
        end_idx = min(len(lines), last_error + 8)
        selected = lines[start_idx:end_idx]
    else:
        selected = lines[-max_lines:]

    snippet = "\n".join(selected)
    if len(snippet) > 1800:
        snippet = snippet[-1800:]
    return snippet


def handle_failure(args):
    token = os.environ.get("TELEGRAM_BOT_TOKEN")
    chat_id = os.environ.get("TELEGRAM_CHAT_ID")

    if not token or not chat_id:
        print("TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID is not configured. Skipping Telegram notification.")
        return

    commit_sha = args.commit or "Unknown"
    short_commit = commit_sha[:7]
    commit_url = f"{args.server_url}/{args.repo}/commit/{commit_sha}"
    run_url = f"{args.server_url}/{args.repo}/actions/runs/{args.run_id}"

    # Determine failed phase
    phase_file = os.path.join("build_logs", "phase.txt")
    failed_phase = "workflow"
    if os.path.isfile(phase_file):
        try:
            with open(phase_file, "r", encoding="utf-8") as f:
                failed_phase = f.read().strip()
        except Exception:
            pass

    if failed_phase == "dependencies":
        phase_title = "Dependency Installation (flutter pub get)"
        error_code = "ERR_PUB_GET_FAILED"
        log_file = os.path.join("build_logs", "pub_get.log")
        why = (
            "Flutter was unable to resolve dependencies or download packages. "
            "This commonly happens if a package in pubspec.yaml has conflicting version constraints, "
            "an incompatible Dart/Flutter SDK constraint, or if a network/registry outage occurred on pub.dev."
        )
        fix = (
            "1. Inspect <code>VSCode/pubspec.yaml</code> for conflicting version ranges or typos in package names.\n"
            "2. Run <code>cd VSCode &amp;&amp; flutter pub get</code> locally to view the version solver conflict tree.\n"
            "3. Run <code>flutter pub outdated</code> to find compatible dependency versions."
        )
    elif failed_phase == "test":
        phase_title = "Automated Tests (flutter test)"
        error_code = "ERR_TEST_ASSERTION_FAILED"
        log_file = os.path.join("build_logs", "test.log")
        why = (
            "One or more automated unit or widget tests failed assertions. "
            "Recent code changes likely caused unexpected UI behavior, state regressions, or changed expected function outputs."
        )
        fix = (
            "1. Run <code>cd VSCode &amp;&amp; flutter test</code> locally to reproduce the failing test.\n"
            "2. Inspect the failed assertion trace in <code>VSCode/test/</code>.\n"
            "3. Update the implementation code to fix the regression, or update test expectations if behavior change is intentional."
        )
    elif failed_phase == "build":
        phase_title = "Android Release Compilation (flutter build apk)"
        error_code = "ERR_APK_BUILD_FAILED"
        log_file = os.path.join("build_logs", "build.log")
        why = (
            "The release APK compilation failed during Gradle or Dart compilation. "
            "Common causes include Gradle plugin / Android SDK (compileSdkVersion) incompatibility, "
            "Dart syntax/type errors, missing asset files referenced in pubspec.yaml, or Android manifest errors."
        )
        fix = (
            "1. Run <code>cd VSCode &amp;&amp; flutter build apk --release</code> locally to view the full Gradle build trace.\n"
            "2. Verify Android configuration in <code>VSCode/android/app/build.gradle</code>.\n"
            "3. Ensure all declared assets in <code>VSCode/pubspec.yaml</code> exist on disk."
        )
    elif failed_phase == "tag_release":
        phase_title = "Tagging & GitHub Release Creation"
        error_code = "ERR_RELEASE_CREATION_FAILED"
        log_file = os.path.join("build_logs", "release.log")
        why = (
            "Failed during git tag push or GitHub Release creation. "
            "This could happen if the git tag already exists on the remote or if GitHub API tokens lack write permissions."
        )
        fix = (
            "1. Verify that the version tag does not conflict with an existing remote tag.\n"
            "2. Ensure workflow permissions include <code>contents: write</code>."
        )
    else:
        phase_title = "Workflow Setup / Runner Environment"
        error_code = "ERR_WORKFLOW_SETUP_FAILED"
        log_file = os.path.join("build_logs", "general.log")
        why = (
            "The workflow failed before or outside the compilation phases (e.g. checkout, Java 17 setup, or Flutter action setup)."
        )
        fix = (
            "Check the GitHub Actions run logs to verify runner availability and setup action configurations."
        )

    raw_snippet = extract_error_snippet(log_file)
    escaped_snippet = html.escape(raw_snippet)

    message = (
        f"🚨 <b>APK Build Failed!</b>\n\n"
        f"📱 <b>App:</b> How Predictable You Are\n"
        f"⚠️ <b>Failed Step:</b> {html.escape(phase_title)}\n"
        f"🛑 <b>Error Code:</b> <code>{error_code}</code>\n"
        f"🔗 <b>Commit:</b> <a href=\"{commit_url}\">{short_commit}</a>\n"
        f"👤 <b>Triggered By:</b> {html.escape(args.actor or 'Unknown')}\n\n"
        f"<b>Log Excerpt:</b>\n<pre>{escaped_snippet}</pre>\n\n"
        f"🧐 <b>Why this occurred:</b>\n{why}\n\n"
        f"🛠️ <b>What should change to fix the problem:</b>\n{fix}\n\n"
        f"📋 <a href=\"{run_url}\">View Full GitHub Actions Run</a>"
    )

    print("Sending failure notification to Telegram...")
    resp = send_telegram_message(token, chat_id, message)
    print("Telegram failure response:", resp)


def main():
    parser = argparse.ArgumentParser(description="Telegram Release & Failure Bot Notification")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Success subcommand
    success_parser = subparsers.add_parser("success")
    success_parser.add_argument("--apk", required=True, help="Path to APK file")
    success_parser.add_argument("--version-name", required=True, help="App version name")
    success_parser.add_argument("--version-code", required=True, help="App version code")
    success_parser.add_argument("--tag", required=True, help="Git release tag")
    success_parser.add_argument("--commit", required=True, help="Commit SHA")
    success_parser.add_argument("--repo", required=True, help="Repository (owner/repo)")
    success_parser.add_argument("--server-url", default="https://github.com", help="GitHub Server URL")
    success_parser.add_argument("--run-id", default="", help="GitHub Run ID")

    # Failure subcommand
    failure_parser = subparsers.add_parser("failure")
    failure_parser.add_argument("--commit", default="", help="Commit SHA")
    failure_parser.add_argument("--repo", default="", help="Repository (owner/repo)")
    failure_parser.add_argument("--server-url", default="https://github.com", help="GitHub Server URL")
    failure_parser.add_argument("--run-id", default="", help="GitHub Run ID")
    failure_parser.add_argument("--actor", default="", help="GitHub Actor")

    args = parser.parse_args()
    if args.command == "success":
        handle_success(args)
    elif args.command == "failure":
        handle_failure(args)


if __name__ == "__main__":
    main()
