# Tone and voice

> **Türkçe özet.** Ton: sakin, dürüst, kesin (`docs/DESIGN_BRIEF.md`). Aion'un yanındaki cümleler tek ve sade bir cümledir; nerede ne olduğunu, düzeltmenin nasıl çalıştığını ya da neyin gizli kaldığını söyler. Bir değer, bir sayı, övgü, yargı ya da öneri içermez. "Sen" diye hitap eder, ünlem kullanmaz. Yasak kelimeler testlerde denetlenir.

## Tone

**Calm · honest · precise** (the design adjectives in [docs/DESIGN_BRIEF.md](../DESIGN_BRIEF.md)). Health data is personal; the app is quiet and trustworthy, never cheerful at the person's expense. The universe's "cute, profound and epic" atmosphere (AIONIA §1) is not used in product text (§11).

## Rules for lines shown beside Aion

A line is acceptable only if all of these hold:

1. **One plain sentence** (a semicolon may join two short clauses), no exclamation mark, no emoji.
2. **Topic** is one of: where something appears, how a correction or history works, what stays private or stays as typed, how to hide Aion.
3. **Never a value, a count, a trend or a date** of the person's data.
4. **Never praise, encouragement, worry or judgement** ("great", "healthy", "keep it up").
5. **Never advice** about health, and never a claim about the person's body.
6. **Never a claim that data is kept or stays**: memory-only web builds keep nothing (G-32, fixed in R015).
7. **True in every build** (development, encrypted, web) and on every platform.
8. **Same meaning in English and Turkish**; Turkish uses "sen", plain everyday words, and avoids words that sound clinical.
9. The same line all day (no reaction to what the person does).

### Current lines (CANON, L-008)

Source: `aionLines` in [strings.dart](../../human_health_os/lib/src/l10n/strings.dart).

| English | Türkçe |
|---|---|
| Nothing you enter here is sent anywhere; a backup is made only when you ask for one. | Buraya yazdığın hiçbir şey bir yere gönderilmez; yedek yalnızca sen istediğinde alınır. |
| A correction adds a new version; the old one stays in the history. | Düzeltme yeni bir sürüm ekler; eskisi geçmişte kalır. |
| You can type a value exactly as a report or a device shows it; the app never rewrites what you typed. | Bir değeri raporda ya da cihazda yazdığı gibi yazabilirsin; uygulama yazdığını değiştirmez. |
| A field you leave empty stays empty; the app never fills it in for you. | Boş bıraktığın bir alan boş kalır; uygulama onu kendisi doldurmaz. |
| Your records appear on the Timeline, newest first. | Kayıtların Zaman çizelgesinde, en yenisi üstte görünür. |
| Settings can hide Aion; your records stay as they are. | Ayarlar'dan Aion'u gizleyebilirsin; kayıtların olduğu gibi kalır. |

## Words never used

The tests hold the authoritative list; this page does not copy it, so it cannot drift.

- `gamified` in [u031_understand_test.dart](../../human_health_os/test/widget/u031_understand_test.dart): score, streak, XP, points, level up, badge, praise words (great job, well done, awesome, congratulations, bravo; harika, aferin, tebrik), and verdicts (healthy, unhealthy, normal, abnormal, risk; sağlıklı, sağlıksız, anormal; puan, seri, rozet). The test "every new word is plain" runs it over every Aion line in both languages.
- The test "no Aion line claims that data is kept or stays" in the same file.
- `interpretive` and `judged` in [f004_labs_test.dart](../../human_health_os/test/widget/f004_labs_test.dart): words that would interpret or grade a lab value.

A new line is added only together with these tests passing (a code change, outside this folder).
