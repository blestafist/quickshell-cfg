# Session Locker

## Architecture

- `lock.qml` is a separate Quickshell configuration and process. Never import it into `shell.qml`.
- `WlSessionLock` acquires ext-session-lock-v1. Its `secure` property reflects the compositor's `locked` event, not a visible window, elapsed time, or a file.
- `lockctl` uses a private-runtime `flock` mutex to serialize requests. This is **not** a secure-ack marker. `status` is read-only and never starts a process. Missing, malformed, timed-out or negative IPC responses fail closed for suspend; they never kill the locker.
- The owning QML event loop rechecks `secure`, `locked`, pending unlock and pending suspend before starting `systemctl suspend`. Authentication is aborted/disabled until that command finishes. This prevents an ordinary PAM unlock between acknowledgement and the suspend request. A timeout leaves the locker untouched.
- Only `PamResult.Success`, while authentication is permitted, sets the success latch. Only that latch can release the protocol lock, after a short cosmetic exit animation. No IPC function unlocks, reloads, quits, changes the PAM user, or supplies credentials.
- The locker remains resident without windows after unlock. There is deliberately no `Qt.quit()`, kill, or timer-based process termination: the Qt Wayland event loop continues delivering `unlock_and_destroy`. The next `lockctl lock` reuses it. The resident process has no bar, clipboard, launcher or network integrations.
- `QS_DISABLE_FILE_WATCHER=1` and `Quickshell.watchFiles = false` prevent automatic reload. Shell reload targets a different config. Locker edits take effect only with a fresh process in a later session; do not kill a locked process to update it.
- Quickshell itself disables `quitOnLastWindowClosed`. A disconnected output therefore must not be treated as authorization to exit.

Entry points live in the repository root because Quickshell 0.3.1 blackholes relative QML module imports escaping its config root. The former `lockscreen/shell.qml` is intentionally removed.

## Authentication

Select Continue, then answer the actual PAM prompt. Every required prompt waits for explicit nonempty input; passwords are not reused for OTPs and visible prompts respect PAM's echo flag. Informational messages never receive fabricated empty responses. Escape cancels the conversation, not the lock. Failures use a UI retry delay; PAM remains responsible for account lockout policy. Responses are limited to 512 characters.

PAM uses the existing `/etc/pam.d/hyprlock`; no system PAM files are installed or modified. Empty `PamContext.user` resolves the process UID via `getpwuid`, not `$USER` (the latter is display text only). Passwords are not command arguments, files, IPC methods, or log messages. Fields clear on submission, a new prompt, cancellation, failure and success. **Qt/QML strings and controls do not provide guaranteed zeroization or locked memory.** Do not claim resistance to a compromised same-user process, root, debugger, swap or crash dumps.

## Verified API

Checked against installed Quickshell 0.3.1 `.qmltypes` in `/usr/lib/qt6/qml/Quickshell` and upstream tag `v0.3.1` (commit `1a4716cde794a59928d9d9fc15f2afc7a95de360`):

- [Session-lock QML implementation](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/wayland/session_lock.cpp): `locked`, read-only `secure`, **`secureStateChanged`**, surfaces per valid output, hotplug handling.
- [Protocol implementation](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/wayland/session_lock/lock.cpp): `locked` acknowledgement and `unlock_and_destroy`; destruction without unlock deliberately does not unlock.
- [PAM implementation](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/services/pam/qml.cpp): `start`, `respond`, `abort`, `pamMessage`, completion and error ordering, UID lookup.
- [Application lifecycle](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/launch/launch.cpp): `setQuitOnLastWindowClosed(false)`.
- [Watcher setting](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/core/qmlglobal.cpp): `watchFiles` and `QS_DISABLE_FILE_WATCHER`.

## Safe Tests

These commands never instantiate the real lock or connect to the live Wayland display:

```sh
qmllint -I /usr/lib/qt6/qml lock.qml lock-preview.qml lock-preview-test.qml lockscreen/*.qml lockscreen/widgets/*.qml lockscreen/preview/*.qml
bash -n scripts/lockctl
node --test tests/locker.test.cjs tests/calculator.test.cjs
python tests/lockctl_test.py
env -u WAYLAND_DISPLAY -u DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    timeout 10s quickshell -p lock-preview-test.qml --no-color
```

The last command must print `LOCK_PREVIEW_TEST_PASS` with no QML errors. It **compiles but never creates** `lock.qml`, creates only an ordinary preview window, and exercises landscape, portrait, small-window and mock multi-prompt states. Set `LOCK_PREVIEW_CAPTURE=/tmp/opencode` to capture screenshots there. The Node tests execute the actual QML handler bodies with mock PAM; they are not a real PAM integration test. Python tests put a fake `quickshell` first on PATH, including for concurrency tests; no real locker or systemctl is launched.

Interactive UI-only preview (ordinary closeable window, no security):

```sh
quickshell -p ./lock-preview.qml
```

Preview imports only visual widgets and a separate mock. It is visibly marked `PREVIEW / NOT LOCKED`. Never enter your real password there. The production entry point has no preview flag or mock-auth branch. `lockscreen/config/LockConfig.qml` controls reduced motion with `animationsEnabled`.

## Isolated Smoke Checklist

**Not performed on the user's live session.** Static/offscreen results cannot establish runtime security. Use a disposable nested compositor or a separate test login with recovery access, not the working desktop. Never test failure recovery by killing the live locker or restarting the live compositor.

1. Check ext-session-lock-v1 support and the selected PAM service. Prepare a separate VT or disposable-session recovery procedure. A crashed locker may leave the compositor locked; another ordinary locker cannot necessarily recover it.
2. Acquire a lock. Verify IPC transitions to `secure` only after the protocol `locked` event, and every output is covered. Confirm screenshots/input do not reach other clients.
3. Try incorrect credentials, empty submit, repeated Enter, Escape, visible prompt, OTP and PAM errors. None may release the lock. Test correct credentials and observe `unlock_and_destroy` reaching the compositor before windows disappear; the resident process must remain idle and reusable.
4. Repeat lock/unlock cycles, concurrent `lockctl` requests, and a request while unlock is animating. No duplicate lock acquisition or accidental unlock may occur.
5. Add/remove/rotate outputs, change scale, remove the primary output and test portrait/small screens. Confirm keyboard access on each screen and secure coverage on hotplug.
6. In the isolated session only, reload the separate bar config and edit a locker source file while locked. Neither may reload or terminate the locker.
7. Test guarded suspend, resume, suspend-command failure and IPC failure. Attempt authentication during the suspend request: it must remain disabled. Missing acknowledgement must never issue suspend.
8. Only after these checks, consider changing external lock/idle bindings. Lid/logind, wlogout and other suspend paths require separate integration; this change does not install a global sleep inhibitor.

## Limits

Same-UID IPC is a control channel, not an adversarial security boundary. Manual Quickshell kill commands, signals, compositor bugs, GPU failures and process crashes remain risks. No automatic restart/unlock recovery is attempted. A successful `systemctl suspend` exit is not a universal resume notification on every system. The locker holds the session lock throughout, but sleep/idle policy outside this helper is not controlled.

The prior reported "lockscreen app died" was not reproduced live. Confirmed prototype defects were an invalid secure signal handler, self-shadowing bindings, unsafe immediate quit, out-of-root imports and one-shot PAM response handling. Fixing these is not proof that all possible runtime crashes are eliminated.
