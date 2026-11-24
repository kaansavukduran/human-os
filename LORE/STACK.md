# STACK: which technologies, versions and commands?
Teknoloji yığını, sürümler, komutlar. Sources: `human_health_os/pubspec.yaml`, `package.json`, [DEVELOPMENT_PLAN.md](../docs/DEVELOPMENT_PLAN.md).

## Product (Flutter app, `human_health_os/`)
| Item | Version / note |
|---|---|
| Flutter / Dart | 3.47.6 / 3.13.5 (pinned; SDK constraint `^3.13.5`) |
| App version | `0.2.0+2` (pubspec); preview downloads `0.2.0-dev.<run_number>` |
| Runtime deps | `flutter`, `flutter_localizations` (SDK); `crypto ^3.0.7` (D-015); `pointycastle 4.0.0` exact (D-016); `file_picker ^13.3.2` + `file_picker_web ^4.2.0` (D-021, D-044) |
| Dev deps | `flutter_test`, `integration_test` (SDK), `flutter_lints ^6.0.0` |
| Bundled fonts | OpenDyslexic, Atkinson Hyperlegible Next (D-025), Lexend (D-042); SIL OFL 1.1 |
| Assets | `assets/aion/` (owner's artwork, D-029b) |

## Reference and Build Lab (TypeScript monorepo)
| Item | Version / note |
|---|---|
| Node | ≥ 22.18 (native type stripping; no build step for packages) |
| pnpm | 10.28.0 (`packageManager`) |
| TypeScript / vitest | 7.0.2 / 5.0.3 |
| React | 19.3.0 (Build Lab, frozen client) |
| Playwright | `@playwright/test` 1.56.1 (pinned to the preinstalled Chromium) |
| Python | ≥ 3.10 (`tools/verify_contracts.py`, state/evidence tools) |
| Root package version | `0.25.0` (TS workspace label; not the app version) |

## Toolchain setup (fresh container)
```bash
export PATH=/opt/toolchains/flutter/bin:$PATH        # install steps + SHA-256: docs/DEVELOPMENT_PLAN.md
export CHROME_EXECUTABLE=/opt/pw-browsers/chromium   # link to the installed Chromium
flutter config --no-analytics && flutter precache --web
```
No SessionStart hook yet (G-10): repeat in every fresh cloud container.

## Commands (from CLAUDE.md)
```bash
flutter doctor -v                                    # informational
cd human_health_os && flutter pub get && dart format --set-exit-if-changed . && flutter analyze && flutter test
flutter build web --release --no-web-resources-cdn --dart-define=APP_ENV=development \
  --dart-define=APP_VERSION=0.1.0+1 --dart-define=SOURCE_REVISION=$(git rev-parse HEAD)
xvfb-run -a flutter test integration_test -d linux   # real file IO, relaunch, folder move (libgtk-3-dev)
cd .. && EXPECT_FLUTTER_VERSION=3.47.6 node tools/flutter_web_smoke.mjs   # Today → Timeline → Labs smoke
node tools/flutter_appearance_smoke.mjs              # interface scale, fonts (CI runs it, C001)
python3 tools/validate_project_state.py && python3 -m unittest tools/evidence/test_run_gate.py
pnpm install && pnpm typecheck && pnpm test && python3 tools/verify_contracts.py
```
- `--no-web-resources-cdn`: otherwise CanvasKit/fonts come from a CDN at start (R-09).
- `FLUTTER_VERSION` is reserved: never pass it as a define; versions reach the app through `FlutterVersion`.
- TS dev servers: `pnpm dev:site` (:5173), `pnpm dev:api` (:8787/v1/health), `pnpm dev:client` (:5174).

## Dependency rule (D-007)
SDK first. A third-party package needs a recorded review in `project_state/DECISIONS.md` first (purpose, licence, maintenance, platforms, native code, privacy, why the SDK is not enough). Commit `pubspec.lock` and `pnpm-lock.yaml`; CI uses `--enforce-lockfile` / `--frozen-lockfile`; no git or path dependencies in release builds.
