// F005-S3 review finding (D-050): phone choosers copy a chosen file,
// unencrypted, into the app's own cache or temporary folder. The copy is
// dropped once the file was read, refused or failed to read; only a path
// inside that app-owned folder is ever deleted, never the person's file.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/data/backup/backup_bundle.dart';
import 'package:human_health_os/src/data/local/storage_io.dart';
import 'package:human_health_os/src/features/today/backup_file_chooser.dart';
import 'package:human_health_os/src/features/today/backup_file_picker.dart';

class _File implements ChosenFile {
  _File(this.bytes, {this.declaredSize, this.fail = false});

  final List<int> bytes;
  final int? declaredSize;
  final bool fail;

  @override
  String get name => 'human-os-backup-dev.hhosbackup.json';

  @override
  Future<int?> size() async => declaredSize;

  @override
  Future<List<int>> read() async {
    if (fail) throw const FileSystemException('gone');
    return bytes;
  }
}

void main() {
  group('the chooser copy is released after every outcome', () {
    late List<ChosenFile> released;
    SystemBackupFilePicker pickerFor(
      ChosenFile? f, {
      bool cleanerFails = false,
    }) => SystemBackupFilePicker(
      choose: (_) async => f,
      release: (file) async {
        released.add(file);
        if (cleanerFails) throw const FileSystemException('busy');
      },
    );

    setUp(() => released = []);

    test('on success', () async {
      final f = _File(utf8.encode('{"a":1}'));
      final picked = await pickerFor(f).pick(title: 't');
      expect(picked!.text, '{"a":1}');
      expect(released, [f]);
    });

    test('on a refusal from its size (nothing read)', () async {
      final f = _File(const [], declaredSize: maxBackupFileBytes + 1);
      await expectLater(
        pickerFor(f).pick(title: 't'),
        throwsA(
          isA<BackupError>().having((e) => e.code, 'c', 'BACKUP_TOO_LARGE'),
        ),
      );
      expect(released, [f]);
    });

    test('on a file that is not text', () async {
      final f = _File(const [0xC1, 0x80]);
      await expectLater(
        pickerFor(f).pick(title: 't'),
        throwsA(
          isA<BackupError>().having((e) => e.code, 'c', 'BACKUP_UNREADABLE'),
        ),
      );
      expect(released, [f]);
    });

    test('on a read that throws', () async {
      final f = _File(const [], fail: true);
      await expectLater(
        pickerFor(f).pick(title: 't'),
        throwsA(isA<FileSystemException>()),
      );
      expect(released, [f]);
    });

    test(
      'a clean-up that fails never hides the result or the refusal',
      () async {
        final ok = _File(utf8.encode('{}'));
        expect(
          (await pickerFor(ok, cleanerFails: true).pick(title: 't'))!.text,
          '{}',
        );
        final big = _File(const [], declaredSize: maxBackupFileBytes + 1);
        await expectLater(
          pickerFor(big, cleanerFails: true).pick(title: 't'),
          throwsA(isA<BackupError>()),
        );
        expect(released, [ok, big]);
      },
    );

    test('cancelled: nothing chosen, nothing to release', () async {
      expect(await pickerFor(null).pick(title: 't'), isNull);
      expect(released, isEmpty);
    });
  });

  group('only the app-owned copy folder is ever cleaned', () {
    test('Android: filesDir -> its sibling cache folder', () {
      expect(
        pickerCopyFolder(
          appDataDir: '/data/user/0/org.humanhealthos.human_health_os/files',
          android: true,
          sep: '/',
        ),
        '/data/user/0/org.humanhealthos.human_health_os/cache',
      );
    });

    test('iOS: Library/Application Support -> the container tmp folder', () {
      expect(
        pickerCopyFolder(
          appDataDir: '/var/mobile/Containers/Data/Application/ABC/Library/Application Support/',
          android: false,
          sep: '/',
        ),
        '/var/mobile/Containers/Data/Application/ABC/tmp',
      );
    });

    test(
      'an app folder of another shape gives no folder (nothing deleted)',
      () {
        expect(
          pickerCopyFolder(appDataDir: '/data/x/data', android: true, sep: '/'),
          isNull,
        );
        expect(
          pickerCopyFolder(appDataDir: '/files', android: true, sep: '/'),
          isNull,
        );
        expect(
          pickerCopyFolder(
            appDataDir: '/a/Documents',
            android: false,
            sep: '/',
          ),
          isNull,
        );
      },
    );

    test('a path is inside only when strictly below the folder', () {
      const c = '/data/user/0/pkg/cache';
      expect(isInside('$c/file_picker/42/dev.json', c, '/'), isTrue);
      expect(isInside(c, c, '/'), isFalse);
      expect(isInside('$c/', c, '/'), isFalse);
      expect(isInside('/data/user/0/pkg/cache2/x', c, '/'), isFalse);
      expect(
        isInside('$c/../files/HumanHealthOS/vault.hhosvault', c, '/'),
        isFalse,
      );
      expect(isInside('$c/./x', c, '/'), isFalse);
      expect(
        isInside('/storage/emulated/0/Download/dev.json', c, '/'),
        isFalse,
      );
    });

    test(
      'on desktop the release touches nothing: the person\'s file stays',
      () async {
        final dir = Directory.systemTemp.createTempSync('hhos_release');
        addTearDown(() => dir.deleteSync(recursive: true));
        final mine = File('${dir.path}/dev.hhosbackup.json')
          ..writeAsStringSync('{}');
        var cleared = 0;
        final before = mobileAppDataDir;
        // Even with an app folder that would contain the file, a desktop
        // build calls no clean-up and deletes nothing.
        mobileAppDataDir = '${dir.path}/files';
        addTearDown(() => mobileAppDataDir = before);
        Directory('${dir.path}/cache').createSync();
        final copy = File('${dir.path}/cache/dev.json')
          ..writeAsStringSync('{}');
        await dropChooserCopy(copy.path, clearChooser: () async => cleared++);
        await dropChooserCopy(mine.path, clearChooser: () async => cleared++);
        await releaseChosenFile(_File(const []));
        expect(cleared, 0);
        expect(mine.existsSync(), isTrue);
        expect(copy.existsSync(), isTrue);
      },
    );
  });
}
