// L001: every visible string has a Turkish version that is not English,
// not empty and carries the same inserted values as the English one;
// Turkish-aware casing; decimal comma in Turkish display.
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/core/capabilities.dart';
import 'package:human_health_os/src/domain/guide/body_guide.dart';
import 'package:human_health_os/src/domain/guide/glossary.dart';
import 'package:human_health_os/src/domain/phyto/phyto_table.dart';
import 'package:human_health_os/src/domain/ports/health_repository.dart';
import 'package:human_health_os/src/domain/ports/storage_status.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';
import 'package:human_health_os/src/domain/units/display_units.dart';
import 'package:human_health_os/src/features/measurements/measurement_format.dart';
import 'package:human_health_os/src/l10n/casing.dart';
import 'package:human_health_os/src/l10n/strings.dart';
import 'package:human_health_os/src/navigation/destinations.dart';

/// One EN/TR pair and where it came from.
typedef Pair = ({String where, String en, String tr});

/// Reads the Dart string literal(s) starting at [i] (adjacent literals are
/// joined); returns the raw text (escapes and `${…}` kept) and the index
/// after it, or null when no literal starts there.
(String, int)? _literal(String s, int i) {
  final out = StringBuffer();
  var found = false;
  while (true) {
    while (i < s.length && ' \n\t\r'.contains(s[i])) {
      i++;
    }
    if (i < s.length && s[i] == 'r' && i + 1 < s.length) {
      if (s[i + 1] == "'" || s[i + 1] == '"') i++;
    }
    if (i >= s.length || (s[i] != "'" && s[i] != '"')) break;
    final q = s[i];
    i++;
    while (s[i] != q) {
      if (s[i] == r'\') {
        out.write(s.substring(i, i + 2));
        i += 2;
        continue;
      }
      if (s.startsWith(r'${', i)) {
        var depth = 0;
        var j = i;
        while (true) {
          if (s[j] == '{') depth++;
          if (s[j] == '}' && --depth == 0) break;
          j++;
        }
        out.write(s.substring(i, j + 1));
        i = j + 1;
        continue;
      }
      out.write(s[i]);
      i++;
    }
    i++;
    found = true;
  }
  return found ? (out.toString(), i) : null;
}

/// Every `_t('en', 'tr')` call in strings.dart whose two arguments are
/// literals, plus the `_capTr` table. Returns the pairs and the number of
/// calls whose arguments are expressions (checked elsewhere or by hand).
(List<Pair>, int) _sourcePairs() {
  final src = File('lib/src/l10n/strings.dart').readAsStringSync();
  final pairs = <Pair>[];
  var skipped = 0;
  for (final m in RegExp(r'\b_t\(').allMatches(src)) {
    final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
    final en = _literal(src, m.end);
    if (en == null) {
      skipped++;
      continue;
    }
    var i = en.$2;
    while (' \n\t\r'.contains(src[i])) {
      i++;
    }
    final tr = src[i] == ',' ? _literal(src, i + 1) : null;
    if (tr == null) {
      skipped++;
      continue;
    }
    pairs.add((where: 'strings.dart:$line', en: en.$1, tr: tr.$1));
  }
  final cap = src.indexOf('_capTr = {');
  final capEnd = src.indexOf('};', cap);
  var i = src.indexOf('{', cap) + 1;
  while (i < capEnd) {
    final k = _literal(src, i);
    if (k == null) break;
    final colon = src.indexOf(':', k.$2);
    final v = _literal(src, colon + 1)!;
    pairs.add((where: '_capTr', en: k.$1, tr: v.$1));
    i = src.indexOf(',', v.$2) + 1;
  }
  return (pairs, skipped);
}

/// Pairs held as data outside strings.dart (navigation, glossary, body
/// guide, plant-chemical dose terms).
List<Pair> _dataPairs() {
  final out = <Pair>[];
  void add(String where, Bilingual? b) {
    if (b != null) out.add((where: where, en: b.$1, tr: b.$2));
  }

  for (final d in [...destinations, ...plannedDestinations]) {
    final w = 'destination ${d.id.name}';
    add(w, (d.en, d.tr));
    add(w, (d.purposeEn, d.purposeTr));
    add(w, (d.principleEn, d.principleTr));
    add(w, (d.canDoEn, d.canDoTr));
    if (d.emptyStateEn != null) add(w, (d.emptyStateEn!, d.emptyStateTr!));
  }
  for (final g in glossary) {
    final w = 'glossary ${g.id}';
    add(w, g.term);
    add(w, g.what);
    add(w, g.unit);
    add(w, g.source);
    for (final h in g.howToMeasure) {
      add(w, h);
    }
  }
  add('glossaryAuthorship', glossaryAuthorship);
  for (final sp in specialties) {
    add('specialty ${sp.id}', sp.name);
    add('specialty ${sp.id}', sp.what);
  }
  for (final b in bodySystems) {
    add('body ${b.id}', b.name);
    add('body ${b.id}', b.what);
    for (final p in b.parts) {
      add('body ${b.id}', p);
    }
  }
  for (final g in guideSources) {
    add('guideSources', g);
  }
  doseTerms.forEach((k, v) => add('doseTerms $k', v));
  return out;
}

/// Turkish text that is the same as the English on purpose: names, units,
/// symbols and words Turkish shares with English.
const _sameAllowed = {
  'Platform',
  'Flutter',
  'Dart',
  'Model',
  'Plan',
  'Protein',
  'Matrix',
  'Trans',
  'kg, cm, °C',
  r'Plan ($state): $schedule ($source)',
  'Kadın 20-49 yaş', // the English hint quotes a Turkish report
};

/// Common English words that never belong in Turkish text.
const _englishWords = {
  'the',
  'and',
  'of',
  'your',
  'you',
  'record',
  'records',
  'save',
  'saved',
  'cancel',
  'settings',
  'error',
  'please',
  'with',
  'for',
  'is',
  'are',
  'this',
  'that',
  'to',
  'in',
  'on',
  'from',
  'entry',
  'entries',
  'value',
  'unknown',
  'null',
  'true',
  'false',
  'none',
  'times',
  'day',
  'days',
  'per',
  'weight',
  'height',
  'blood',
  'pressure',
  'heart',
  'rate',
  'sleep',
  'mood',
  'note',
  'notes',
  'add',
  'delete',
  'edit',
  'open',
  'close',
  'back',
  'next',
  'done',
  'skipped',
  'taken',
  'planned',
  'yes',
  'ok',
  'it',
  'be',
  'or',
  'at',
  'by',
  'was',
  'has',
  'have',
  'will',
  'can',
  'here',
  'there',
  'when',
  'what',
  'which',
  'only',
  'any',
  'more',
  'less',
  'new',
  'old',
  'version',
  'build',
  'backup',
  'restore',
  'vault',
  'passphrase',
  'key',
  'lab',
  'labs',
  'result',
  'results',
};

/// External site labels and names quoted in Turkish instructions, kept in
/// English because the person sees them in English on that site.
const _externalPhrases = [
  'Download these results as: CSV',
  'Send to > File > Format: Summary > Create File',
  'Format: Summary',
  'Format: TSV',
  'dbSNP Summary',
  'Gene Names',
  'Protein names',
  'Function [CC]',
  'Homo sapiens',
  'Reviewed',
  'Download',
  'Likely benign',
  'Benign',
  'Entry',
  'UniProt Consortium',
  'CC BY 4.0',
  '23andMe',
  'mmHg',
  'Human OS',
  'Health Connect',
  'Atkinson Hyperlegible',
  'OpenDyslexic',
  'variant_summary',
  'tab_delimited',
  'FamilyTreeDNA',
  'pub/clinvar',
  'Apple Health',
];

/// The inserted values of [text] with any quoted words inside them
/// emptied, so `${taken ? 'taken' : 'skipped'}` matches its Turkish twin.
List<String> _placeholders(String text) {
  final out = <String>[];
  for (final m in RegExp(
    r'\$\{(?:[^{}]|\{[^{}]*\})*\}|\$[A-Za-z_]\w*',
  ).allMatches(text)) {
    out.add(m[0]!.replaceAll(RegExp(r"'[^']*'"), "''"));
  }
  return out..sort();
}

/// The words a reader sees in [text]: inserted values, quoted literals
/// inside them, URLs and external labels removed; quoted words inside the
/// inserted values are kept (they are shown too).
List<String> _visibleWords(String text) {
  final inner = StringBuffer();
  for (final m in RegExp(r'\$\{(?:[^{}]|\{[^{}]*\})*\}').allMatches(text)) {
    for (final q in RegExp(r"'([^']*)'").allMatches(m[0]!)) {
      inner.write(' ${q[1]}');
    }
  }
  var t = text
      .replaceAll(RegExp(r'\$\{(?:[^{}]|\{[^{}]*\})*\}'), ' ')
      .replaceAll(RegExp(r'\$[A-Za-z_]\w*'), ' ')
      .replaceAll(r'\n', ' ')
      .replaceAll(r"\'", "'");
  t = '$t ${inner.toString().replaceAll(RegExp(r'\$[A-Za-z_]\w*'), ' ')}';
  for (final p in _externalPhrases) {
    t = t.replaceAll(p, ' ');
  }
  t = t.replaceAll(RegExp(r'\S+\.(gov|org|com|txt|gz)\S*'), ' ');
  return [
    for (final w in t.split(RegExp(r'[^A-Za-zÇĞİÖŞÜçğıöşüâîû]+')))
      if (w.isNotEmpty) w,
  ];
}

void main() {
  final (source, skipped) = _sourcePairs();
  final data = _dataPairs();
  final all = [...source, ...data];

  test('the scan sees the string table', () {
    // Guards the scanner itself: a parser change that reads nothing would
    // pass every check below.
    expect(source.length, greaterThan(900));
    expect(skipped, lessThan(10));
    expect(data.length, greaterThan(150));
    // ignore: avoid_print
    print('L001 checked ${all.length} EN/TR pairs ($skipped computed calls)');
  });

  test('no Turkish text is empty', () {
    final empty = [
      for (final p in all)
        if (p.tr.trim().isEmpty && p.en.trim().isNotEmpty) p.where,
    ];
    expect(empty, isEmpty);
  });

  test('Turkish differs from English unless allow-listed', () {
    final same = [
      for (final p in all)
        if (p.tr == p.en &&
            !_sameAllowed.contains(p.tr) &&
            // Symbols, numbers and units only (e.g. "30", "mmHg").
            RegExp(r'[a-zçğıöşü]{3,}').hasMatch(p.tr) &&
            !RegExp(r'^[A-Za-z0-9 /().%+-]{1,12}$').hasMatch(p.tr))
          '${p.where}: ${p.tr}',
    ];
    expect(same, isEmpty);
  });

  test('no common English word in Turkish text', () {
    final hits = <String>[];
    for (final p in all) {
      for (final w in _visibleWords(p.tr)) {
        if (_englishWords.contains(w.toLowerCase())) {
          hits.add('${p.where}: "$w" in ${p.tr}');
        }
      }
    }
    expect(hits, isEmpty);
  });

  test('no raw code, enum name or null in Turkish text', () {
    final hits = [
      for (final p in all)
        for (final w in _visibleWords(p.tr))
          if (RegExp(r'^[A-Z]+_[A-Z_]+$').hasMatch(w) ||
              w == 'null' ||
              RegExp(r'^[a-z]+[A-Z][a-z]+\w*$').hasMatch(w))
            '${p.where}: $w',
    ];
    expect(hits, isEmpty);
  });

  test('English and Turkish insert the same values', () {
    // dateLine picks day and month names from per-language lists; the
    // English day count says "day"/"days", Turkish has no plural.
    const differ = {'dateLine', 'days apart'};
    final hits = [
      for (final p in all)
        if (_placeholders(p.en).join('|') != _placeholders(p.tr).join('|') &&
            !(p.en.contains('enDays') && differ.contains('dateLine')) &&
            !(p.en.contains("days == 1 ? 'day'") &&
                differ.contains('days apart')))
          '${p.where}: ${_placeholders(p.en)} vs ${_placeholders(p.tr)}',
    ];
    expect(hits, isEmpty);
  });

  test('no Turkish plural after a number placeholder', () {
    // "{n} kayıt", never "{n} kayıtlar": Turkish keeps the noun singular
    // after a count.
    final hits = [
      for (final p in all)
        for (final m in RegExp(
          r'\$(?:n|total|shown|records|profiles|lines|found|kept|skipped|all|days|taken)\s+([a-zçğıöşü]+)',
        ).allMatches(p.tr))
          if (RegExp(r'(lar|ler)$').hasMatch(m[1]!)) '${p.where}: ${m[0]}',
    ];
    expect(hits, isEmpty);
  });

  test('every device capability text has a Turkish version', () {
    const tr = S(AppLang.tr);
    const productNames = {'Health Connect', 'Apple Health (HealthKit)'};
    final missing = <String>[];
    final descriptions = <StorageDescription?>[
      null,
      for (final d in StorageDurability.values)
        for (final e in [true, false])
          StorageDescription(
            durability: d,
            encrypted: e,
            location: 'x',
            vaultId: 'v',
          ),
    ];
    for (final platform in HostPlatform.values) {
      for (final reason in [null, ...StorageReason.values]) {
        for (final storage in descriptions) {
          final reg = CapabilityRegistry.forPlatform(
            platform,
            storage: storage,
            reason: reason,
          );
          for (final c in reg.capabilities) {
            for (final text in [c.label, c.detail]) {
              if (text.isEmpty || productNames.contains(text)) continue;
              if (tr.capText(text) == text) missing.add(text);
            }
          }
        }
      }
    }
    expect(missing.toSet(), isEmpty);
  });

  group('Turkish casing', () {
    test('upper case keeps the dotted İ', () {
      expect(upperIn(AppLang.tr, 'işlem'), 'İŞLEM');
      expect(upperIn(AppLang.tr, 'ılık iğne'), 'ILIK İĞNE');
      expect(upperIn(AppLang.en, 'file'), 'FILE');
    });

    test('lower case keeps the dotless ı', () {
      expect(lowerIn(AppLang.tr, 'IŞIK İLAÇ'), 'ışık ilaç');
      expect(lowerIn(AppLang.tr, 'İlaç ya da takviye'), 'ilaç ya da takviye');
      expect(lowerIn(AppLang.en, 'FILE'), 'file');
      // Dart's own mapping is language-neutral: I/i, not I/ı and İ/i.
      expect('IŞIK'.toLowerCase(), isNot('ışık'));
      expect('işlem'.toUpperCase(), isNot('İŞLEM'));
    });

    test('record kinds lowered for "needs:" lines read correctly', () {
      const tr = S(AppLang.tr);
      for (final k in RecordKind.values) {
        final lowered = lowerIn(AppLang.tr, tr.recordKind(k));
        expect(lowered.contains('̇'), isFalse, reason: lowered);
        expect(lowered.contains('I'), isFalse, reason: lowered);
      }
      expect(
        lowerIn(AppLang.tr, tr.recordKind(RecordKind.labResult)),
        'tahlil sonucu',
      );
    });
  });

  group('decimal mark', () {
    test('Turkish shows a decimal comma, English a point', () {
      expect(decimalIn(AppLang.tr, '72.4'), '72,4');
      expect(decimalIn(AppLang.en, '72.4'), '72.4');
      expect(decimalIn(AppLang.tr, '120'), '120');
    });

    test('measured values keep their typed decimals, in the shown mark', () {
      expect(fmtShown(const S(AppLang.tr), 77.5, '77,50'), '77,50');
      expect(fmtShown(const S(AppLang.tr), 72.4, '72.4'), '72,4');
      expect(fmtShown(const S(AppLang.en), 72.4, '72,4'), '72.4');
    });

    test('converted US units follow the language', () {
      const tr = S(AppLang.tr, units: UnitSystem.us);
      const en = S(AppLang.en, units: UnitSystem.us);
      expect(tr.converted(70, 'kg'), ' (≈ 154,3 lb)');
      expect(en.converted(70, 'kg'), ' (≈ 154.3 lb)');
      expect(tr.convertedSpoken(70, 'kg'), ', yaklaşık 154,3 lb');
    });
  });

  test('the Turkish locale picks the Turkish table', () {
    expect(const Locale('tr').languageCode, 'tr');
    expect(const S(AppLang.tr).save, 'Kaydet');
  });
}
