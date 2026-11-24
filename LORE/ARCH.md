# ARCH: how is the system built?
Mimari, modüller, akış. Summary of [ARCHITECTURE.md](../docs/ARCHITECTURE.md) (wins on detail) and ADR-IMPL-002.

## Shape
```
contracts/golden_vectors/*.json  (language-neutral contract, 73 vectors)
   ▲ Dart human_health_os/lib/src/domain   ▲ TS packages/domain   ▲ Python tools/verify_contracts.py
   │ (product core)                        │ (reference oracle)   (independent port)
human_health_os (Flutter app)              ├── apps/site     → Build Lab (synthetic only)
  features → application → domain ports ← data adapters (vault, import/export, later sync)
  platform adapters: Health Connect · HealthKit · key stores · file picker · browser storage
  targets: Android · iOS · Web/PWA · Windows (portable + installer) · macOS · Linux (D-008)
```

## What lives where
| Path | Role |
|---|---|
| `human_health_os/` | The product: one Flutter app for all six surfaces. Pure-Dart domain in `lib/src/domain/` (no Flutter, IO or HTML imports). |
| `contracts/golden_vectors/` | Contract every engine in every language must pass. |
| `packages/domain` (TS) | Reference oracle; used by the Build Lab and the reference API. |
| `apps/site` | Human OS Build Lab: synthetic teaching/simulation lab (React). Not a product surface. |
| `services/api` | Reference sync/API candidate (Node + SQLite), dev auth only. |
| `apps/client` | Frozen React/Capacitor prototype; retired at parity. Do not extend. |
| `docs/handoff/` | Specs as received (v0.24 semantics, v0.27/v0.28 candidates, v0.31, current v0.32 master). |
| `project_state/` | Canonical state, FORGE log, decisions, risks, gaps, sources (validators depend on it). |
| `evidence/` | Machine-written JSON receipts from `tools/evidence/run_gate.py`. |
| `reports/` | Older evidence (screenshots, logs) kept for history. |
| `packaging/`, `tools/linux/`, `tools/release/` | Linux/Windows/web packaging and release-note inputs. |
| `docs/lore/` | Fictional Aion lore (D-051); never enters medical content. Keep/remove is open (STATE). |

## Flutter app layout (`human_health_os/lib/src/`)
- `app/` bootstrap, storage choice and fallback · `config/` AppConfig (`APP_ENV`, `APP_VERSION`, `SOURCE_REVISION`; no secrets)
- `core/` capability registry, Clock, UUID ids, `redact.dart` (the only console writer: type + code)
- `domain/` pure Dart: `records/` (envelope, validation, timeline), `profile/`, `ports/`, `engines/` (F011), `derived/`
- `application/` use cases (`HeartbeatService`) · `data/local/` log, migrations, encrypted envelope · `data/crypto/` · `data/backup/`
- `features/` one folder per area (vault gate, today, labs, medications, documents, derived …) · `navigation/` responsive shell · `l10n/` EN/TR strings
- Dependency direction `features → application/domain ports ← data adapters`; `test/architecture/imports_test.dart` enforces it.

## Key flows
- **Persistence:** one `HealthRepository` port over four sinks: memory, file (development desktop), browser `localStorage` (development web), encrypted envelope (staging, production, portable). Details: [DATA.md](DATA.md).
- **Timeline:** records are never edited. A correction is a new version; *entered in error* voids its target; *deleted* is a tombstone; two live corrections are a conflict, never resolved by timestamp.
- **Capabilities:** `CapabilityRegistry` reports what really exists on this runtime; unavailable integrations are shown as unavailable, never borrowed from another platform.
- **Engines (F011):** Dart ports of MP-CORE-DERIVED-1, NUTRITION-MATH-1, LAB-INTERPRETATION-ENGINE-1, MED-SAFETY-ENGINE-1, PREVENTIVE-ENGINE-1; every result carries model id/version, inputs, missing inputs, limitations (D-037, D-038). Only the derived-values screen uses them (D-039).
- **Migrations (master §35):** vault format 1; newer vault/record schema refused, never overwritten; older data migrated in memory, read-only, with receipts; a checkpoint backup precedes the first record of a newer schema (D-018).

## Invariants (never break; master §2 wins where this differs)
planned ≠ completed · prescribed ≠ taken · reminder ≠ completion · missing ≠ zero · unknown ≠ false · source text ≠ normalized interpretation · association ≠ causation · risk estimate ≠ diagnosis · screening ≠ diagnosis · scenario ≠ observation · model output ≠ observed fact · reference interval ≠ optimal target · reference interval ≠ clinical decision limit · outside reference ≠ critical · self-report ≠ diagnosis · no interaction found ≠ safe · unknown history ≠ zero history · same display name ≠ same measurand.
- Corrections create new records; history is never rewritten silently.
- Every computed result carries its model or rule id and version, inputs, missing inputs and limitations.
- Build Lab synthetic data never mixes with real profiles. The core never requires an LLM or the network.

## Owner product requirements (from AGENTS.md, meaning unchanged)
- Every changed flow complete in Turkish and English (`lib/src/l10n/strings.dart`); first launch uses a supported device language, otherwise Turkish; keep selections, typed text, records, settings and migration compatibility.
- Settings easy to reach. Appearance: light, dark, system, high contrast, accent, independent text size, bundled Turkish-capable reading/dyslexia fonts, motion, density, layout. Interface scale 80–200% (five-point slider, exact input, six presets, own reset); never silently reduce a chosen scale.
- Keyboard focus, screen-reader labels, touch targets, narrow layouts and 200% scale are acceptance requirements; check real rendered Turkish text.
- Gamification optional and calm: reward no clinical value or risky behaviour; count only explicit completed actions, deduplicated; never infer completion from a plan, retry or elapsed time.
- One shared core for Windows, Linux, macOS, Android, iPhone and web; each build, install, signing and runtime reported separately.
