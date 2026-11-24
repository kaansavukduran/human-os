# CLAUDE.md: Human OS
Human OS is a local-first personal health app: one Flutter app (`human_health_os/`) for Android, iOS, web, Windows, macOS and Linux, with a TypeScript reference oracle and a synthetic Build Lab.

**First read `LORE/STATE.md`, then only the LORE file your task needs.** Canonical state stays in `project_state/` (code wins over both).

| Question | File |
|---|---|
| Where are we, what is next, what is open? | `LORE/STATE.md` |
| Architecture, modules, invariants | `LORE/ARCH.md` |
| Stack, versions, commands | `LORE/STACK.md` |
| Record model, schemas, storage | `LORE/DATA.md` |
| FORGE workflow, gates, CI, releases, common errors | `LORE/OPS.md` |
| Decisions and why | `LORE/DECISIONS.md` |
| How to read and update LORE | `LORE/GENERATE.md` |

## Critical rules
1. Never break the invariants (planned ≠ completed, missing ≠ zero, model output ≠ observed fact …; full list `LORE/ARCH.md`, master §2 wins).
2. Storage: only development builds write an unencrypted, labelled log; staging, production and portable builds persist only through the encrypted vault, nothing before unlock, never a plaintext fallback; non-development web is memory only.
3. Never commit secrets or real health data; no server secrets in Dart, `--dart-define` or a web bundle; new dependencies only after a recorded review.
4. One bounded FORGE at a time; commit before `tools/evidence/run_gate.py`; no PASS without a receipt; a build is COMPILED, not RUNTIME_TESTED.
5. Git: no `reset --hard`, `clean -fd` or force-push; work on the designated branch.

Privacy: LORE holds only rules, decisions and architecture: no personal data, secrets, Drive or account ids, or copyrighted content.
