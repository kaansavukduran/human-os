# AGENTS.md: Human OS (Codex and other agents)
Human OS is a local-first personal health app: one Flutter app in `human_health_os/` for six platforms; do not rebuild it as a separate site or extend the frozen `apps/client`.

**First read `LORE/STATE.md`, then only the LORE file your task needs.** The owner's latest explicit request beats attached planning documents.

| Question | File |
|---|---|
| Where are we, what is next? | `LORE/STATE.md` |
| Architecture, invariants, owner product requirements | `LORE/ARCH.md` |
| Stack, versions, commands | `LORE/STACK.md` |
| Record model, storage | `LORE/DATA.md` |
| Workflow, gates, releases, owner process rules | `LORE/OPS.md` |
| Decisions | `LORE/DECISIONS.md` |
| Reading and updating LORE | `LORE/GENERATE.md` |

## Critical rules
1. Every changed flow complete in Turkish and English; keep the user's records, settings and migration compatibility.
2. Health semantics, append-only corrections, the encrypted-vault policy and the offline core stay as specified (`LORE/ARCH.md`, `LORE/DATA.md`).
3. One bounded Forge; commit before `run_gate.py`; update state, log and gaps with real evidence; recommend one next Forge.
4. Never publish a secret, a real health record or a private Drive source; keep all earlier releases and tags.
5. Answer in the language of the owner's latest message; say what changed, which checks ran and what is blocked.

Privacy: LORE holds only rules, decisions and architecture. The owner's private backup-folder id is not kept in the repository; the owner gives it when needed (owner decision, 2026-11-25).
