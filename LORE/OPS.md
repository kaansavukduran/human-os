# OPS: how do we work, test, release, and what usually breaks?
Çalıştırma, dağıtım, test, sık hatalar. Commands: [STACK.md](STACK.md). Detail: [TEST_STRATEGY.md](../docs/TEST_STRATEGY.md), [RELEASE_STRATEGY.md](../docs/RELEASE_STRATEGY.md), [DEVELOPMENT_PLAN.md](../docs/DEVELOPMENT_PLAN.md).

## FORGE workflow (master §22, §31–§34; v0.32 execution kernel)
- `FORGE` = one bounded increment: orient → select gap → specify → implement → test → fix the first failure → retest → regression → audit → package → update state → stop. `FORGE xN` = up to N, each closed on its own.
- Ladder F001–F017 ([ROADMAP.md](../docs/ROADMAP.md)); owner experience track U001… (D-020); review runs R<n>; ids carry the contract (`U037@v0.32`).
- A first one-shot run (master + "START") is Phase 0 → F001 → stop, never Phase 0 alone.
- On start/resume: read the state file, compare with `git status`, resume from the first unverified action; never mark an interrupted Forge complete because code exists. Repository reality beats the state file; record the discrepancy.
- Close: update `CURRENT_STATE.json`, `FORGE_LOG.md`, `RISKS.md`, `KNOWN_GAPS.md`; recommend exactly one next Forge. Report: v0.32 FINAL REPORT CONTRACT (one-shot) or §24.

## Gates and evidence
```bash
python3 tools/evidence/run_gate.py --id <EV-…> --kind TEST|BUILD|RUNTIME --forge <F…@contract> \
  [--covers <paths>] [--target/--arch/--profile/--signing] -- <command>
```
- Commit before running gates: a dirty tree is recorded and rejected for verified gates.
- Receipts go to `evidence/{tests,builds,runtime}/`; no PASS without a receipt. Evidence goes stale when anything it covers changes (§33.5); `tools/validate_project_state.py` checks this.
- Closing set: `verified_gates` in `CURRENT_STATE.json` (U037: 14 gates, incl. pub get, format, analyze, flutter test in UTC and America/New_York, tooling tests, web build, web and appearance smokes, Linux integration and build, contracts, pnpm test).
- Evidence ladder, never collapsed: PLANNED < SPECIFIED < IMPLEMENTED < STATICALLY_TESTED < UNIT_TESTED < INTEGRATION_TESTED < COMPILED < RUNTIME_TESTED < PACKAGED < SIGNED < NOTARIZED < DEPLOYED; plus NOT_RUN, UNAVAILABLE, BLOCKED_ENVIRONMENT, BLOCKED_BY_HOST_OS, UNKNOWN. A build is COMPILED, not RUNTIME_TESTED. Never hand-craft binaries.
- A Linux pass never stands in for Windows, macOS, Android or iOS.

## CI and release workflows (`.github/workflows/`)
| Workflow | Trigger | Jobs |
|---|---|---|
| `ci.yml` | push (all branches), pull_request | ts-reference-and-build-lab, flutter-linux-web, linux-deb-install-smoke, flutter-android, flutter-windows, flutter-macos |
| `downloads.yml` | push to `main` (app, packaging, release paths), manual | linux, android, macos, web, windows → release (one pre-release per build) |
| `windows-exe.yml` | workflow_call (from downloads), manual | windows |
| `pages.yml` | push to `main` (`human_health_os/**`), manual | build, deploy (development web build to GitHub Pages) |

- Two flavours per preview (D-049): development (unencrypted, labelled) and `-encrypted-` (staging vault). Web is development only.
- Releases and tags are never deleted or replaced; each build gets its own versioned pre-release.
- `main` moves only with closed, receipt-backed Forges; development on `claude/code-capabilities-kz21fr` (D-017).
- Pages needs the owner's one-time setting Settings > Pages > Source: GitHub Actions (STATE).

## Owner process rules (from AGENTS.md, meaning unchanged)
- The owner's latest explicit request beats attached planning documents. Answer in the language of the owner's latest message; say what changed, where to open it, which checks ran, what is blocked. No prose em dashes.
- UI changes: `flutter analyze`, `flutter test`, a real web build and browser smoke; CI covers other hosts.
- After a successful code push, back up that commit's sources (ZIP) and all Git refs (bundle) to the owner's private Drive project folder (its id is not kept in the repository; the owner gives it when needed); exclude credentials and signing keys; if blocked, report pending.
- Signed distribution, Android signing continuity, Apple signing/notarization/store access and a real two-package update drill must be verified before they are claimed. Never call an unsigned or untested candidate stable.

## Safety rules
- Never commit secrets or real health data; never put server secrets in Dart, `--dart-define` or a web bundle.
- Git: no `reset --hard`, `clean -fd` or force-push; work on the designated branch.

## Common errors (seen before)
- Blank web app with `RangeError: Incorrect locale information` in headless Chromium (`en-US@posix`): pin `en-US`/`tr-TR`, set `LANG=C.UTF-8` (R-11).
- Linux package installs but aborts at start ("Couldn't open libGLESv2.so.2"): dlopen'd GL libraries must be declared (R-15, D-041); check `LD_DEBUG=files` after each Flutter upgrade.
- Runtime floor rises on a newer build host (GLib 2.80 symbols): GLib API cap 2.64 and `tools/linux/check_symbols.sh` (R-16, D-010).
- Web start fetches CanvasKit from a CDN and fails offline: build with `--no-web-resources-cdn` (R-09).
- Appearance smoke failed only in CI because no local gate ran it: run it locally too (C001).
- Windows CI Labs tests must wait for the real-file read before scrolling (fixed in 50ba9fa).
- Web smoke clicks About with `force`: an empty full-window semantics node fails Playwright's actionability check (Q001, U036).
- Linux integration test tapped a tile hidden behind "More measurements" (U036, fixed in e83b156).
