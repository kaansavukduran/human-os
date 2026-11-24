# DATA: what does a record look like and where is it stored?
Veri modeli ve şemalar (gerçek veri yok). Details: [DATA_MODEL.md](../docs/DATA_MODEL.md), [SECURITY_MODEL.md](../docs/SECURITY_MODEL.md); normative: v0.24 handoff.

## Record envelope (every canonical record)
| Field | Meaning |
|---|---|
| `id` | Stable UUID, never derived from a path or display name |
| `profile_id` | Owning profile (UUID); a portable vault keeps it across machines |
| `kind` | e.g. `body.weight`, `lab.result`, `medication.intake` |
| `state` | OBSERVED · REPORTED · PLANNED · COMPLETED · DERIVED · MODELLED · ASSUMED · UNKNOWN |
| `value` / `value_status` | Typed value (may be absent) / PRESENT · NOT_REPORTED · NOT_MEASURED · NOT_APPLICABLE · UNKNOWN (missing is a status, never 0) |
| `context`, `details` | Free text as typed (≤ 500 chars) / kind-tagged structured value (e.g. blood pressure) |
| `original` | Source representation kept verbatim |
| `provenance` | MANUAL · DEVICE · PROVIDER · DOCUMENT · API · DERIVED · MODELLED · IMPORTED · UNKNOWN |
| `observed_at` / `recorded_at` | When it happened / when it was entered |
| `supersedes_id`, `amend_reason` | Correction lineage; a correction is a new record |
| `deleted_at` | Tombstone |
| `schema_version` | Record schema version |

Profiles: `SELF | REAL_OTHER | SYNTHETIC | SCENARIO`; synthetic and scenario profiles are labelled and never mix with SELF data.

## Record schema versions (all additive; each record written at the oldest schema that holds it)
| Schema | Adds | Decision |
|---|---|---|
| 1 | envelope, profile, `body.weight` (F002) | — |
| 2 | `amend_reason` (correction, entered in error, delete) (F003) | — |
| 3 | `lab.result` with printed details (F004) | — |
| 4 (RS-004) | waist, resting heart rate, blood pressure; `context`, `details` | D-018 |
| 5 (RS-005) | height, body temperature, SpO2, respiratory rate | D-019 |
| 6 (RS-006) | `medication.item`, `medication.plan`, `medication.intake` | D-030 |
| 7 (RS-007) | `sleep.night` | D-031 |
| 8 (RS-008) | `self.feeling_check_in` | D-032 |
| 9 (RS-009) | `nutrition.food_entry` | D-033 |
| 10 (RS-010) | `activity.entry` | D-034 |
| 11 (RS-011) | `condition.entry` | D-035 |
| 12 (RS-012) | `preventive.entry` | D-036 |
| 13 | `document.reference` (RS-013 label not used in the source) | D-040 |
| 14 (RS-014) | `lab.result` printed result: censored (`<`, `≤`, `>`, `≥`) or text | D-043 |
| 15 (RS-015) | lab `reported_at`, `method`, `reference_interval` as printed | D-045 |
| 16 (RS-016) | `glucose.capillary` (mg/dL or mmol/L as chosen), `body.fat_percentage` | D-048 |

An app refuses a store holding a newer record schema (`RECORD_SCHEMA_NEWER`) and leaves it untouched. Synthetic fixtures per schema: `human_health_os/test/fixtures/vault/`.

## Storage by build profile (`APP_ENV`)
| Profile | Where | Encrypted |
|---|---|---|
| development (desktop) | JSON-lines log under XDG (`$XDG_DATA_HOME/human-health-os/`), Application Support or LOCALAPPDATA | No, labelled "not encrypted (development)" |
| development (web) | browser `localStorage` | No |
| staging / production / portable desktop | `hhos-vault-enc` v1 envelope (`vault-staging.hhosvault`, `vault.hhosvault`; portable: `UserData/`) | Yes (D-016) |
| non-development web | memory only (G-32) | — |
| phones | app-private `HumanHealthOS/` via native channel (D-026), same policy | per profile |

- Nothing is written before the vault is created or unlocked; a failed unlock writes nothing; never a plaintext fallback.
- Unknown non-empty `APP_ENV`, or a release build without it, falls back to staging (fail closed) and does not open a development vault.
- Never write plaintext health data next to an executable.

## Encrypted vault (D-016)
Line 1: vault id + two wrapped copies of a random 256-bit data key (Argon2id from the passphrase; 160-bit recovery key shown once). Each log line sealed with ChaCha20-Poly1305 as `{"s":seq,"n":nonce,"c":sealed}`, vault id and sequence as associated data. Display preferences sealed beside it in `<vault>.prefs` (D-027).

## Backup, export, import
- Backup: `hhos-backup` bundle = manifest (format, app version/revision, vault id, schema versions, counts, SHA-256) + log bytes; restore runs the staged gate `stageRestore` before any write (F005).
- Export: `hhos-export` v1 JSON, `encryption: none`; from an encrypted vault only behind the warning (D-044).
- Import: development records enter only an empty encrypted vault (D-050); external formats not built (G-31).

## TS reference API
`services/api`: SQLite kernel `migrations/0001_kernel.sql`, invariants as CHECK constraints (PRESENT ⇒ value, COMPLETED ⇒ completion record).
