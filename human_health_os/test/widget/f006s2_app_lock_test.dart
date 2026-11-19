// F006-S2 (G-36, G-38, D-046): the recovery key is confirmed by typing two
// of its groups back; an optional app lock of an encrypted vault (after
// inactivity, or when the app is hidden) closes the vault, drops the key
// and the decrypted state, keeps every saved record and writes nothing.
import 'dart:math';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/appearance_scope.dart';
import 'package:human_health_os/src/app/bootstrap.dart';
import 'package:human_health_os/src/app/human_os_app.dart';
import 'package:human_health_os/src/core/capabilities.dart';
import 'package:human_health_os/src/data/local/encrypted_vault.dart';
import 'package:human_health_os/src/data/local/log_repository.dart';
import 'package:human_health_os/src/data/local/sealed_preferences.dart';
import 'package:human_health_os/src/data/local/vault_envelope.dart';
import 'package:human_health_os/src/domain/ports/health_repository.dart';
import 'package:human_health_os/src/domain/ports/storage_status.dart';
import 'package:human_health_os/src/domain/settings/appearance.dart';
import 'package:human_health_os/src/features/vault/vault_gate_screen.dart';
import 'package:human_health_os/src/navigation/app_shell.dart'
    show openSettingsOn;

import 'f006_vault_gate_test.dart'
    show
        Disk,
        cheap,
        createThroughGate,
        dev,
        latest,
        pass,
        prod,
        saveWeight,
        settle,
        tapKey,
        textOf,
        type;

/// The vault, its preferences file and what the gate opened.
class LockDisk extends Disk {
  String? prefs;
  final opened = <OpenedVault>[];
}

Future<VaultGate> lockGate(LockDisk disk) async {
  final vault = EncryptedVault(
    raw: disk.raw,
    location: 'test vault',
    newKdf: cheap,
    preferencesFor: (sink) => SealedAppearanceStore(
      sink: sink,
      read: () async => disk.prefs,
      write: (t) async => disk.prefs = t,
    ),
  );
  return VaultGate(
    vault: vault,
    inspection: await vault.inspect(),
    open: (o) {
      disk.opened.add(o);
      return servicesFor(
        prod,
        HostPlatform.linux,
        o.repository,
        reason: StorageReason.saving,
        report: o.report,
        preferences: o.preferences,
      );
    },
    memoryOnly: (reason, {detail}) async {
      final r = inMemoryRepository();
      await r.open();
      return servicesFor(prod, HostPlatform.linux, r, reason: reason);
    },
  );
}

Future<AppearanceController> launchLock(
  WidgetTester tester,
  LockDisk disk, {
  Size size = const Size(1280, 2600),
  double ratio = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
  final c = AppearanceController(MemoryAppearanceStore());
  final g = await tester.runAsync(() => lockGate(disk));
  await tester.pumpWidget(HumanOsApp(gate: g, appearance: c));
  await settle(tester);
  return c;
}

/// Creates the vault and lets the sealed preferences be adopted.
Future<void> createVault(WidgetTester tester) async {
  await createThroughGate(tester);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await settle(tester);
}

Future<void> unlockAgain(WidgetTester tester) async {
  await type(tester, 'gate-passphrase', pass);
  await tapKey(tester, 'gate-unlock');
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await settle(tester);
}

/// Ends the test with no lock timer left running.
Future<void> closeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

/// Goes to the confirmation step; returns the key that was shown.
Future<String> toConfirm(WidgetTester tester) async {
  await type(tester, 'gate-passphrase', pass);
  await type(tester, 'gate-passphrase-confirm', pass);
  await tapKey(tester, 'gate-continue');
  final key = textOf(tester, 'gate-recovery-key');
  await tapKey(tester, 'gate-key-written');
  return key;
}

/// The groups asked for (1-based), read from the instruction on screen
/// (the first two numbers in it); the fields carry the same numbers.
List<int> askedGroups(WidgetTester tester) => [
  for (final m in RegExp(
    r'\d',
  ).allMatches(textOf(tester, 'gate-confirm-body')).take(2))
    int.parse(m[0]!),
];

String? fieldError(WidgetTester tester, int n) => tester
    .widget<TextField>(find.byKey(ValueKey('gate-confirm-group-$n')))
    .decoration!
    .errorText;

/// The Settings page's own list.
Finder settingsScroll() => find
    .descendant(
      of: find.byKey(const ValueKey('screen-settings')),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  group('G-38 recovery key confirmation', () {
    test('groupMatches reads a group like a typed recovery key', () {
      const key = 'ABCD-EFGH-IJKL-MNOP-QRST-UVWX-YZ23-4567';
      expect(groupMatches(key, 1, 'ABCD'), isTrue);
      expect(groupMatches(key, 1, ' ab-cd '), isTrue);
      expect(groupMatches(key, 7, 'yz23'), isTrue);
      expect(groupMatches(key, 3, '1JKL'), isTrue, reason: '1 reads as I');
      expect(groupMatches(key, 4, 'MN0P'), isTrue, reason: '0 reads as O');
      expect(groupMatches(key, 1, 'A8CD'), isTrue, reason: '8 reads as B');
      expect(groupMatches(key, 1, 'EFGH'), isFalse, reason: 'another group');
      expect(groupMatches(key, 1, 'ABC'), isFalse);
      expect(groupMatches(key, 1, ''), isFalse);
      // The whole key pasted from a password manager.
      expect(groupMatches(key, 5, key), isTrue);
      expect(
        groupMatches(key, 5, key.toLowerCase().replaceAll('-', ' ')),
        isTrue,
      );
      expect(groupMatches(key, 5, key.replaceFirst('QRST', 'QRSS')), isFalse);
      expect(groupMatches(key, 0, 'ABCD'), isFalse);
      expect(groupMatches(key, 9, 'ABCD'), isFalse);
    });

    test('pickConfirmGroups: two different groups, ascending, 1 to 8, '
        'every group can be asked', () {
      final seen = <int>{};
      final r = Random(7);
      for (var i = 0; i < 500; i++) {
        final (a, b) = pickConfirmGroups(r);
        expect(a, lessThan(b));
        expect(a, greaterThanOrEqualTo(1));
        expect(b, lessThanOrEqualTo(8));
        seen
          ..add(a)
          ..add(b);
      }
      expect(seen, {1, 2, 3, 4, 5, 6, 7, 8});
    });

    testWidgets('wrong groups: a clear error on the field, nothing written, '
        'no lockout; show the key again (same key, new groups); right groups '
        'create the vault', (tester) async {
      final disk = LockDisk();
      await launchLock(tester, disk);
      final key = await toConfirm(tester);
      final groups = key.split('-');
      expect(
        find.byKey(const ValueKey('gate-recovery-key')),
        findsNothing,
        reason: 'typed from where it was written, not copied off screen',
      );
      var asked = askedGroups(tester);
      expect(asked, hasLength(2));
      expect(
        textOf(tester, 'gate-confirm-body'),
        contains('Type groups ${asked[0]} and ${asked[1]}'),
      );

      // Empty: says which group to type.
      await tapKey(tester, 'gate-create-vault');
      expect(fieldError(tester, asked[0]), 'Type group ${asked[0]}.');
      expect(disk.raw.text, isNull);

      // Wrong three times: never locked out, nothing written.
      final wrong = groups[asked[0] == 1 ? 1 : 0];
      for (var i = 0; i < 3; i++) {
        await type(tester, 'gate-confirm-group-${asked[0]}', wrong);
        await type(
          tester,
          'gate-confirm-group-${asked[1]}',
          groups[asked[1] - 1],
        );
        await tapKey(tester, 'gate-create-vault');
        expect(fieldError(tester, asked[0]), contains('not group ${asked[0]}'));
        expect(fieldError(tester, asked[1]), isNull);
        expect(textOf(tester, 'gate-error'), contains('no limit'));
        expect(disk.raw.text, isNull, reason: 'nothing written');
        expect(
          tester
              .widget<TextField>(
                find.byKey(ValueKey('gate-confirm-group-${asked[0]}')),
              )
              .focusNode!
              .hasFocus,
          isTrue,
          reason: 'the wrong field takes the focus',
        );
      }
      // Typing in the field clears its error.
      await type(tester, 'gate-confirm-group-${asked[0]}', 'X');
      expect(fieldError(tester, asked[0]), isNull);

      // Show the key again: the same key, two new groups asked next.
      await tapKey(tester, 'gate-show-key-again');
      expect(textOf(tester, 'gate-recovery-key'), key);
      await tapKey(tester, 'gate-key-written');
      asked = askedGroups(tester);
      expect(asked, hasLength(2));
      expect(fieldError(tester, asked[0]), isNull, reason: 'a fresh start');

      // The whole key pasted (a password manager) in one field, a group in
      // lower case with a space in the other.
      await type(tester, 'gate-confirm-group-${asked[0]}', key);
      final g2 = groups[asked[1] - 1].toLowerCase();
      await type(
        tester,
        'gate-confirm-group-${asked[1]}',
        '${g2.substring(0, 2)} ${g2.substring(2)}',
      );
      await tapKey(tester, 'gate-create-vault');
      expect(find.byKey(const ValueKey('screen-today')), findsOneWidget);
      expect(detectStoredVault(disk.raw.text), StoredVaultKind.encrypted);
    });

    testWidgets('confirmation speaks Turkish', (tester) async {
      tester.platformDispatcher.localesTestValue = [const Locale('tr')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final disk = LockDisk();
      await launchLock(tester, disk);
      await toConfirm(tester);
      final asked = askedGroups(tester);
      expect(
        textOf(tester, 'gate-confirm-body'),
        startsWith('Anahtarın ${asked[0]}. ve ${asked[1]}. gruplarını'),
      );
      await tapKey(tester, 'gate-create-vault');
      expect(fieldError(tester, asked[0]), '${asked[0]}. grubu yaz.');
      expect(find.text('Anahtarı yeniden göster'), findsOneWidget);
    });
  });

  group('G-36 app lock: the setting', () {
    test('kept additively: older preferences load Off; only offered values '
        'are read', () {
      final old = AppearanceSettings.fromJson({
        'format': 'hhos.appearance',
        'version': 1,
        'language': 'tr',
      });
      expect(old.lockAfterMinutes, 0);
      expect(old.lockWhenHidden, isFalse);
      expect(old.language, LanguageChoice.tr);
      const on = AppearanceSettings(lockAfterMinutes: 15, lockWhenHidden: true);
      final back = AppearanceSettings.fromJson(on.toJson());
      expect(back.lockAfterMinutes, 15);
      expect(back.lockWhenHidden, isTrue);
      expect(back, on);
      expect(on.toJson()['version'], 1, reason: 'same format version');
      for (final odd in [7, -1, '5', 5.0, null, 999]) {
        expect(
          AppearanceSettings.fromJson({'lockAfterMinutes': odd})
              .lockAfterMinutes,
          0,
          reason: '$odd',
        );
      }
      expect(
        on.resetToday().lockAfterMinutes,
        15,
        reason: 'not a Today choice',
      );
    });

    testWidgets('development build: the setting is shown disabled with the '
        'reason, and a saved choice never locks', (tester) async {
      tester.view.physicalSize = const Size(1280, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = LogRepository(
        sink: MemoryLogSink(),
        durability: StorageDurability.localFile,
        location: 'dev log',
      );
      final services = await tester.runAsync(() async {
        await repo.open();
        return servicesFor(dev, HostPlatform.linux, repo);
      });
      expect(services!.closeVault, isNull);
      final c = AppearanceController(
        MemoryAppearanceStore(),
        const AppearanceSettings(lockAfterMinutes: 1, lockWhenHidden: true),
      );
      await tester.pumpWidget(HumanOsApp(services: services, appearance: c));
      await settle(tester);
      await tapKey(tester, 'open-settings');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('set-lock-hidden')),
        300,
        scrollable: settingsScroll(),
      );
      expect(textOf(tester, 'set-lock-reason'), contains('development build'));
      for (final m in AppearanceSettings.lockMinuteChoices) {
        final chip = tester.widget<ChoiceChip>(
          find.byKey(ValueKey('set-lock-$m')),
        );
        expect(chip.onSelected, isNull);
        expect(chip.selected, isFalse);
      }
      final sw = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('set-lock-hidden')),
      );
      expect(sw.onChanged, isNull);
      expect(sw.value, isFalse);
      await tester.pump(const Duration(minutes: 2));
      expect(find.byKey(const ValueKey('app-lock-banner')), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byKey(const ValueKey('screen-settings')), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('memory-only session of an encrypted build: disabled, with '
        'its own reason', (tester) async {
      final disk = LockDisk();
      await launchLock(tester, disk);
      await tapKey(tester, 'gate-memory-only');
      await tapKey(tester, 'open-settings');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('set-lock-reason')),
        300,
        scrollable: settingsScroll(),
      );
      expect(textOf(tester, 'set-lock-reason'), contains('nothing to lock'));
      await closeApp(tester);
    });
  });

  test(
    'closing a vault: a record write in flight finishes first, later '
    'writes are refused with VAULT_LOCKED, the file is not touched',
    () async {
      final raw = MemoryLogSink();
      final vault = EncryptedVault(raw: raw, location: 'v', newKdf: cheap);
      final opened = await vault.create(
        passphrase: pass,
        recoveryKey: 'ABCD-EFGH-IJKL-MNOP-QRST-UVWX-YZ23-4567',
      );
      final services = await servicesFor(
        prod,
        HostPlatform.linux,
        opened.repository,
      );
      final close = services.closeVault!;
      final saving = services.heartbeat.recordWeightKg(
        profileId: services.self.id,
        input: '70,1',
      );
      final closing = close();
      await saving; // saved, not cut short
      await closing;
      final after = raw.text;
      expect(opened.repository.isClosed, isTrue);
      expect(opened.sink.isClosed, isTrue);
      await expectLater(
        services.heartbeat.recordWeightKg(
          profileId: services.self.id,
          input: '70,2',
        ),
        throwsA(
          isA<StorageWriteRefused>().having(
            (e) => e.code,
            'code',
            'VAULT_LOCKED',
          ),
        ),
      );
      expect(raw.text, after, reason: 'nothing written after the lock');
      expect(opened.sink.openPreferences('{}'), isNull);
      // The saved record opens with the passphrase.
      final again = await vault.unlock(pass);
      final records = await again.repository.records(services.self.id);
      expect(records, hasLength(1));
    },
  );

  group('G-36 app lock: locking', () {
    testWidgets('inactivity: activity resets the wait, the banner shows at '
        'T-30 s, the lock closes the repository, drops the key, writes '
        'nothing, discards unsaved text and keeps every saved record', (
      tester,
    ) async {
      final disk = LockDisk();
      final c = await launchLock(tester, disk);
      await createVault(tester);
      await saveWeight(tester, '73,6');
      expect(latest(tester), contains('73.6'));

      // Turned on in Settings (sealed with the vault's other choices).
      await tapKey(tester, 'open-settings');
      final settingsList = settingsScroll();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('set-lock-1')),
        300,
        scrollable: settingsList,
      );
      expect(find.byKey(const ValueKey('set-lock-reason')), findsNothing);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('set-lock-0')))
            .selected,
        isTrue,
        reason: 'Off by default',
      );
      await tester.tap(find.byKey(const ValueKey('set-lock-1')));
      await tester.pump();
      expect(c.value.lockAfterMinutes, 1);
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // A mouse moving over the window counts as use (no click needed).
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(640, 1300));
      await mouse.moveTo(const Offset(650, 1310));

      // 29 s of quiet, then the mouse moves: the wait starts again.
      await tester.pump(const Duration(seconds: 29));
      expect(find.byKey(const ValueKey('app-lock-banner')), findsNothing);
      await mouse.moveTo(const Offset(660, 1320));
      await mouse.removePointer();
      await tester.pump(const Duration(seconds: 29));
      expect(find.byKey(const ValueKey('app-lock-banner')), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('app-lock-banner')), findsOneWidget);
      expect(
        textOf(tester, 'app-lock-banner-text'),
        startsWith('Locking in 30 s'),
      );
      expect(
        textOf(tester, 'app-lock-banner-text'),
        contains('not saved will be cleared'),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(
        textOf(tester, 'app-lock-banner-text'),
        startsWith('Locking in 25 s'),
      );
      // "Stay open" hides it and starts again.
      await tester.tap(find.byKey(const ValueKey('app-lock-stay')));
      await tester.pump();
      expect(find.byKey(const ValueKey('app-lock-banner')), findsNothing);
      await tester.pump(const Duration(seconds: 30));
      expect(find.byKey(const ValueKey('app-lock-banner')), findsOneWidget);
      // A key press counts too.
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(find.byKey(const ValueKey('app-lock-banner')), findsNothing);

      // Unsaved typing and an open page when the lock comes.
      await type(tester, 'weight-input', '99,9');
      await tapKey(tester, 'open-settings');
      expect(find.byKey(const ValueKey('screen-settings')), findsOneWidget);

      final opened = disk.opened.single;
      final vaultBefore = disk.raw.text;
      final prefsBefore = disk.prefs;
      expect(prefsBefore, isNotNull);
      await tester.pump(const Duration(seconds: 30));
      expect(find.byKey(const ValueKey('app-lock-banner')), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const ValueKey('vault-gate-unlock')), findsOneWidget);
      expect(find.byKey(const ValueKey('screen-settings')), findsNothing);
      expect(find.byKey(const ValueKey('app-lock-banner')), findsNothing);
      expect(textOf(tester, 'gate-locked-notice'), contains('locked itself'));
      // The repository and the key are closed; nothing was written.
      expect(opened.repository.isClosed, isTrue);
      expect(opened.repository.writable, isFalse);
      expect(opened.sink.isClosed, isTrue);
      expect(disk.raw.text, vaultBefore, reason: 'vault bytes unchanged');
      expect(disk.prefs, prefsBefore, reason: 'preferences bytes unchanged');
      final self = await tester.runAsync(() => opened.repository.profiles());
      expect(self, isEmpty, reason: 'decrypted state dropped');
      expect(
        () => opened.sink.sealPreferences('{}'),
        throwsA(isA<StorageWriteRefused>()),
      );
      Object? refused;
      await tester.runAsync(() async {
        try {
          await opened.sink.appendLine('{"op":"x"}');
        } catch (e) {
          refused = e;
        }
      });
      expect((refused! as StorageWriteRefused).code, 'VAULT_LOCKED');
      expect(disk.raw.text, vaultBefore);

      // No timer runs at the gate.
      await tester.pump(const Duration(minutes: 3));
      expect(find.byKey(const ValueKey('app-lock-banner')), findsNothing);

      // A wrong passphrase writes nothing; the right one opens it again
      // with the saved record and without the unsaved text.
      await type(tester, 'gate-passphrase', 'not the passphrase');
      await tapKey(tester, 'gate-unlock');
      expect(disk.raw.text, vaultBefore);
      await unlockAgain(tester);
      expect(find.byKey(const ValueKey('screen-today')), findsOneWidget);
      expect(latest(tester), contains('73.6'));
      final input = tester.widget<TextField>(
        find.byKey(const ValueKey('weight-input')),
      );
      expect(input.controller!.text, isEmpty, reason: 'unsaved text cleared');
      expect(c.value.lockAfterMinutes, 1, reason: 'read back after unlock');
      expect(disk.opened, hasLength(2));
      expect(disk.opened.last.sink, isNot(same(opened.sink)));
      await closeApp(tester);
    });

    testWidgets('lock when hidden: only when turned on; locks at once on the '
        'system "hidden" event', (tester) async {
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      final disk = LockDisk();
      final c = await launchLock(tester, disk);
      await createVault(tester);

      Future<void> hideAndShow() async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      await hideAndShow();
      expect(
        find.byKey(const ValueKey('screen-today')),
        findsOneWidget,
        reason: 'off by default',
      );

      await c.update(c.value.copyWith(lockWhenHidden: true));
      await tester.pump();
      final before = disk.raw.text;
      await hideAndShow();
      expect(find.byKey(const ValueKey('vault-gate-unlock')), findsOneWidget);
      expect(disk.opened.single.repository.isClosed, isTrue);
      expect(disk.opened.single.sink.isClosed, isTrue);
      expect(disk.raw.text, before);
      await unlockAgain(tester);
      expect(find.byKey(const ValueKey('screen-today')), findsOneWidget);
      await closeApp(tester);
    });
  });

  group('320 dp at 2x text', () {
    for (final locale in const [Locale('en'), Locale('tr')]) {
      testWidgets('${locale.languageCode}: confirmation, the lock setting and '
          'the banner fit', (tester) async {
        tester.platformDispatcher.localesTestValue = [locale];
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        const phone = Size(640, 1600); // 320 x 800 dp
        final disk = LockDisk();
        await launchLock(tester, disk, size: phone, ratio: 2.0);
        expect(tester.getSize(find.byType(Scaffold).first).width, 320);

        Finder gateList() => find
            .descendant(
              of: find.byType(Scaffold).first,
              matching: find.byType(Scrollable),
            )
            .first;
        Future<Finder> reveal(String key) async {
          final f = find.byKey(ValueKey(key));
          if (f.evaluate().isEmpty) {
            tester.state<ScrollableState>(gateList()).position.jumpTo(0);
            await tester.pump();
            await tester.scrollUntilVisible(f, 120, scrollable: gateList());
          }
          // Twice: a lazy list learns its full length while it scrolls.
          for (var i = 0; i < 2; i++) {
            await tester.ensureVisible(f);
            await tester.pump();
          }
          return f;
        }

        Future<void> gateType(String key, String text) async {
          await tester.enterText(await reveal(key), text);
          await tester.pump();
        }

        Future<void> gateTap(String key) async {
          await tester.tap(await reveal(key));
          await settle(tester);
        }

        await gateType('gate-passphrase', pass);
        await gateType('gate-passphrase-confirm', pass);
        await gateTap('gate-continue');
        final key = tester
            .widget<SelectableText>(await reveal('gate-recovery-key'))
            .data!;
        await gateTap('gate-key-written');
        expect(tester.takeException(), isNull);
        final asked = askedGroups(tester);
        expect(asked, hasLength(2));
        final groups = key.split('-');
        await gateType('gate-confirm-group-${asked[0]}', 'ZZZZ');
        await gateTap('gate-create-vault'); // errors under both fields
        await reveal('gate-confirm-group-${asked[0]}');
        expect(fieldError(tester, asked[0]), isNotNull);
        await reveal('gate-confirm-group-${asked[1]}');
        expect(fieldError(tester, asked[1]), isNotNull);
        expect(tester.takeException(), isNull);
        await gateType('gate-confirm-group-${asked[0]}', groups[asked[0] - 1]);
        await gateType('gate-confirm-group-${asked[1]}', groups[asked[1] - 1]);
        await reveal('gate-show-key-again');
        expect(tester.takeException(), isNull);
        await gateTap('gate-create-vault');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await settle(tester);
        expect(find.byKey(const ValueKey('screen-today')), findsOneWidget);

        // The settings section (opened the way the top bar and the More
        // sheet open it; at this size the top bar may keep it in More).
        openSettingsOn(
          tester.state<NavigatorState>(find.byType(Navigator).first),
          null,
          null,
        );
        await settle(tester);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('set-lock-hidden')),
          400,
          maxScrolls: 200,
          scrollable: settingsScroll(),
        );
        expect(find.byKey(const ValueKey('set-lock-30')), findsOneWidget);
        expect(find.byKey(const ValueKey('set-lock-reason')), findsNothing);
        expect(tester.takeException(), isNull);
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await settle(tester);

        // The banner.
        final c = AppearanceScope.read(
          tester.element(find.byKey(const ValueKey('screen-today'))),
        )!;
        await c.update(c.value.copyWith(lockAfterMinutes: 1));
        await tester.pump();
        await tester.pump(const Duration(seconds: 31));
        expect(find.byKey(const ValueKey('app-lock-banner')), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('app-lock-stay')).hitTestable(),
          findsOneWidget,
        );
        await closeApp(tester);
      });
    }
  });
}
