# Human OS lore

This folder is the single canonical home of everything Human OS knows about its place in the owner's fictional universe: who Aion is, what the setting is, how companion lines sound, and which art may be used. It is the project's lore record in the sense of AIONIA §8 (`/docs/LORE_LINKS.md` is suggested there; this folder takes that role, so no second file exists).

> **Türkçe özet.** Bu klasör Human OS'un lore (evren bilgisi) kaydının tek kanonik yeridir: Aion kimdir, evrenle bağ nedir, Aion'un yanındaki cümleler nasıl yazılır, hangi görseller kullanılabilir. Lore yalnızca bu belgelerde ve Aion'un küçük, kapatılabilir görünüşünde yaşar; tıbbi içeriğe girmez, öneri vermez, bir değeri yargılamaz, oyunlaştırmaz (AIONIA §11). Kanon değişikliği sahibin (Kaan) onayını ve `project_state/DECISIONS.md` içinde bir karar kaydını gerektirir.

## The boundary rule (never break)

Human OS is a health application. AIONIA §11 (v1.1) says that banking, health, education or productivity apps get no forced mascot, gamification, pixel art or epic narrative, and §14.1 says Fragaria Interactive, the AIONIA universe and an independent app identity are not mixed up. In this repository that means:

1. **Lore lives in two places only:** these documents, and Aion's small, optional presence in the app (a still picture on the introduction and on empty states, and one neutral line on the introduction). See [characters/aion.md](characters/aion.md).
2. **Lore never enters medical content.** No lore word, character or story appears in a record, a lab result, a medicine, a derived value, a glossary entry about health, an export or a backup.
3. **Lore never gives advice, never judges a value, never counts, never praises.** A number is never "good" because Aion is near it.
4. **Lore never gamifies.** No points, streaks, badges, levels, rewards or reactions to what the person saved.
5. **Lore never changes the product invariants** in [CLAUDE.md](../../CLAUDE.md) (planned is not completed, missing is not zero, and the rest).
6. **Fragaria Interactive and AIONIA are not shown as brands in the product** ([docs/DESIGN_BRIEF.md](../DESIGN_BRIEF.md)). Aion can be hidden in Settings ("Show Aion"); hiding it changes no record.

This rule is recorded as decision D-051 in [project_state/DECISIONS.md](../../project_state/DECISIONS.md). Lore documentation does not widen what the product shows.

## How to add or change canon

1. Open an issue with the [lore change template](../../.github/ISSUE_TEMPLATE/lore-change.md): what, why, source, status asked.
2. Anything not taken from an owner-approved source enters [canon.md](canon.md) as **PROPOSAL** (AIONIA §2 and §9.7: proposed lore is marked TASLAK; unknown is a gap, not a fact to invent).
3. A move to **APPROVED DRAFT** or **CANON**, or to **RETIRED**, needs the owner's explicit approval (AIONIA §10: the universe identity, brand hierarchy and existing characters' core design change only with the owner's approval) and a decision record in `project_state/DECISIONS.md` naming the source.
4. Check for conflicts with existing entries before writing (AIONIA §2). A conflict is listed under "Open questions" in [canon.md](canon.md), never resolved silently.
5. Art follows [art/README.md](art/README.md): only the owner's approved art is used.

## Index

| File | What it holds |
|---|---|
| [canon.md](canon.md) | Status levels, the current canon list with sources, open questions |
| [characters/aion.md](characters/aion.md) | Aion: appearance, role in the app, voice rules, accessibility, assets |
| [world.md](world.md) | Human OS within the AIONIA universe and Fragaria Interactive |
| [tone-and-voice.md](tone-and-voice.md) | Calm, honest, precise; companion line rules in English and Turkish |
| [glossary.md](glossary.md) | Lore names and terms with their sources |
| [timeline.md](timeline.md) | When lore elements entered this project |
| [art/README.md](art/README.md) | Art direction and which AIONIA art rules apply here |

## Sources used

- The owner's AIONIA standard (Google Doc "AIONIA Standartları - Evrensel Tasarım ve Kalite", v1.7, 13 November 2026; read 2026-11-24): §0, §1, §2, §3, §4, §8, §9, §10, §11, §14.1, §14.7, §18, §19, §22.8, §22.9. How the repository applies it: [docs/AIONIA_STANDARD.md](../AIONIA_STANDARD.md).
- [docs/DESIGN_BRIEF.md](../DESIGN_BRIEF.md), [docs/HUMAN_OS_OVERVIEW.md](../HUMAN_OS_OVERVIEW.md), D-029 (A001) in [project_state/DECISIONS.md](../../project_state/DECISIONS.md), A001, U031, R015 and U033 in [project_state/FORGE_LOG.md](../../project_state/FORGE_LOG.md).
- The owner's sister project YKSMania (`docs/ART_BIBLE.md`, `README.md`), read for how the owner records Aion and canon; nothing from it is canon here unless an entry says so.
