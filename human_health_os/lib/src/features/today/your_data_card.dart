import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../application/export.dart';
import '../../data/backup/backup_bundle.dart';
import '../../data/backup/data_files.dart';
import '../../core/redact.dart' show errorCode;
import '../../data/crypto/recovery_key.dart' show RecoveryKeyFormatError;
import '../../data/local/vault_envelope.dart' show KeyKind;
import '../../l10n/strings.dart';
import '../../presentation/widgets/status_chip.dart';
import '../timeline/timeline_screen.dart' show fmtWhen;
import 'backup_file_picker.dart';
import 'save_copy.dart';

/// Your data (ladder F005, F006): create a backup, export the records, check
/// a saved backup and restore one through the staged restore gate. An
/// encrypted vault's backups stay encrypted; restoring one needs the
/// backup's own passphrase or recovery key. Export from an encrypted vault
/// writes plaintext, so it runs only after a warning, a required
/// confirmation and a place the person chooses (G-34, D-044). In the
/// browser a backup file the person chooses goes through the same gate,
/// with a preview before anything changes (G-29).
class YourDataCard extends StatefulWidget {
  const YourDataCard({super.key, required this.services});

  final AppServices services;

  @override
  State<YourDataCard> createState() => _YourDataCardState();
}

class _YourDataCardState extends State<YourDataCard> {
  List<SavedFile> _backups = const [];
  String? _message;
  bool _messageIsError = false;

  /// The file just saved, when it can be copied out (phones, M002).
  Copyable? _copyable;
  bool _busy = false;

  /// What is running while [_busy] (said in words, announced).
  String? _busyLabel;

  /// Kept in AppServices, not here: leaving and returning to Today must not
  /// re-enable writes after a restore (review finding).
  bool get _restored => _s.restartRequired?.value ?? false;

  AppServices get _s => widget.services;
  DataFiles? get _files => _s.dataFiles;

  @override
  void initState() {
    super.initState();
    _reload();
    // A checkpoint made by a save elsewhere on Today shows up in the list.
    widget.services.checkpointSaved?.addListener(_reload);
  }

  @override
  void dispose() {
    widget.services.checkpointSaved?.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final f = _files;
    if (f == null || !f.canRestore) return;
    final list = await f.backups();
    if (mounted) setState(() => _backups = list);
  }

  Future<void> _run(
    Future<String> Function(S s) action,
    S s, {
    String? busy,
    bool chosenFile = false,
  }) async {
    setState(() {
      _busy = true;
      _busyLabel = busy ?? s.busyWorking;
      _message = null;
      _copyable = null;
    });
    try {
      final msg = await action(s);
      _message = msg;
      _messageIsError = false;
      await _reload();
    } catch (e) {
      _message = _describe(e, s, chosenFile: chosenFile);
      _messageIsError = true;
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyLabel = null;
        });
      }
    }
  }

  /// The reason in words; for a chosen file also the way out. Once a
  /// restore has stopped this session's writes (even one that then failed)
  /// another file cannot be tried: the way out is a reload in the browser
  /// (R018), a restart elsewhere (said by the message itself).
  String _describe(Object e, S s, {bool chosenFile = false}) {
    final inBrowser = _files?.restoresChosenFile ?? false;
    if (e is BackupError && inBrowser) {
      final browser = s.browserRestoreFailed(e.code, e.message);
      if (browser != null) return browser;
    }
    final again = !chosenFile
        ? ''
        : !_restored
        ? '\n${s.tryAnotherFile}'
        : inBrowser
        ? '\n${s.reloadToGoOn}'
        : '';
    return switch (e) {
      BackupError() => s.backupError(e.code, e.message) + again,
      RecoveryKeyFormatError() => s.recoveryKeyFormat,
      // A read, write or rename failed outside the restore gate's checks;
      // nothing was switched (review finding: it used to say "storage").
      _ => s.dataFileFailed(errorCode(e) ?? e.runtimeType.toString()) + again,
    };
  }

  void _say(String? message, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _busyLabel = null;
      _message = message;
      _messageIsError = error;
      _copyable = null;
    });
  }

  void _working(String label) {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _busyLabel = label;
      _message = null;
      _copyable = null;
    });
  }

  void _lockAfterRestore() {
    _s.lockStorage?.call('RESTART_REQUIRED');
    _s.restartRequired?.value = true;
  }

  Future<String> _backup(S s) async {
    final now = DateTime.now().toUtc();
    final bundle = await _s.makeBackup!(now);
    final where = await _files!.save(
      DataFileKind.backup,
      backupFileName(_s.storage.vaultId, now),
      bundle,
    );
    return _saved(s, where, (
      name: backupFileName(_s.storage.vaultId, now),
      text: bundle,
      mime: 'application/json',
    ));
  }

  Future<String> _export(S s) async {
    final now = DateTime.now().toUtc();
    final json = exportRecordsJson(
      profile: _s.self,
      records: await _s.heartbeat.repository.records(_s.self.id),
      exportedAt: now,
      appVersion: _s.config.version,
    );
    final where = await _files!.save(
      DataFileKind.export,
      exportFileName(now),
      json,
    );
    return _saved(s, where, (
      name: exportFileName(now),
      text: json,
      mime: 'application/json',
    ));
  }

  /// On phones the folder is private: say so and offer a copy (M002).
  String _saved(S s, String where, Copyable file) {
    if (saveCopyFor(_s) == null) return s.savedTo(where);
    _copyable = file;
    return _s.storage.encrypted
        ? s.savedInApp
        : '${s.savedInApp} ${s.copyNotEncrypted}';
  }

  Future<void> _saveCopy(S s) async {
    final file = _copyable;
    final copy = saveCopyFor(_s);
    if (file == null || copy == null) return;
    try {
      final ok = await copy.save(
        fileName: file.name,
        text: file.text,
        mimeType: file.mime,
        title: s.saveCopy,
      );
      if (ok && mounted) setState(() => _message = s.copySaved(file.name));
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = s.dataFileFailed(errorCode(e) ?? e.runtimeType.toString());
          _messageIsError = true;
        });
      }
    }
  }

  Future<String> _check(SavedFile f, S s) async {
    final staged = stageRestore(await _files!.read(f));
    final m = staged.manifest;
    return staged.encrypted
        ? s.backupCheckedEncrypted(m.recordCount, fmtWhen(m.createdAt))
        : s.backupChecked(m.recordCount, m.profileCount, fmtWhen(m.createdAt));
  }

  /// Asks for the passphrase (or recovery key) an encrypted backup was made
  /// with. Null when cancelled.
  Future<(String, KeyKind)?> _askBackupKey(S s) =>
      showDialog<(String, KeyKind)>(
        context: context,
        builder: (c) {
          final field = TextEditingController();
          var recovery = false;
          return StatefulBuilder(
            builder: (c, setDialog) => AlertDialog(
              title: Text(s.openBackupTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.openBackupExplain),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('backup-secret'),
                    controller: field,
                    obscureText: !recovery,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: recovery ? s.recoveryKeyLabel : s.passphrase,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  CheckboxListTile(
                    key: const ValueKey('backup-use-recovery'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: recovery,
                    onChanged: (v) => setDialog(() => recovery = v ?? false),
                    title: Text(s.useRecoveryKeyInstead),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(c).pop(),
                  child: Text(s.cancel),
                ),
                FilledButton(
                  key: const ValueKey('confirm-open-backup'),
                  onPressed: () => Navigator.of(c).pop((
                    field.text,
                    recovery ? KeyKind.recovery : KeyKind.passphrase,
                  )),
                  child: Text(s.restoreBackup),
                ),
              ],
            ),
          );
        },
      );

  Future<void> _restore(SavedFile f, S s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.restoreTitle),
        content: Text(s.restoreExplain),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton(
            key: const ValueKey('confirm-restore'),
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(s.restoreBackup),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // Read once: the checks, the key prompt and the restore all use the
    // same bytes.
    final StagedRestore staged;
    try {
      staged = stageRestore(await _files!.read(f));
    } catch (e, st) {
      if (mounted) await _run((s) => Future.error(e, st), s);
      return;
    }
    if (!mounted) return;
    if (staged.encrypted != _files!.holdsEncryptedVault) {
      // Refused before any key is asked for or derived (review finding).
      await _run(
        (s) async => throw const BackupError(
          'BACKUP_KIND_MISMATCH',
          'Not the same kind of vault',
        ),
        s,
      );
      return;
    }
    (String, KeyKind)? key;
    if (staged.needsKey) {
      key = await _askBackupKey(s);
      if (key == null || !mounted) return;
    }
    await _run((s) async {
      var st = staged;
      if (key != null) {
        st = await unlockStagedRestore(
          st,
          key.$1,
          kind: key.$2,
          derive: _s.deriveKey,
        );
      }
      final out = await _files!.restore(
        st,
        now: DateTime.now().toUtc(),
        // From the moment the vault file starts to change, this session's
        // memory no longer matches it: no more writes, even if the switch
        // fails half-way (review finding).
        beforeSwitch: _lockAfterRestore,
      );
      _lockAfterRestore();
      return st.encrypted
          ? s.restoredEncrypted(out.records, out.keptPrevious)
          : s.restored(out.records, out.keptPrevious);
    }, s);
  }

  /// Export from an encrypted vault (G-34, D-044): the plaintext file is
  /// written only after the warning is confirmed, and only where the person
  /// chooses in the system's save dialog; never into a folder of the app's
  /// choosing, never silently.
  Future<void> _exportEncrypted(S s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) {
        var understood = false;
        return StatefulBuilder(
          builder: (c, setDialog) => AlertDialog(
            key: const ValueKey('export-warning'),
            title: Text(s.exportWarningTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.exportWarning,
                    key: const ValueKey('export-warning-text'),
                    style: Theme.of(c).textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(s.exportWhere),
                  CheckboxListTile(
                    key: const ValueKey('export-understand'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: understood,
                    onChanged: (v) => setDialog(() => understood = v ?? false),
                    title: Text(s.exportUnderstand),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                key: const ValueKey('cancel-export'),
                onPressed: () => Navigator.of(c).pop(false),
                child: Text(s.cancel),
              ),
              FilledButton(
                key: const ValueKey('confirm-export'),
                onPressed: understood ? () => Navigator.of(c).pop(true) : null,
                child: Text(s.exportChooseWhere),
              ),
            ],
          ),
        );
      },
    );
    if (ok != true) {
      _say(s.exportCancelled);
      return;
    }
    final copy = _s.saveCopy ?? const SystemSaveCopy();
    await _run((s) async {
      final now = DateTime.now().toUtc();
      final records = await _s.heartbeat.repository.records(_s.self.id);
      final json = exportRecordsJson(
        profile: _s.self,
        records: records,
        exportedAt: now,
        appVersion: _s.config.version,
      );
      final name = exportFileName(now);
      final saved = await copy.save(
        fileName: name,
        text: json,
        mimeType: 'application/json',
        title: s.exportChooseWhere,
      );
      if (!saved) return s.exportCancelled;
      final n = records.where((r) => r.profileId == _s.self.id).length;
      return s.exportedUnencrypted(n, name);
    }, s);
  }

  /// The browser (G-29): a backup file the person chooses goes through the
  /// same gate as a saved one: manifest and checksum, schema compatibility,
  /// the backup's own key when encrypted, a preview, an explicit
  /// confirmation, then the adapter's staged write. Nothing changes before
  /// the confirmation or on any failure.
  Future<void> _restoreChosen(S s) async {
    final files = _files!;
    final picker = _s.backupPicker ?? const SystemBackupFilePicker();
    _working(s.busyReading);
    final PickedBackup? picked;
    StagedRestore staged;
    try {
      picked = await picker.pick(
        title: s.chooseBackupTitle,
        // Checked from the file's size before it is read (R018).
        limit: files.keepsInBrowserStorage
            ? BackupSizeLimit.browserStorage
            : BackupSizeLimit.anyBackup,
      );
      if (picked == null) {
        _say(s.noFileChosen);
        return;
      }
      _working(s.busyChecking);
      staged = stageRestore(picked.text);
      if (staged.encrypted && !files.opensEncryptedBackups) {
        throw const BackupError('BACKUP_ENCRYPTED_BROWSER', '');
      }
      if (staged.encrypted != files.holdsEncryptedVault) {
        // Refused before any key is asked for or derived.
        throw const BackupError('BACKUP_KIND_MISMATCH', '');
      }
    } catch (e) {
      _say(_describe(e, s, chosenFile: true), error: true);
      return;
    }
    if (!mounted) return;
    if (staged.needsKey) {
      _say(null);
      final key = await _askBackupKey(s);
      if (!mounted) return;
      if (key == null) {
        _say(s.restoreCancelled);
        return;
      }
      _working(s.busyChecking);
      try {
        staged = await unlockStagedRestore(
          staged,
          key.$1,
          kind: key.$2,
          derive: _s.deriveKey,
        );
      } catch (e) {
        _say(_describe(e, s, chosenFile: true), error: true);
        return;
      }
    }
    if (!mounted) return;
    _say(null);
    final st = staged;
    final m = st.manifest;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        key: const ValueKey('restore-preview'),
        title: Text(s.restoreTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.restorePreview(
                  picked!.name,
                  st.state!.records.length,
                  st.state!.profiles.length,
                  fmtWhen(m.createdAt),
                  m.sourceAppVersion,
                ),
                key: const ValueKey('restore-preview-text'),
              ),
              const SizedBox(height: 8),
              Text(s.restoreKeepsCurrent),
              if (files.sessionOnly) ...[
                const SizedBox(height: 8),
                Text(
                  s.sessionRestoreNotice,
                  key: const ValueKey('restore-preview-session'),
                  style: Theme.of(c).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('cancel-restore-file'),
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton(
            key: const ValueKey('confirm-restore-file'),
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(s.restoreBackup),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (ok != true) {
      _say(s.restoreCancelled);
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    await _run(
      (s) async {
        final out = await files.restore(
          st,
          now: DateTime.now().toUtc(),
          beforeSwitch: _lockAfterRestore,
        );
        _lockAfterRestore();
        if (files.sessionOnly) {
          // This tab's memory now holds the backup: the session reopens on
          // it at once (a reload would lose it).
          final msg = s.restoredInSession(out.records);
          await _s.reopenAfterRestore?.call();
          messenger?.showSnackBar(
            SnackBar(
              key: const ValueKey('restored-in-session'),
              content: Text(msg),
              duration: const Duration(seconds: 30),
              showCloseIcon: true,
            ),
          );
          return msg;
        }
        if (st.encrypted) {
          return s.restoredEncrypted(out.records, out.keptPrevious);
        }
        return s.restoredInBrowser(out.records, out.keptPrevious);
      },
      s,
      busy: s.busyRestoring,
      chosenFile: true,
    );
  }

  Widget _chosenFileButton(S s) => OutlinedButton.icon(
    key: const ValueKey('restore-from-file'),
    onPressed: _busy || _restored ? null : () => _restoreChosen(s),
    icon: const Icon(Icons.upload_file_outlined),
    label: Text(s.restoreFromFile),
  );

  List<Widget> _status(S s, TextTheme text) => [
    if (_busy && _busyLabel != null) ...[
      const SizedBox(height: 8),
      Semantics(
        liveRegion: true,
        child: Row(
          key: const ValueKey('data-busy'),
          children: [
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(_busyLabel!, style: text.bodyMedium)),
          ],
        ),
      ),
    ],
    if (_restored && _message == null) ...[
      const SizedBox(height: 8),
      Text(
        _files?.restoresChosenFile ?? false
            ? s.restartToUseBrowser
            : s.restartToUse,
        key: const ValueKey('restart-to-use'),
        style: text.bodyMedium,
      ),
    ],
    if (_message != null) ...[
      const SizedBox(height: 8),
      Semantics(
        liveRegion: true,
        child: Text(
          _message!,
          key: const ValueKey('data-message'),
          style: text.bodyMedium?.copyWith(
            color: _messageIsError ? Theme.of(context).colorScheme.error : null,
          ),
        ),
      ),
    ],
    // In the browser, once a restore ran (finished or not), a reload is the
    // only way on: offered as an action, whatever the message says (R018).
    if (_restored &&
        (_files?.restoresChosenFile ?? false) &&
        _s.reloadPage != null) ...[
      const SizedBox(height: 8),
      FilledButton.tonalIcon(
        key: const ValueKey('reload-page'),
        onPressed: _s.reloadPage,
        icon: const Icon(Icons.refresh),
        label: Text(s.reloadPage),
      ),
    ],
    if (_message != null && _copyable != null) ...[
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: const ValueKey('data-save-copy'),
        onPressed: _busy ? null : () => _saveCopy(s),
        icon: const Icon(Icons.save_alt),
        label: Text(s.saveCopy),
      ),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final files = _files;
    final canWrite = files != null && _s.makeBackup != null && !_restored;
    final encrypted = _s.storage.encrypted;
    return Card(
      semanticContainer: false,
      key: const ValueKey('your-data-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(s.yourData, style: text.titleMedium),
            ),
            const SizedBox(height: 8),
            if (files == null)
              Text(
                s.dataNotAvailable,
                key: const ValueKey('data-not-available'),
                style: text.bodyMedium,
              )
            else if (files.sessionOnly) ...[
              // Web builds that save nothing (G-32): no backups or exports,
              // but a chosen backup can be restored into this tab (G-29).
              Text(
                s.dataNotAvailable,
                key: const ValueKey('data-not-available'),
                style: text.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                s.sessionRestoreNotice,
                key: const ValueKey('session-restore-notice'),
                style: text.bodyMedium,
              ),
              const SizedBox(height: 8),
              _chosenFileButton(s),
              ..._status(s, text),
            ] else ...[
              encrypted
                  ? StatusChip(label: s.dataEncrypted, tone: StatusTone.ok)
                  : StatusChip(label: s.dataUnencrypted, tone: StatusTone.info),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    key: const ValueKey('create-backup'),
                    onPressed: _busy || !canWrite
                        ? null
                        : () => _run(_backup, s),
                    icon: const Icon(Icons.backup_outlined),
                    label: Text(s.createBackup),
                  ),
                  if (!encrypted)
                    OutlinedButton.icon(
                      key: const ValueKey('export-json'),
                      onPressed: _busy || !canWrite
                          ? null
                          : () => _run(_export, s),
                      icon: const Icon(Icons.file_download_outlined),
                      label: Text(s.exportJson),
                    )
                  else
                    OutlinedButton.icon(
                      key: const ValueKey('export-unencrypted'),
                      onPressed: _busy || !canWrite
                          ? null
                          : () => _exportEncrypted(s),
                      icon: const Icon(Icons.warning_amber_outlined),
                      label: Text(s.exportUnencrypted),
                    ),
                ],
              ),
              ..._status(s, text),
              const SizedBox(height: 12),
              if (files.restoresChosenFile) ...[
                Text(s.browserRestoreExplain, style: text.bodyMedium),
                const SizedBox(height: 8),
                _chosenFileButton(s),
              ] else if (files.canRestore) ...[
                Semantics(
                  header: true,
                  child: Text(s.backupsTitle, style: text.titleMedium),
                ),
                if (_backups.isEmpty)
                  Text(
                    s.noBackups,
                    key: const ValueKey('no-backups'),
                    style: text.bodyMedium,
                  ),
                for (final b in _backups)
                  Padding(
                    key: ValueKey('backup-${b.name}'),
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(b.name, style: text.bodyMedium),
                        TextButton(
                          key: ValueKey('check-${b.name}'),
                          onPressed: _busy
                              ? null
                              : () => _run((s) => _check(b, s), s),
                          child: Text(s.checkBackup),
                        ),
                        TextButton(
                          key: ValueKey('restore-${b.name}'),
                          onPressed: _busy || _restored
                              ? null
                              : () => _restore(b, s),
                          child: Text(s.restoreBackup),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
