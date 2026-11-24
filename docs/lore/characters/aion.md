# Aion

> **Türkçe özet.** Aion, sahibin karakteri: pembe bir aksolotl, uçları mavi solungaçlar, mavi gözler, sonsuzluk-yaprak amblemli beyaz laboratuvar önlüğü ve DNA desenli kuyruk. Human OS'ta yalnızca hareketsiz, etiketli bir resimdir (tanıtımın ilk adımı ve boş ekranlar); konuşmaz, öneri vermez, bir hekimin yerine geçmez, Ayarlar'dan gizlenebilir. Yanındaki tek cümle tarafsızdır: bir değer, bir sayı ya da övgü içermez.

Status of each fact: see [canon.md](../canon.md) (L-003, L-005 to L-008, L-013 to L-015).

## Appearance (CANON, L-005)

| Feature | Canon |
|---|---|
| Species | Axolotl |
| Body colour | Pink |
| Gills | External gills, pink with **blue tips** |
| Eyes | Blue |
| Clothing | White lab coat |
| Emblem | Infinity-leaf emblem on the coat |
| Tail | DNA-patterned |

**Source:** the owner's main reference in Drive, `Aion_Ana_Karakter_Referansi.png`, recorded in D-029 (A001) in [project_state/DECISIONS.md](../../../project_state/DECISIONS.md). The colours, proportions and distinguishing features are kept as drawn (AIONIA §4). The Drive four-move sheet draws the gills fully pink, so it is not used.

Personality, motivation, relationships and origin (fields AIONIA §2 asks a character record to hold) are **not defined** by any source for Human OS. They are gaps, not facts to invent. Any proposal goes through [canon.md](../canon.md) as PROPOSAL.

## What Aion does in the app (CANON, L-006 to L-008)

- Appears as a **still picture** in three places: the first introduction step, beside the empty weight card on Today, and the shared empty state of record areas (`FirstStep`, for example empty Labs and Timeline).
- On the introduction, **one neutral line** is shown beneath it, the same all day, picked by the day of the year from six lines (`aionLines`, `aionLine` in [strings.dart](../../../human_health_os/lib/src/l10n/strings.dart)).
- Can be **hidden everywhere** with Settings → "Show Aion" (default on, saved with the display choices; Reset Today keeps it). Hiding it hides the line too and changes no record.

## What Aion never does

- Speaks as a clinician, gives advice, explains a result, or suggests an action about health.
- Reacts to what the person saved: no celebration, no worry, no change of pose, no reward.
- Shows or mentions a value, a count, a trend, a score or praise.
- Appears on a record, a lab result, a medicine, a derived value, an export, a backup, a notification or a loading screen.
- Blocks, delays or covers an action (it is decoration on screens that already have their own action).
- Claims that data is kept (memory-only web builds keep nothing, G-32; fixed in R015).

## Voice rules for lines shown beside Aion

Full rules: [tone-and-voice.md](../tone-and-voice.md). In short: one plain sentence about **where things are, how corrections work, or what stays private**; never a value, a count or praise; both English and Turkish; checked by the tests named there.

## Accessibility

- The picture carries a screen reader label: "Aion, the Human OS character, waving" / "Aion, Human OS karakteri, el sallıyor" (`aionAlt`).
- It is drawn at its displayed size; a missing or unreadable picture leaves only empty space, never an error.
- It is a still picture, so reduced motion needs no extra handling. Any future animation must stop under reduced motion and when Aion is hidden.
- Nothing is understood only through Aion: every empty state has its own sentence and action.

## Assets in the repository

| Path | What | Licence |
|---|---|---|
| [human_health_os/assets/aion/aion_wave.png](../../../human_health_os/assets/aion/aion_wave.png) | 473×480 RGBA, cropped and scaled from `Aion_Ana_Karakter_Referansi.png` | Owner's artwork, included at the owner's request; **not** under an open licence |

Code: [human_health_os/lib/src/presentation/widgets/aion.dart](../../../human_health_os/lib/src/presentation/widgets/aion.dart) (`AionFigure`, `AionLine`).

## Open questions

- **Animation** waits for reference sheets that match the current main reference (blue-tipped gills). No frames are made from the four-move sheet and no missing move is faked with repeated frames (AIONIA §4).
- Whether Aion is an AIONIA-wide character or a Human OS variant, and whether the introduction line counts as Aion's voice: see "Open questions" in [canon.md](../canon.md).
