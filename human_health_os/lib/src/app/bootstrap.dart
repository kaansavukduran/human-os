/// Opens storage and the SELF profile. An unreadable vault is never
/// overwritten: the app falls back to memory and says so. Staging,
/// production and portable builds start at the vault gate (F006): nothing
/// is saved until the encrypted vault is created or unlocked.
library;

import 'package:flutter/foundation.dart';

import '../application/heartbeat_service.dart';
import '../config/app_config.dart';
import '../core/capabilities.dart';
import '../core/ids.dart' show Clock, SystemClock;
import '../core/redact.dart' show errorCode;
import '../data/backup/backup_bundle.dart';
import '../data/backup/data_files.dart';
import '../data/backup/dev_import.dart';
import '../data/local/encrypted_vault.dart';
import '../data/local/log_repository.dart';
import '../data/local/sealed_preferences.dart';
import '../data/local/storage.dart';
import '../data/local/vault_envelope.dart';
import '../domain/ports/health_repository.dart';
import '../features/genetics/genome_file_picker.dart';
import '../features/today/backup_file_picker.dart' show BackupFilePicker;
import '../features/today/save_copy.dart' show SaveCopy;
import 'app_services.dart';
import 'page_reload.dart';

/// What `main()` shows first: the app, or the vault gate.
class AppStartup {
  const AppStartup.ready(AppServices this.services) : gate = null;
  const AppStartup.gate(VaultGate this.gate) : services = null;

  final AppServices? services;
  final VaultGate? gate;
}

/// Everything the vault gate needs (F006).
class VaultGate {
  const VaultGate({
    required this.vault,
    required this.inspection,
    required this.open,
    required this.memoryOnly,
  });

  final EncryptedVault vault;

  /// What was stored when the app started (read only).
  final VaultInspection inspection;

  /// Builds the app around an opened vault.
  final Future<AppServices> Function(OpenedVault opened) open;

  /// Builds the app on a memory store: the user declined to open the vault
  /// ([StorageReason.sessionOnly]) or it is unreadable.
  final Future<AppServices> Function(StorageReason reason, {String? detail})
  memoryOnly;

  /// The same gate for a vault that is now [next] (after the app lock, the
  /// vault exists and is locked: G-36). A new object, so the gate screen
  /// starts afresh.
  VaultGate withInspection(VaultInspection next) => VaultGate(
    vault: vault,
    inspection: next,
    open: open,
    memoryOnly: memoryOnly,
  );
}

/// [env] and [executablePath] stand in for the process environment and the
/// binary's location (tests); the app passes neither.
Future<AppStartup> startApp(
  AppConfig config,
  HostPlatform platform, {
  Map<String, String>? env,
  String? executablePath,
}) async {
  final choice = await createPlatformRepository(
    config,
    env: env,
    executablePath: executablePath,
  );
  final vault = choice.vault;
  if (vault == null) {
    return AppStartup.ready(await _openChoice(config, platform, choice));
  }
  final inspection = await vault.inspect();
  return AppStartup.gate(
    VaultGate(
      vault: vault,
      inspection: inspection,
      open: (opened) => servicesFor(
        config,
        platform,
        opened.repository,
        reason: opened.report.readOnly
            ? StorageReason.vaultReadOnly
            : StorageReason.saving,
        notes: choice.notes,
        report: opened.report,
        files: opened.files,
        derive: choice.derive,
        preferences: opened.preferences,
      ),
      memoryOnly: (reason, {detail}) async {
        final repo = inMemoryRepository();
        await repo.open();
        return servicesFor(
          config,
          platform,
          repo,
          reason: reason,
          detail: detail,
          notes: choice.notes,
          derive: choice.derive,
        );
      },
    ),
  );
}

/// Opens storage without a gate (development builds, memory stores). Builds
/// that keep an encrypted vault must start with [startApp]: they never fall
/// back to an unexplained memory store.
Future<AppServices> bootstrap(
  AppConfig config,
  HostPlatform platform, {
  Map<String, String>? env,
  String? executablePath,
}) async {
  final choice = await createPlatformRepository(
    config,
    env: env,
    executablePath: executablePath,
  );
  if (choice.vault != null) {
    throw StateError('This build starts at the vault gate (startApp)');
  }
  return _openChoice(config, platform, choice);
}

Future<AppServices> _openChoice(
  AppConfig config,
  HostPlatform platform,
  StorageChoice choice,
) async {
  HealthRepository repo = choice.repository;
  var reason = choice.reason;
  var detail = choice.detail;
  var report = const LoadReport(warnings: []);
  try {
    report = await repo.open();
    if (report.readOnly) reason = StorageReason.vaultReadOnly;
  } catch (e) {
    // Do not touch the unreadable vault; keep working in memory and explain.
    repo = inMemoryRepository();
    await repo.open();
    reason = StorageReason.vaultUnreadable;
    detail = errorCode(e) ?? e.runtimeType.toString();
  }
  if (!repo.writable && (await repo.profiles()).isEmpty) {
    // A read-only vault without a SELF profile has nothing to show and
    // cannot create one; keep its file untouched and work in memory.
    repo = inMemoryRepository();
    await repo.open();
  }
  return servicesFor(
    config,
    platform,
    repo,
    reason: reason,
    detail: detail,
    notes: choice.notes,
    report: report,
    files: choice.files,
    derive: choice.derive,
  );
}

/// Shared by [bootstrap], the vault gate and tests: builds services around
/// an opened repository.
Future<AppServices> servicesFor(
  AppConfig config,
  HostPlatform platform,
  HealthRepository repo, {
  StorageReason? reason,
  String? detail,
  List<StorageNote> notes = const [],
  LoadReport report = const LoadReport(warnings: []),
  DataFiles? files,
  GenomeFilePicker? genomePicker,
  SaveCopy? saveCopy,
  BackupFilePicker? backupPicker,
  void Function()? reloadPage = pageReload,
  KeyDeriver derive = deriveInline,
  SealedAppearanceStore? preferences,
  Clock clock = const SystemClock(),
}) async {
  final heartbeat = HeartbeatService(repo, clock: clock);
  final self = await heartbeat.ensureSelfProfile();
  final makeBackup =
      repo is LogRepository &&
          repo.description.durability != StorageDurability.memoryOnly
      ? _backupMaker(repo, config)
      : null;
  final checkpointSaved = ValueNotifier<String?>(null);
  final recordsAppended = ValueNotifier<int>(0);
  if (repo is LogRepository) {
    repo.afterRecordAppended = () => recordsAppended.value++;
  }
  if (repo is LogRepository &&
      makeBackup != null &&
      files != null &&
      files.canRestore) {
    // Before the first record of a newer schema, keep a backup of the store
    // as it is: older apps refuse it from then on (D-018). Browser builds
    // cannot save a file unasked, so they keep none (G-47).
    repo.beforeSchemaUpgrade = () async {
      final now = heartbeat.clock.nowUtc();
      // A checkpoint never replaces another backup: the name carries the
      // time to the second, so a second checkpoint in the same second moves
      // on until its name is free.
      final taken = {for (final b in await files.backups()) b.name};
      var stamp = now;
      while (taken.contains(backupFileName(repo.description.vaultId, stamp))) {
        stamp = stamp.add(const Duration(seconds: 1));
      }
      final where = await files.save(
        DataFileKind.backup,
        backupFileName(repo.description.vaultId, stamp),
        await makeBackup(now),
      );
      checkpointSaved.value = where;
    };
  }
  // Session-only builds (G-32): a restored backup replaces this tab's
  // memory store; the session reopens on it at once (a restart would lose
  // it). The old repository is locked by the restore itself.
  final replacedBy = ValueNotifier<AppServices?>(null);
  Future<void> Function()? reopen;
  if (files is SessionDataFiles) {
    reopen = () async {
      final next = LogRepository(
        sink: files.sink,
        durability: StorageDurability.memoryOnly,
        location: repo.description.location,
        clock: clock,
      );
      final nextReport = await next.open();
      replacedBy.value = await servicesFor(
        config,
        platform,
        next,
        reason: reason,
        detail: detail,
        notes: notes,
        report: nextReport,
        files: files,
        genomePicker: genomePicker,
        saveCopy: saveCopy,
        backupPicker: backupPicker,
        reloadPage: reloadPage,
        derive: derive,
        preferences: preferences,
        clock: clock,
      );
    };
  }
  // Tests that hand in a repository without a reason get "not reported"
  // (null) for a memory store, never an invented cause.
  final status =
      reason ??
      (repo.description.durability == StorageDurability.memoryOnly
          ? null
          : StorageReason.saving);
  return AppServices(
    config: config,
    registry: CapabilityRegistry.forPlatform(
      platform,
      storage: repo.description,
      reason: status,
    ),
    heartbeat: heartbeat,
    self: self,
    storage: repo.description,
    storageReason: status,
    storageDetail: detail,
    storageNotes: notes,
    loadWarnings: report.warnings,
    // Files stay available when the vault could not be opened: restoring a
    // backup is the way back. A backup copies the persisted store, so a
    // memory store offers none.
    dataFiles: files,
    makeBackup: makeBackup,
    lockStorage: repo is LogRepository ? repo.lock : null,
    restartRequired: ValueNotifier<bool>(false),
    checkpointSaved: checkpointSaved,
    recordsAppended: recordsAppended,
    genomePicker: genomePicker,
    saveCopy: saveCopy,
    vaultPreferences: preferences,
    deriveKey: derive,
    backupPicker: backupPicker,
    reopenAfterRestore: reopen,
    replacedBy: replacedBy,
    reloadPage: reloadPage,
    closeVault: closeVaultOf(repo),
    stageDevelopmentImport: _importStager(repo, files, config),
  );
}

/// How records of a development build enter [repo] (F005-S3, D-050): only
/// an encrypted vault whose file the adapter can replace through the
/// staged restore steps (desktop and phones). Null elsewhere.
Future<StagedRestore> Function(StagedImport, DateTime)? _importStager(
  HealthRepository repo,
  DataFiles? files,
  AppConfig config,
) {
  if (repo is! LogRepository || files == null) return null;
  final sink = repo.sink;
  if (sink is! EncryptedLogSink ||
      !files.canRestore ||
      files.restoresChosenFile ||
      !files.holdsEncryptedVault) {
    return null;
  }
  return (source, now) => stageImportIntoVault(
    source,
    sink,
    now: now,
    appVersion: config.version,
    sourceRevision: config.sourceRevision,
  );
}

/// How the app lock closes [repo] (G-36, D-046); null unless it is an
/// encrypted vault, the only store with a key to drop.
Future<void> Function()? closeVaultOf(HealthRepository repo) {
  if (repo is! LogRepository) return null;
  final sink = repo.sink;
  if (sink is! EncryptedLogSink) return null;
  return () async {
    await repo.close();
    sink.close();
  };
}

/// A backup of exactly what is stored: the plaintext development log, or
/// the encrypted envelope (never decrypted into the bundle).
Future<String> Function(DateTime now) _backupMaker(
  LogRepository repo,
  AppConfig config,
) {
  final sink = repo.sink;
  if (sink is EncryptedLogSink) {
    return (now) async {
      final both = await sink.readBoth();
      return createEncryptedBackupBundle(
        envelopeText: both.raw,
        innerLogText: both.opened.inner,
        appVersion: config.version,
        sourceRevision: config.sourceRevision,
        createdAt: now,
      );
    };
  }
  return (now) async => createBackupBundle(
    vaultLogText: await sink.read() ?? '',
    appVersion: config.version,
    sourceRevision: config.sourceRevision,
    createdAt: now,
  );
}
