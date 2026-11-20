# Release strategy

Status: channels below are **SPECIFIED**; only unsigned preview pre-releases are built (next section, D001), each in a development and an encrypted flavour (D-049). See `project_state/CURRENT_STATE.json`.

## Preview downloads: one release page per build (D001, D-049)

Stable link for people: **https://github.com/kaansavukduran/human-os/releases** (Settings links there too). Each push to `main` that touches the app, packaging or these workflows runs `.github/workflows/downloads.yml`, which ends in **one** pre-release holding every platform's files:

```
linux (ubuntu-22.04) ─┐  development: flutter build linux → start check → package.sh → .deb .rpm .AppImage
                      │  encrypted:   APP_ENV=staging build → no-write start check → FLAVOR=encrypted package.sh
                      │               → .deb .rpm .AppImage portable .tar.zst
android ──────────────┤  development APK + AAB; encrypted (staging) APK (development signing key)
macos ────────────────┤  development .app zipped → start check; encrypted "Human OS encrypted.app" → no-write start check
web ──────────────────┤  tools/package_web_local.sh → web zip with the localhost launcher (development only)
windows ──────────────┤  reusable windows-exe.yml → development portable zip + Setup.exe → start check;
                      │  encrypted portable zip (portable_mode.json) + Setup.exe → no-write start check
                      └→ release (needs all, runs unless cancelled):
                         download artifacts Human-OS-* → tools/release/release_notes.py
                         → SHA256SUMS + EN/TR note → gh release create (one tag)
```

- **Two flavours (D-049).** *Development* (`APP_ENV=development`): for trying the app; entries are kept unencrypted and the app says it is a development build. *Encrypted* (`APP_ENV=staging`): for a person's own records; entries are kept only in the encrypted vault (F006, D-016), nothing is written before the vault is created or unlocked, and a staging build does not open a development vault. The flavour is in the file name: the encrypted files carry `-encrypted-` right after the version, the development files keep their earlier names.
- **Files, development:** `Human-OS-<version>-windows-x64-Setup.exe`, `…-windows-x64-portable.zip`, `…-macos.zip`, `…-android.apk`, `…-android.aab`, `…-linux-amd64.deb`, `…-linux-x86_64.rpm`, `…-linux-x86_64.AppImage`, `…-web.zip`.
- **Files, encrypted:** `Human-OS-<version>-encrypted-windows-x64-Setup.exe`, `…-encrypted-windows-x64-portable.zip`, `…-encrypted-macos.zip`, `…-encrypted-android.apk`, `…-encrypted-linux-amd64.deb`, `…-encrypted-linux-x86_64.rpm`, `…-encrypted-linux-x86_64.AppImage`, `…-encrypted-linux-x86_64-portable.tar.zst`; plus `SHA256SUMS`. iOS is not built (needs an Apple signing identity); the note says so.
- **Side by side.** The encrypted Windows installer (own AppId, "Human OS (encrypted)", `Human OS encrypted` folder), the Linux packages (`human-health-os-encrypted`, command `human-health-os-encrypted`, desktop id `org.humanhealthos.HumanHealthOS.Encrypted`) and the Mac bundle (`Human OS encrypted.app`) install beside the development app and never replace it. Android cannot: both APKs share one application id, so a phone holds one of them; the note says so. The Windows encrypted portable zip carries `portable_mode.json` (vault in `UserData\` beside the exe). The Linux portable tar.zst always carries `portable_mode.json`, which makes even a development bundle keep an encrypted vault, so it is published only as the encrypted build.
- **Web: development only.** A web build other than development is memory-only (G-32): it would keep nothing after the tab closes, so an "encrypted" web zip could not keep records. The note says so.
- **Start checks.** Development builds: alive after 10 s (Linux, Windows, macOS). Encrypted builds, started without unlocking: alive after 10 s **and nothing written**. Linux: `tools/linux/no_write_start_check.sh` under Xvfb with a fresh `XDG_DATA_HOME`, listed with checksums before and after (any new file or folder fails). Windows: the encrypted portable folder (`UserData\` must not appear) and the Release exe as the installer ships it with `HHOS_DATA_DIR` set to a fresh path (it must not appear). macOS: the sandbox container's and the plain `Application Support/HumanHealthOS` folders, listed with checksums before and after. Android: no start check (no device or emulator). These checks prove "starts and writes nothing before unlock"; they do not see the screen, install the Setup.exe/.deb/.rpm/.app on a real machine, or unlock a vault.
- **Note:** "Which file should I choose?" / "Hangi dosyayı seçmeliyim?" explains in plain words: the development build to try the app (not encrypted); the encrypted build for real records (a passphrase and a recovery key; if both are lost nobody can recover the data); the encrypted build does not open or import development entries (keep a backup or export of them); the web zip is development only; unsigned previews (SmartScreen/Gatekeeper warnings); not for clinical decisions. It lists only the files really attached, grouped by flavour, and a "missing" section names every expected file that is absent (with its flavour) and every platform job that did not succeed. The generator refuses an empty set (exit 1) and any file it cannot classify (exit 2), so it never claims a file that is not there. Dry run: see the docstring of `tools/release/release_notes.py`.
- **Failure handling:** platform jobs are independent; the release job runs with `if: !cancelled()` and publishes what exists. Inside a platform job the encrypted steps run after the development ones (they build into the same folder) but also when a development step failed, and the upload runs unless cancelled, so each flavour ships on its own. On Linux, a failed AppImage step (appimagetool 1.9.0 is downloaded from its GitHub release, not checksum-pinned) still lets the other formats ship.
- **Uniqueness and retention:** version `0.1.1-dev.<run_number>` (packages: `0.1.1~dev.<run_number>`; 0.1.1 starts the single all-platform release, so it never repeats an older per-platform `0.1.0-dev.N` page), tag `preview-<version>-<run_id>-<run_attempt>`; releases and tags are never deleted or replaced; publishing is serialized per branch.
- **Permissions:** platform jobs `contents: read`; only the release job gets `contents: write` through the built-in `GITHUB_TOKEN`. No other secret is used.
- **Evidence level:** the workflows are statically checked (actionlint with shellcheck; the PowerShell steps are not linted here), `package.sh` is run locally for both flavours on a stand-in bundle, `no_write_start_check.sh` is exercised locally with stand-in commands, and the note generator is dry-run on fake files of both flavours. The real artifacts, their start checks and the published page are verified only by a run on GitHub; until then they are NOT_RUN. Installing a release .deb is covered separately by `linux-deb-install-smoke` in `ci.yml` (development flavour).
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
