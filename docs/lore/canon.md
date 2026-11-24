# Canon

> **Türkçe özet.** Her lore maddesinin bir durumu vardır: KANON (sahibin onaylı kaynağından), ONAYLI TASLAK (kullanım için onaylı ama nihai değil), ÖNERİ (çıkarım ya da yeni fikir; kanon sayılmaz) ve EMEKLİ (artık geçerli değil, tarih olarak saklanır). Ayrıca AIONIA §2 katmanı yazılır: ANA (evren geneli) ya da YEREL (yalnızca Human OS). Kaynağı olmayan hiçbir şey kanon değildir.

## Status levels

| Status | Meaning | AIONIA §2 equivalent | Who sets it |
|---|---|---|---|
| **CANON** | Taken from an owner-approved source (the AIONIA standard, an approved Drive reference, an owner decision recorded in `DECISIONS.md`). | ANA or YEREL | The owner |
| **APPROVED DRAFT** | Approved for use in this project, but the owner has not called it final (for example a reference sheet marked "TASLAK 01"). | TASLAK, approved for use | The owner |
| **PROPOSAL** | Inferred, suggested or new. Not canon; never shown in the product as if it were. | TASLAK | Anyone, through the [lore change template](../../.github/ISSUE_TEMPLATE/lore-change.md) |
| **RETIRED** | No longer valid. Kept as history, never deleted (history is never rewritten silently). | — | The owner |

Each entry also names its **layer**: **ANA** (a universe-wide fact, AIONIA §2) or **YEREL** (true for Human OS only). OYUN and ALTERNATİF layers (game events, a separate continuity) do not occur in this project.

## Current canon list

| ID | Entry | Status | Layer | Source |
|---|---|---|---|---|
| L-001 | AIONIA is an original, multi-world fictional universe open to expansion, under Fragaria Interactive. It is not a single game or a single planet. | CANON | ANA | AIONIA standard, header and §1 |
| L-002 | Fragaria Interactive is the main product and publishing brand; AIONIA is the fictional universe. "Fragaria Games" is not a required sub-brand. | CANON | ANA | AIONIA standard, header, §11, §22.10 |
| L-003 | Aion can be a character; the universe is named AIONIA (Aion is not the universe). | CANON | ANA | AIONIA standard §1 |
| L-004 | The universe's atmosphere is cute, profound and epic. In Human OS this atmosphere is **not** applied to the product surface (§11). | CANON (not applied here) | ANA | AIONIA standard §1, §3, §11 |
| L-005 | Aion's appearance: pink axolotl, blue-tipped external gills, blue eyes, white lab coat with the infinity-leaf emblem, DNA-patterned tail. | CANON | ANA | Drive reference `Aion_Ana_Karakter_Referansi.png`; D-029 (A001) |
| L-006 | In Human OS, Aion is a still, labelled picture on the first introduction step, beside the empty weight card and on the shared empty state of record areas; it can be hidden in Settings ("Show Aion", default on). | CANON | YEREL | D-029 (A001); U031, U033 in `FORGE_LOG.md` |
| L-007 | In Human OS, Aion says nothing, gives no advice and does not stand for a clinician. | CANON | YEREL | D-029 (A001) |
| L-008 | One neutral line, the same all day, is shown beside Aion on the introduction: where things appear, how a correction works, what stays private; never a value, a count, praise, or a claim that data is kept. | CANON | YEREL | U031, R015 in `FORGE_LOG.md`; `aionLines` in `human_health_os/lib/src/l10n/strings.dart` |
| L-009 | Human OS is an independent application of the owner; Fragaria Interactive and AIONIA are not shown as brands in the product. | CANON | YEREL | `docs/DESIGN_BRIEF.md`; AIONIA §14.1 |
| L-010 | Lore lives in `docs/lore/`; the product boundary is unchanged. | CANON | YEREL | D-051 |
| L-011 | Other existing AIONIA characters named by the standard: Kurt, Kuzu, Baykuş Ömer, Tavşan Emre (Tavşan Emre's sheet is marked "3D MODEL REFERANSI · TASLAK 01"). None of them appears in Human OS; their appearance in any product is a separate scope decision. | CANON (existence only) | ANA | AIONIA standard §4, §22.9 |
| L-012 | Human OS is a place inside the AIONIA universe (a world, a region or an in-world institution). | PROPOSAL | — | Inferred; no source defines it. See [world.md](world.md). |
| L-013 | Aion's in-world role in Human OS is a "keeper of the record": it shows where things are and never reads them. | PROPOSAL | YEREL | Inferred from L-007 and L-008 |
| L-014 | Aion's default facing is three-quarter left; the asymmetric coat is never mirrored. | PROPOSAL (for Human OS) | — | YKSMania `docs/ART_BIBLE.md` (a project-specific decision there, not Human OS canon) |
| L-015 | A frame-by-frame Aion animation in Human OS. | PROPOSAL (waits) | YEREL | D-029: waits for sheets matching the current reference |

Nothing is RETIRED yet. The Drive four-move sheet is not an entry: D-029 records that it draws the gills fully pink, unlike the current reference, so it is not used (not retired canon, just not adopted).

## Open questions (recorded, not resolved)

- **Whose character is Aion?** D-029 and the app's label call Aion "the Human OS character"; the AIONIA standard (§1, §4) lists Aion among the universe's characters, and YKSMania uses the same Aion. Whether Aion is an AIONIA-wide character who appears in Human OS, or a Human OS-specific variant, is the owner's call. Until then L-005 is ANA (one appearance everywhere) and L-006 to L-008 are YEREL.
- **"Says nothing" and the introduction line.** D-029 says Aion says nothing; U031 added one line shown beside Aion. In the code the line is plain app text under the picture (no speech bubble, no quotation, `AionLine` in `human_health_os/lib/src/presentation/widgets/aion.dart`). This record reads it as the app speaking next to Aion, not Aion speaking. If the owner wants it read as Aion's voice, D-029 needs a new decision.
- **Two decisions numbered D-029** exist in `project_state/DECISIONS.md` (U022 appearance requirements and A001 Aion). This folder cites "D-029 (A001)". Renumbering would rewrite history, so it is left as is.
