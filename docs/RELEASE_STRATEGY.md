# Release strategy

Status: channels below are **SPECIFIED**; only unsigned development pre-releases are built (next section, D001). See `project_state/CURRENT_STATE.json`.

## Development downloads: one release page per build (D001)

Stable link for people: **https://github.com/kaansavukduran/human-os/releases** (Settings links there too). Each push to `main` that touches the app, packaging or these workflows runs `.github/workflows/downloads.yml`, which ends in **one** pre-release holding every platform's files:

```
linux (ubuntu-22.04) ─┐  flutter build linux → start check → tools/linux/package.sh → .deb .rpm .AppImage portable .tar.zst
android ──────────────┤  release APK + AAB (development signing key)
macos ────────────────┤  .app zipped with ditto → start check
web ──────────────────┤  tools/package_web_local.sh → web zip with the localhost launcher
windows ──────────────┤  reusable windows-exe.yml → portable zip + Inno Setup .exe → start check
                      └→ release (needs all, runs unless cancelled):
                         download artifacts Human-OS-* → tools/release/release_notes.py
                         → SHA256SUMS + EN/TR note → gh release create (one tag)
```

- **Files:** `Human-OS-<version>-windows-x64-Setup.exe`, `…-windows-x64-portable.zip`, `…-macos.zip`, `…-android.apk`, `…-android.aab`, `…-linux-amd64.deb`, `…-linux-x86_64.rpm`, `…-linux-x86_64.AppImage`, `…-linux-x86_64-portable.tar.zst`, `…-web.zip`, plus `SHA256SUMS`. iOS is not built (needs an Apple signing identity); the note says so.
- **Note:** "Which file is mine?" / "Hangi dosya benim?" lists only the files really attached, a "missing" section names every expected file that is absent and every platform job that did not succeed, and a warning (EN and TR) says these are development builds that mostly keep data unencrypted and must not hold real health data. The generator refuses an empty set (exit 1) and any file it cannot classify (exit 2), so it never claims a file that is not there. Dry run: see the docstring of `tools/release/release_notes.py`.
- **Failure handling:** platform jobs are independent; the release job runs with `if: !cancelled()` and publishes what exists. On Linux, a failed AppImage step (appimagetool 1.9.0 is downloaded from its GitHub release, not checksum-pinned) still lets the .deb, .rpm and tar.zst ship.
- **Uniqueness and retention:** version `0.1.0-dev.<run_number>` (packages: `0.1.0~dev.<run_number>`), tag `preview-<version>-<run_id>-<run_attempt>`; releases and tags are never deleted or replaced; publishing is serialized per branch.
- **Permissions:** platform jobs `contents: read`; only the release job gets `contents: write` through the built-in `GITHUB_TOKEN`. No other secret is used.
- **Evidence level:** the workflows are statically checked (actionlint with shellcheck) and the note generator is dry-run locally on fake files. The real artifacts, their start checks and the published page are verified only by a run on GitHub; until then they are NOT_RUN. Installing a release .deb is covered separately by `linux-deb-install-smoke` in `ci.yml`.
- `tools/package_web_local.sh` still makes a local try-out zip under `downloads/`, which is ignored by git: zips are not committed.

## Channels

development → internal → beta → production. Every build records:
- product version and build number
- source revision
- `pubspec.lock` and `pnpm-lock.yaml` SHA-256
- Flutter, Dart and Node versions
- build host OS and architecture
- profile (`APP_ENV`)
- rule, model and content-pack versions
- artifact SHA-256
- signing state

## Build matrix (each target judged independently)

| Target | Host | Command | Artifact | Signing |
|---|---|---|---|---|
| Web (private app) | Linux | `flutter build web --release --no-web-resources-cdn --dart-define=APP_ENV=…` | `human_health_os/build/web/` | n/a, HTTPS hosting |
| Linux (product, D-008) | Ubuntu 22.04 builder (glibc floor) + GTK3 dev | `flutter build linux --release`, then package | `HumanHealthOS-Linux-x64-Portable.tar.gz`, `.AppImage`, `.deb`, `.rpm`, Flatpak | GPG-signed repo metadata / detached signatures |
| Android | Linux/macOS + Android SDK, reaching Google Maven | `flutter build apk` and `flutter build appbundle` | APK, AAB | Upload key in protected CI secrets |
| iOS | macOS + Xcode | `flutter build ipa` | IPA | Apple distribution certificate |
| macOS | macOS + Xcode | `flutter build macos`, then create a DMG/PKG | `.app`, DMG | Developer ID + notarization + stapling |
| Windows portable | Windows + VS C++ workload | `flutter build windows`, then zip the `Release` folder with `portable_mode.json` and an empty `UserData/` | `HumanHealthOS-Windows-x64-Portable.zip` | Authenticode on the EXE/DLLs |
| Windows installer | Windows | Installer script (e.g. Inno Setup or MSIX), chosen and recorded at that FORGE | `HumanHealthOS-Setup-x64.exe` | Authenticode |
| Build Lab (synthetic) | Linux | `pnpm --filter @hhos/site build` | static site / artifact | n/a |

Never handcraft an EXE, DMG or APK from the spec. "Portable ZIP exists" ≠ "clean-machine portable PASS". "DMG exists" ≠ "notarized".

## Windows specifics

- **Portable layout:** `HumanHealthOS.exe` + runtime DLLs + `data/` + `portable_mode.json` + `UserData/` (encrypted vault). The vault opens with a passphrase on any PC. The profile identity is a UUID stored inside the vault.
- **Installer:** Start Menu entry, optional desktop shortcut, per-user install by default, clean uninstall that **keeps** `%LOCALAPPDATA%\HumanHealthOS` unless the user explicitly chooses to delete data.

## Updates and rollback

Update metadata covers release ID, platform/architecture, schema compatibility, artifact SHA-256 and signature/attestation locator. HTTPS alone does not make metadata trusted, so production needs signed metadata. Before a schema-changing update the app takes a vault checkpoint. Binary rollback, schema rollback and rule/content-pack rollback are separate operations. Offline, the update status reads "unavailable", never "up to date".

## Supply chain

The lockfiles are committed. Dependency updates go through lockfile diff → license and security review → analyze and test → platform smoke. Public releases need an SPDX or CycloneDX SBOM. Unknown or incompatible licenses block a release. Provenance is recorded and moves toward SLSA, but no SLSA level is claimed. Attestation states are NOT_GENERATED, GENERATED_UNVERIFIED, VERIFIED or INVALID.
