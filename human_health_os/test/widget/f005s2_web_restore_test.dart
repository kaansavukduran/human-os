// F005-S2: data you can take back.
// G-29: in the browser a backup file the person chooses goes through the
// same staged restore gate as on desktop (checksum, schema, the backup's own
// key, a preview, an explicit confirmation), nothing changes on a failure or
// a cancel, and a build that saves nothing says the restored data lives only
// in this tab. G-34 (D-044): an encrypted vault exports only after an
// unencrypted-file warning, a required confirmation and a place the person
// chooses.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/app_services.dart';
import 'package:human_health_os/src/app/bootstrap.dart';
import 'package:human_health_os/src/app/human_os_app.dart';
import 'package:human_health_os/src/config/app_config.dart';
import 'package:human_health_os/src/core/capabilities.dart';
import 'package:human_health_os/src/data/backup/backup_bundle.dart';
import 'package:human_health_os/src/data/backup/data_files.dart';
import 'package:human_health_os/src/data/crypto/vault_crypto.dart';
import 'package:human_health_os/src/data/local/encrypted_vault.dart';
import 'package:human_health_os/src/data/local/log_repository.dart';
import 'package:human_health_os/src/data/local/storage_status.dart';
import 'package:human_health_os/src/data/local/vault_envelope.dart'
    show EncryptedLogSink;
import 'package:human_health_os/src/domain/ports/health_repository.dart'
    show StorageDurability;
import 'package:human_health_os/src/features/today/backup_file_picker.dart';
import 'package:human_health_os/src/features/today/save_copy.dart';

import 'f005_your_data_test.dart'
    show backupMadeElsewhere, dev, message, reveal, settle, staging, tapKey;

const prod = AppConfig(
  profile: BuildProfile.production,
  version: '0.1.0+1',
  sourceRevision: 'test',
);
const pass = 'Mavi-Kedi 7 Ağaç Lamba!';
const oldPass = 'passphrase of the old vault';
const recovery = 'ABCD-EFGH-IJKL-MNOP-QRST-UVWX-YZ23-4567';

KdfParams cheap() =>
    KdfParams(salt: randomBytes(16), memoryKib: 64, iterations: 1);

/// The browser's chooser, without a browser.
class FakePicker implements BackupFilePicker {
  FakePicker([this.text, this.name = 'human-os-backup-test.hhosbackup.json']);

  String? text;
  String name;
  int picks = 0;
  BackupSizeLimit? limit;

  @override
  Future<PickedBackup?> pick({
    required String title,
    BackupSizeLimit limit = BackupSizeLimit.anyBackup,
  }) async {
    picks++;
    this.limit = limit;
    final t = text;
    return t == null ? null : PickedBackup(name: name, text: t);
  }
}

class FakeSaveCopy implements SaveCopy {
  FakeSaveCopy({this.accept = true});

  bool accept;
  final saved = <({String fileName, String text})>[];

  @override
  Future<bool> save({
    required String fileName,
    required String text,
    required String mimeType,
    required String title,
  }) async {
    if (!accept) return false;
    saved.add((fileName: fileName, text: text));
    return true;
  }
}

/// The browser's development adapter: no list, a chosen file, and no
/// encrypted backups (the vault cryptography does not run under dart2js).
MemoryDataFiles browserLike() => MemoryDataFiles(
  restoresChosenFile: true,
  opensEncryptedBackups: false,
  keepsInBrowserStorage: true,
);

/// A chosen file with a size from its metadata; counts reads (R018).
class FakeChosenFile implements ChosenFile {
  FakeChosenFile(this.text, {this.declaredSize});

  final String text;
  final int? declaredSize;
  int reads = 0;

  @override
  String get name => 'human-os-backup-chosen.hhosbackup.json';

  @override
  Future<int?> size() async => declaredSize;

  @override
  Future<List<int>> read() async {
    reads++;
    return utf8.encode(text);
  }
}

/// The development browser adapter's restore steps on [slots] (the real
/// `restoreIntoSlots`), so a full browser storage can be simulated.
class SlotFiles extends MemoryDataFiles {
  SlotFiles(this.slots)
    : super(
        restoresChosenFile: true,
        opensEncryptedBackups: false,
        keepsInBrowserStorage: true,
      );

  final MapSlots slots;

  @override
  Future<RestoreOutcome> restore(
    StagedRestore staged, {
    required DateTime now,
    void Function()? beforeSwitch,
  }) async => restoreIntoSlots(
    slots,
    'v',
    staged,
    now: now,
    beforeSwitch: beforeSwitch,
  );
}

/// A copy of [bundle] whose payload was changed after the checksum.
String tampered(String bundle) {
  final doc = jsonDecode(bundle) as Map<String, Object?>;
  doc['payload'] = (doc['payload']! as String).replaceFirst('77', '78');
  return jsonEncode(doc);
}

/// A well-formed bundle (checksum matches) whose record was written by a
/// newer record schema than this app knows.
String newerSchema(String bundle) {
  final doc = jsonDecode(bundle) as Map<String, Object?>;
  final payload = (doc['payload']! as String).replaceAll(
    RegExp(r'"schema_version":\d+'),
    '"schema_version":999',
  );
  final m = (doc['manifest']! as Map).cast<String, Object?>();
  m['payload_sha256'] = sha256Hex(payload);
  m['payload_bytes'] = utf8.encode(payload).length;
  doc['payload'] = payload;
  doc['manifest'] = m;
  return jsonEncode(doc);
}

void useView(WidgetTester tester, {Size size = const Size(1280, 2600)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// A development session on a stored log with [files] and [picker].
Future<AppServices> startDev(
  WidgetTester tester, {
  required MemoryLogSink sink,
  required DataFiles files,
  BackupFilePicker? picker,
  void Function()? reloadPage,
}) async {
  useView(tester);
  final s = await tester.runAsync(() async {
    final repo = LogRepository(
      sink: sink,
      durability: StorageDurability.browserStorage,
      location: 'test',
    );
    final report = await repo.open();
    return servicesFor(
      dev,
      HostPlatform.web,
      repo,
      report: report,
      files: files,
      backupPicker: picker,
      reloadPage: reloadPage,
    );
  });
  await tester.pumpWidget(HumanOsApp(services: s!));
  await settle(tester);
  return s;
}

/// A web build that saves nothing (G-32), wired as the browser wires it.
Future<(AppServices, SessionDataFiles)> startSession(
  WidgetTester tester, {
  required BackupFilePicker picker,
  Size size = const Size(1280, 2600),
}) async {
  useView(tester, size: size);
  final r = await tester.runAsync(() async {
    final choice = profileGate(staging)!;
    final report = await choice.repository.open();
    final s = await servicesFor(
      staging,
      HostPlatform.web,
      choice.repository,
      reason: choice.reason,
      report: report,
      files: choice.files,
      backupPicker: picker,
    );
    return (s, choice.files! as SessionDataFiles);
  });
  await tester.pumpWidget(HumanOsApp(services: r!.$1));
  await settle(tester);
  return r;
}

/// The live vault of an encrypted session, kept by a "file" adapter that
/// takes a chosen file like the browser does.
class ChosenEncryptedFiles extends MemoryDataFiles {
  ChosenEncryptedFiles(this.raw, EncryptedLogSink sink)
    : super(
        target: RestoreTarget.encrypted(sink.open),
        restoresChosenFile: true,
      );

  final MemoryLogSink raw;

  @override
  String? get vaultText => raw.text;

  @override
  set vaultText(String? v) => raw.text = v;
}

/// An encrypted vault created with [pass] (no records unless [weight]).
Future<(AppServices, MemoryLogSink)> startEncrypted(
  WidgetTester tester, {
  BackupFilePicker? picker,
  SaveCopy? copy,
  String? weight,
  Size size = const Size(1280, 2600),
}) async {
  useView(tester, size: size);
  final raw = MemoryLogSink();
  final s = await tester.runAsync(() async {
    final vault = EncryptedVault(
      raw: raw,
      location: 'test vault',
      newKdf: cheap,
      filesFor: (sink) => ChosenEncryptedFiles(raw, sink),
    );
    final o = await vault.create(passphrase: pass, recoveryKey: recovery);
    final s = await servicesFor(
      prod,
      HostPlatform.linux,
      o.repository,
      reason: StorageReason.saving,
      report: o.report,
      files: o.files,
      backupPicker: picker,
      saveCopy: copy,
    );
    if (weight != null) {
      await s.heartbeat.recordWeightKg(profileId: s.self.id, input: weight);
    }
    return s;
  });
  await tester.pumpWidget(HumanOsApp(services: s!));
  await settle(tester);
  return (s, raw);
}

/// An encrypted backup of another vault (passphrase [oldPass]) holding one
/// weight.
Future<String> encryptedBackup(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final vault = EncryptedVault(
        raw: MemoryLogSink(),
        location: 'old vault',
        newKdf: cheap,
      );
      final o = await vault.create(passphrase: oldPass, recoveryKey: recovery);
      final s = await servicesFor(prod, HostPlatform.linux, o.repository);
      await s.heartbeat.recordWeightKg(profileId: s.self.id, input: '81,5');
      return s.makeBackup!(DateTime.utc(2026, 10, 6));
    }))!;

bool enabled(WidgetTester tester, String key) =>
    tester.widget<ButtonStyleButton>(find.byKey(ValueKey(key))).enabled;

class MapSlots implements TextSlots {
  final map = <String, String>{};
  String? failOn;

  /// Fails every key that starts with this (keys that carry a time).
  String? failOnPrefix;

  @override
  String? get(String key) => map[key];

  @override
  void set(String key, String value) {
    if (failOn != null && key == failOn) throw StateError('quota exceeded');
    if (failOnPrefix != null && key.startsWith(failOnPrefix!)) {
      throw StateError('quota exceeded');
    }
    map[key] = value;
  }

  @override
  void remove(String key) => map.remove(key);
}

void main() {
  group('G-29 restore a chosen backup file (browser development build)', () {
    testWidgets('a valid backup: preview first, nothing changes until '
        'Restore; then the records are in place, the earlier data is kept, '
        'and writes pause until a reload', (tester) async {
      final bundle = await backupMadeElsewhere(tester);
      final files = browserLike();
      final sink = MemoryLogSink();
      final picker = FakePicker(bundle);
      await startDev(tester, sink: sink, files: files, picker: picker);
      expect(find.byKey(const ValueKey('no-backups')), findsNothing);
      expect(find.byKey(const ValueKey('export-json')), findsOneWidget);

      await tapKey(tester, 'restore-from-file');
      expect(picker.picks, 1);
      expect(find.byKey(const ValueKey('restore-preview')), findsOneWidget);
      final preview = tester
          .widget<Text>(find.byKey(const ValueKey('restore-preview-text')))
          .data!;
      expect(preview, contains('human-os-backup-test.hhosbackup.json'));
      expect(preview, contains('It holds 1 records and 1 profiles'));
      expect(preview, contains('by Human OS x'));
      expect(
        find.byKey(const ValueKey('restore-preview-session')),
        findsNothing,
      );
      expect(files.vaultText, isNull, reason: 'nothing before confirmation');

      await tapKey(tester, 'confirm-restore-file');
      expect(
        message(tester),
        'Restored 1 records into this browser. Reload the page to use them.',
      );
      expect(files.vaultText, jsonDecode(bundle)['payload']);
      expect(enabled(tester, 'create-backup'), isFalse);
      expect(enabled(tester, 'restore-from-file'), isFalse);
    });

    testWidgets('a wrong checksum: refused with the reason and a way out; '
        'nothing changed', (tester) async {
      final bundle = await backupMadeElsewhere(tester);
      final files = browserLike()..vaultText = 'live';
      await startDev(
        tester,
        sink: MemoryLogSink(),
        files: files,
        picker: FakePicker(tampered(bundle)),
      );
      await tapKey(tester, 'restore-from-file');
      expect(find.byKey(const ValueKey('restore-preview')), findsNothing);
      expect(
        message(tester),
        'This backup is damaged: its content does not match its checksum. '
        'Nothing was changed.\nYou can choose another file to try again.',
      );
      expect(files.vaultText, 'live');
      expect(enabled(tester, 'restore-from-file'), isTrue);
      expect(enabled(tester, 'create-backup'), isTrue);
    });

    testWidgets('a backup from a newer record schema: "update the app"; '
        'nothing changed', (tester) async {
      final bundle = await backupMadeElsewhere(tester);
      final files = browserLike();
      await startDev(
        tester,
        sink: MemoryLogSink(),
        files: files,
        picker: FakePicker(newerSchema(bundle)),
      );
      await tapKey(tester, 'restore-from-file');
      expect(find.byKey(const ValueKey('restore-preview')), findsNothing);
      expect(
        message(tester),
        startsWith(
          'This backup holds data from a newer Human OS. Update the app to '
          'restore it. Nothing was changed.',
        ),
      );
      expect(files.vaultText, isNull);
    });

    testWidgets('not a backup at all, and a file that cannot be read', (
      tester,
    ) async {
      final files = browserLike();
      final picker = FakePicker('hello');
      await startDev(
        tester,
        sink: MemoryLogSink(),
        files: files,
        picker: picker,
      );
      await tapKey(tester, 'restore-from-file');
      expect(
        message(tester),
        startsWith('This file is not a readable Human OS backup.'),
      );
      expect(files.vaultText, isNull);
    });

    testWidgets('320 dp and 2x text: the answer to the restore entry is '
        'scrolled into view (Q002)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final files = browserLike()..vaultText = 'live';
      await startDev(
        tester,
        sink: MemoryLogSink(),
        files: files,
        picker: FakePicker(),
      );
      tester.view.physicalSize = const Size(320, 640);
      await settle(tester);
      await reveal(tester, 'restore-from-file', 400);
      // As a person scrolls: the entry at the top of the list, the card's
      // status line above it out of sight.
      await tester.ensureVisible(
        find.byKey(const ValueKey('restore-from-file')),
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('restore-from-file')));
      await settle(tester);
      expect(message(tester), 'No file chosen. Nothing was changed.');
      final list = tester.getRect(
        find
            .descendant(
              of: find.byKey(const ValueKey('screen-today')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final shown = tester.getRect(find.byKey(const ValueKey('data-message')));
      // A millionth of a pixel of room for floating-point sums (the one-line
      // banner above the list has a fractional height: U035).
      expect(
        shown.top,
        greaterThanOrEqualTo(list.top - 1e-6),
        reason: '$shown in $list',
      );
      expect(
        shown.bottom,
        lessThanOrEqualTo(list.bottom + 1e-6),
        reason: '$shown in $list',
      );
    });

    testWidgets('cancel at every step changes nothing: no file chosen, '
        'cancel at the preview', (tester) async {
      final bundle = await backupMadeElsewhere(tester);
      final files = browserLike()..vaultText = 'live';
      final picker = FakePicker();
      await startDev(
        tester,
        sink: MemoryLogSink(),
        files: files,
        picker: picker,
      );
      await tapKey(tester, 'restore-from-file');
      expect(message(tester), 'No file chosen. Nothing was changed.');

      picker.text = bundle;
      await tapKey(tester, 'restore-from-file');
      await tapKey(tester, 'cancel-restore-file');
      expect(message(tester), 'Restore cancelled. Nothing was changed.');
      expect(files.vaultText, 'live');
      expect(enabled(tester, 'create-backup'), isTrue);
    });

    testWidgets('a browser that holds records refuses the restore after the '
        'confirmation; nothing changed', (tester) async {
      final bundle = await backupMadeElsewhere(tester);
      final files = browserLike();
      final s = await startDev(
        tester,
        sink: MemoryLogSink(),
        files: files,
        picker: FakePicker(bundle),
      );
      // The live store holds a record (the adapter checks its own slot).
      final live = await tester.runAsync(() async {
        await s.heartbeat.recordWeightKg(profileId: s.self.id, input: '70');
        final sink = (s.heartbeat.repository as LogRepository).sink;
        return sink.read();
      });
      files.vaultText = live;
      await tapKey(tester, 'restore-from-file');
      await tapKey(tester, 'confirm-restore-file');
      expect(message(tester), contains('already holds records'));
      expect(files.vaultText, live);
    });

    testWidgets('an encrypted backup in the browser is refused before any '
        'key is asked for (the vault cryptography does not run there)', (
      tester,
    ) async {
      final enc = await encryptedBackup(tester);
      final files = browserLike();
      await startDev(
        tester,
        sink: MemoryLogSink(),
        files: files,
        picker: FakePicker(enc),
      );
      await tapKey(tester, 'restore-from-file');
      expect(find.byKey(const ValueKey('backup-secret')), findsNothing);
      expect(message(tester), startsWith('This backup is encrypted.'));
      expect(files.vaultText, isNull);
    });
  });

  group('G-29 an encrypted backup through the same chosen-file flow', () {
    testWidgets('wrong passphrase: refused, nothing changed; the right one: '
        'preview, then restored', (tester) async {
      final enc = await encryptedBackup(tester);
      final picker = FakePicker(enc);
      final (_, raw) = await startEncrypted(tester, picker: picker);
      final before = raw.text;

      await tapKey(tester, 'restore-from-file');
      await tester.enterText(
        find.byKey(const ValueKey('backup-secret')),
        'wrong one!',
      );
      await tapKey(tester, 'confirm-open-backup');
      expect(message(tester), contains('does not open the backup'));
      expect(message(tester), contains('choose another file'));
      expect(raw.text, before);

      // Cancel at the key prompt.
      await tapKey(tester, 'restore-from-file');
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(message(tester), 'Restore cancelled. Nothing was changed.');
      expect(raw.text, before);

      await tapKey(tester, 'restore-from-file');
      await tester.enterText(
        find.byKey(const ValueKey('backup-secret')),
        oldPass,
      );
      await tapKey(tester, 'confirm-open-backup');
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('restore-preview-text')))
            .data,
        contains('It holds 1 records'),
      );
      expect(raw.text, before, reason: 'nothing before confirmation');
      await tapKey(tester, 'confirm-restore-file');
      expect(message(tester), startsWith('Restored 1 records. Close and'));
      expect(raw.text, jsonDecode(enc)['payload']);
    });
  });

  group('G-29 / G-32 a web build that saves nothing', () {
    testWidgets('says the restored data lives only in this tab; the session '
        'reopens on the restored records', (tester) async {
      final bundle = await backupMadeElsewhere(tester);
      final (_, files) = await startSession(tester, picker: FakePicker(bundle));
      expect(find.byKey(const ValueKey('data-not-available')), findsOneWidget);
      expect(find.byKey(const ValueKey('create-backup')), findsNothing);
      expect(find.byKey(const ValueKey('export-json')), findsNothing);
      expect(
        find.textContaining(
          'A restored backup stays only in this tab: when you close or '
          'reload it, the records are gone again.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('weight-latest')), findsNothing);

      await tapKey(tester, 'restore-from-file');
      expect(
        find.byKey(const ValueKey('restore-preview-session')),
        findsOneWidget,
      );
      await tapKey(tester, 'confirm-restore-file');
      expect(find.byKey(const ValueKey('restored-in-session')), findsOneWidget);
      expect(
        find.textContaining('Restored 1 records into this tab.'),
        findsOneWidget,
      );
      expect(files.sink.text, jsonDecode(bundle)['payload']);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('weight-latest'))).data,
        '77 kg',
      );
    });

    testWidgets('a failure leaves this tab as it was', (tester) async {
      final bundle = await backupMadeElsewhere(tester);
      final (_, files) = await startSession(
        tester,
        picker: FakePicker(tampered(bundle)),
      );
      final before = files.sink.text;
      await tapKey(tester, 'restore-from-file');
      expect(message(tester), contains('does not match its checksum'));
      expect(files.sink.text, before);
    });

    testWidgets('320 dp at 2x text: the card and the preview fit', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final bundle = await backupMadeElsewhere(tester);
      await startSession(
        tester,
        picker: FakePicker(bundle),
        size: const Size(320, 900),
      );
      await reveal(tester, 'restore-from-file', 300);
      expect(tester.takeException(), isNull);
      await tapKey(tester, 'restore-from-file');
      expect(find.byKey(const ValueKey('restore-preview')), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('confirm-restore-file')),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('G-34 export from an encrypted vault (D-044)', () {
    testWidgets('only after the warning and its confirmation, to a place the '
        'person chooses; cancel writes nothing', (tester) async {
      final copy = FakeSaveCopy();
      await startEncrypted(tester, copy: copy, weight: '80');
      expect(find.byKey(const ValueKey('export-json')), findsNothing);
      await tapKey(tester, 'export-unencrypted');
      expect(
        find.text(
          'This file is not encrypted. Anyone who opens it can read your '
          'health records.',
        ),
        findsOneWidget,
      );
      expect(
        enabled(tester, 'confirm-export'),
        isFalse,
        reason: 'refused without the confirmation',
      );
      await tester.tap(find.byKey(const ValueKey('confirm-export')));
      await settle(tester);
      expect(copy.saved, isEmpty);
      await tapKey(tester, 'cancel-export');
      expect(message(tester), 'Export cancelled. Nothing was written.');
      expect(copy.saved, isEmpty);

      // The save dialog itself cancelled: nothing written either.
      copy.accept = false;
      await tapKey(tester, 'export-unencrypted');
      await tapKey(tester, 'export-understand');
      await tapKey(tester, 'confirm-export');
      expect(message(tester), 'Export cancelled. Nothing was written.');
      expect(copy.saved, isEmpty);

      copy.accept = true;
      await tapKey(tester, 'export-unencrypted');
      await tapKey(tester, 'export-understand');
      expect(enabled(tester, 'confirm-export'), isTrue);
      await tapKey(tester, 'confirm-export');
      expect(copy.saved, hasLength(1));
      expect(copy.saved.single.fileName, startsWith('human-os-export-'));
      expect(copy.saved.single.text, contains('"encryption": "none"'));
      expect(copy.saved.single.text, contains('"record_count": 1'));
      expect(
        message(tester),
        startsWith('Exported 1 records to the place you chose'),
      );
    });

    testWidgets('the warning speaks Turkish', (tester) async {
      tester.platformDispatcher.localesTestValue = [const Locale('tr')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await startEncrypted(tester, copy: FakeSaveCopy());
      await tapKey(tester, 'export-unencrypted');
      expect(
        find.text(
          'Bu dosya şifreli değil. Onu açan herkes sağlık kayıtlarını '
          'okuyabilir.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Bu dosyanın şifreli olmadığını anlıyorum'),
        findsOneWidget,
      );
    });

    testWidgets('320 dp at 2x text: the warning and its buttons fit', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await startEncrypted(
        tester,
        copy: FakeSaveCopy(),
        size: const Size(320, 900),
      );
      await reveal(tester, 'export-unencrypted', 300);
      expect(tester.takeException(), isNull);
      await tapKey(tester, 'export-unencrypted');
      await tester.ensureVisible(find.byKey(const ValueKey('confirm-export')));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('development desktop builds behave as before: a list of '
      'saved backups, a plain export, no file chooser', (tester) async {
    await startDev(tester, sink: MemoryLogSink(), files: MemoryDataFiles());
    expect(find.byKey(const ValueKey('export-json')), findsOneWidget);
    expect(find.byKey(const ValueKey('export-unencrypted')), findsNothing);
    expect(find.byKey(const ValueKey('restore-from-file')), findsNothing);
    expect(find.byKey(const ValueKey('no-backups')), findsOneWidget);
  });

  group('restoreIntoSlots (browser storage steps, G-29)', () {
    Future<StagedRestore> staged(WidgetTester tester) async =>
        stageRestore(await backupMadeElsewhere(tester));

    testWidgets('replaces an empty vault slot and keeps what was there', (
      tester,
    ) async {
      final st = await staged(tester);
      final slots = MapSlots()..map['v'] = 'previous';
      var locked = false;
      final out = await restoreIntoSlots(
        slots,
        'v',
        st,
        now: DateTime.utc(2026, 11, 19, 10),
        beforeSwitch: () => locked = true,
      );
      expect(locked, isTrue);
      expect(slots.map['v'], st.payload);
      expect(slots.map['v.before-restore-20261119T100000Z'], 'previous');
      expect(slots.map.containsKey('v.restoring'), isFalse);
      expect(out.records, 1);
      expect(out.keptPrevious, 'v.before-restore-20261119T100000Z');
    });

    testWidgets('refuses while the slot holds records; nothing changed', (
      tester,
    ) async {
      final st = await staged(tester);
      final slots = MapSlots()..map['v'] = st.payload;
      await expectLater(
        restoreIntoSlots(slots, 'v', st, now: DateTime.utc(2026)),
        throwsA(
          isA<BackupError>().having(
            (e) => e.code,
            'code',
            'RESTORE_TARGET_HAS_RECORDS',
          ),
        ),
      );
      expect(slots.map.keys, ['v']);
    });

    testWidgets('a full browser storage: nothing changed, no switch', (
      tester,
    ) async {
      final st = await staged(tester);
      final slots = MapSlots()
        ..map['v'] = 'previous'
        ..failOn = 'v.restoring';
      var locked = false;
      await expectLater(
        restoreIntoSlots(
          slots,
          'v',
          st,
          now: DateTime.utc(2026),
          beforeSwitch: () => locked = true,
        ),
        throwsStateError,
      );
      expect(locked, isFalse);
      expect(slots.map, {'v': 'previous'});
    });

    testWidgets('the vault slot cannot be written: the previous content '
        'stays in place and is also kept aside', (tester) async {
      final st = await staged(tester);
      final slots = MapSlots()
        ..map['v'] = 'previous'
        ..failOn = 'v';
      await expectLater(
        restoreIntoSlots(slots, 'v', st, now: DateTime.utc(2026)),
        throwsA(
          isA<BackupError>()
              .having((e) => e.code, 'code', 'RESTORE_SWITCH_FAILED')
              .having((e) => e.message, 'message', ''),
        ),
      );
      expect(slots.map['v'], 'previous');
      expect(slots.map['v.before-restore-20260101T000000Z'], 'previous');
    });

    testWidgets('R026: a write that lands while the session stops is never '
        'replaced: nothing is switched, nothing staged is left', (
      tester,
    ) async {
      final st = await staged(tester);
      final slots = MapSlots()..map['v'] = 'previous';
      await expectLater(
        restoreIntoSlots(
          slots,
          'v',
          st,
          now: DateTime.utc(2026),
          beforeSwitch: () async => slots.map['v'] = 'previous+saved',
        ),
        throwsA(
          isA<BackupError>()
              .having((e) => e.code, 'code', 'RESTORE_NOT_SWITCHED')
              .having((e) => e.message, 'message', vaultChangedBeforeSwitch),
        ),
      );
      expect(slots.map, {'v': 'previous+saved'});
    });

    testWidgets('R018: a second restore in the same second never overwrites '
        'the copy kept by the first; its name steps forward', (tester) async {
      final st = await staged(tester);
      final slots = MapSlots()
        ..map['v'] = 'second'
        ..map['v.before-restore-20261119T100000Z'] = 'first'
        ..map['v.before-restore-20261119T100001Z'] = 'also earlier';
      final out = await restoreIntoSlots(
        slots,
        'v',
        st,
        now: DateTime.utc(2026, 11, 19, 10),
      );
      expect(out.keptPrevious, 'v.before-restore-20261119T100002Z');
      expect(slots.map['v.before-restore-20261119T100000Z'], 'first');
      expect(slots.map['v.before-restore-20261119T100001Z'], 'also earlier');
      expect(slots.map['v.before-restore-20261119T100002Z'], 'second');
      expect(slots.map['v'], st.payload);
    });
  });

  group('R018: a chosen file is checked by its size before it is read', () {
    BackupError? refusal(Object? e) => e is BackupError ? e : null;

    test('the browser storage limit: a 5 MB file is refused from its size '
        'alone; nothing is read', () async {
      final f = FakeChosenFile('{}', declaredSize: 5 * 1024 * 1024);
      Object? error;
      try {
        await SystemBackupFilePicker(choose: (_) async => f)
            .pick(title: 't', limit: BackupSizeLimit.browserStorage);
      } catch (e) {
        error = e;
      }
      expect(refusal(error)?.code, 'BACKUP_TOO_LARGE_BROWSER');
      expect(refusal(error)?.message, '${5 * 1024 * 1024}');
      expect(f.reads, 0);
    });

    test('the general limit: a file over 64 MiB is refused unread', () async {
      final f = FakeChosenFile('{}', declaredSize: maxBackupFileBytes + 1);
      Object? error;
      try {
        await SystemBackupFilePicker(choose: (_) async => f).pick(title: 't');
      } catch (e) {
        error = e;
      }
      expect(refusal(error)?.code, 'BACKUP_TOO_LARGE');
      expect(f.reads, 0);
    });

    test('a normal file is read once, whole', () async {
      final f = FakeChosenFile('{"x":"ağaç"}', declaredSize: 15);
      final picked = await SystemBackupFilePicker(choose: (_) async => f)
          .pick(title: 't', limit: BackupSizeLimit.browserStorage);
      expect(picked!.text, '{"x":"ağaç"}');
      expect(picked.name, 'human-os-backup-chosen.hhosbackup.json');
      expect(f.reads, 1);
    });

    test('a size the system does not report is checked after the read', () {
      final big = 'x' * (maxBrowserBackupBytes + 1);
      expect(
        readChosenBackup(FakeChosenFile(big), BackupSizeLimit.browserStorage),
        throwsA(
          isA<BackupError>().having(
            (e) => e.code,
            'code',
            'BACKUP_TOO_LARGE_BROWSER',
          ),
        ),
      );
    });

    test('cancelled: nothing chosen, nothing read', () async {
      expect(
        await SystemBackupFilePicker(choose: (_) async => null)
            .pick(title: 't'),
        isNull,
      );
    });

    testWidgets('a development browser build says why a large file was not '
        'read; another file can be tried', (tester) async {
      final f = FakeChosenFile('{}', declaredSize: 5 * 1024 * 1024 + 300000);
      final files = browserLike()..vaultText = 'live';
      await startDev(
        tester,
        sink: MemoryLogSink(),
        files: files,
        picker: SystemBackupFilePicker(choose: (_) async => f),
      );
      await tapKey(tester, 'restore-from-file');
      expect(
        message(tester),
        'This backup is larger than this browser can keep (5.3 MB; the limit '
        'here is 4 MB), so it was not read. Restore it in the desktop app. '
        'Nothing was changed.\nYou can choose another file to try again.',
      );
      expect(f.reads, 0);
      expect(files.vaultText, 'live');
      expect(enabled(tester, 'restore-from-file'), isTrue);
      expect(find.byKey(const ValueKey('reload-page')), findsNothing);
    });

    testWidgets('the same refusal in Turkish', (tester) async {
      tester.platformDispatcher.localesTestValue = [const Locale('tr')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final f = FakeChosenFile('{}', declaredSize: 5 * 1024 * 1024 + 300000);
      await startDev(
        tester,
        sink: MemoryLogSink(),
        files: browserLike(),
        picker: SystemBackupFilePicker(choose: (_) async => f),
      );
      await tapKey(tester, 'restore-from-file');
      expect(
        message(tester),
        'Bu yedek, bu tarayıcının saklayabileceğinden büyük (5,3 MB; buradaki '
        'sınır 4 MB); bu yüzden okunmadı. Onu masaüstü uygulamasında geri '
        'yükle. Hiçbir şey değişmedi.\nYeniden denemek için başka bir dosya '
        'seçebilirsin.',
      );
      expect(f.reads, 0);
    });

    testWidgets('which limit applies: browser storage for a development '
        'browser build, the general one for a memory-only build', (
      tester,
    ) async {
      final devPicker = FakePicker();
      await startDev(
        tester,
        sink: MemoryLogSink(),
        files: browserLike(),
        picker: devPicker,
      );
      await tapKey(tester, 'restore-from-file');
      expect(devPicker.limit, BackupSizeLimit.browserStorage);

      final session = FakePicker();
      await startSession(tester, picker: session);
      await tapKey(tester, 'restore-from-file');
      expect(session.limit, BackupSizeLimit.anyBackup);
    });
  });

  group('R018: a restore that fails in the browser after writes stopped', () {
    Future<(MapSlots, List<int>)> failAfterLock(
      WidgetTester tester, {
      String? failOn,
    }) async {
      final bundle = await backupMadeElsewhere(tester);
      final slots = MapSlots()..map['v'] = '';
      if (failOn == null) {
        slots.failOnPrefix = 'v.before-restore-';
      } else {
        slots.failOn = failOn;
      }
      final reloads = <int>[];
      await startDev(
        tester,
        sink: MemoryLogSink(),
        files: SlotFiles(slots),
        picker: FakePicker(bundle),
        reloadPage: () => reloads.add(1),
      );
      await tapKey(tester, 'restore-from-file');
      await tapKey(tester, 'confirm-restore-file');
      return (slots, reloads);
    }

    testWidgets('a full storage on the kept copy: browser wording, no other '
        'file offered, a reload button that works', (tester) async {
      final (slots, reloads) = await failAfterLock(tester);
      expect(
        message(tester),
        "The restore could not be finished: this browser's storage refused "
        'the write (it may be full). Nothing was changed in it. Reload the '
        'page to go on; saving is paused until then.',
      );
      expect(message(tester), isNot(contains('another file')));
      expect(message(tester), isNot(contains('Human OS restarts')));
      expect(slots.map, {'v': ''});
      expect(enabled(tester, 'restore-from-file'), isFalse);
      expect(enabled(tester, 'create-backup'), isFalse);
      expect(enabled(tester, 'reload-page'), isTrue);
      expect(find.text('Reload the page'), findsOneWidget);
      await tapKey(tester, 'reload-page');
      expect(reloads, [1]);
    });

    testWidgets('the same in Turkish', (tester) async {
      tester.platformDispatcher.localesTestValue = [const Locale('tr')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await failAfterLock(tester);
      expect(
        message(tester),
        'Geri yükleme tamamlanamadı: bu tarayıcının deposu yazmayı reddetti '
        '(dolu olabilir). Depoda hiçbir şey değişmedi. Devam etmek için '
        'sayfayı yenile; o zamana kadar kaydetme duraklatıldı.',
      );
      expect(message(tester), isNot(contains('başka bir dosya')));
      expect(find.text('Sayfayı yenile'), findsOneWidget);
      expect(enabled(tester, 'reload-page'), isTrue);
    });

    testWidgets('the vault slot refuses the restored copy: the previous '
        'data is back in place, a reload is the way on', (tester) async {
      final (slots, _) = await failAfterLock(tester, failOn: 'v');
      final kept = slots.map.keys.singleWhere(
        (k) => k.startsWith('v.before-restore-'),
      );
      expect(slots.map['v'], '');
      expect(slots.map[kept], '');
      expect(
        message(tester),
        "The restore could not be finished: this browser's storage refused "
        'the restored copy (it may be full). The data that was here before '
        'is back in place. Reload the page before saving anything.',
      );
      expect(enabled(tester, 'reload-page'), isTrue);
    });

    testWidgets('a failure before writes stopped still offers another file '
        'and no reload', (tester) async {
      await failAfterLock(tester, failOn: 'v.restoring');
      expect(message(tester), contains('You can choose another file'));
      expect(find.byKey(const ValueKey('reload-page')), findsNothing);
      expect(enabled(tester, 'restore-from-file'), isTrue);
    });
  });
}
