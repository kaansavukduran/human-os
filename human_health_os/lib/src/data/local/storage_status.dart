/// What the storage adapter decided at startup. Shared by the native and
/// web adapters, so the profile gate exists exactly once (audit ARCH-5).
library;

import '../../config/app_config.dart';
import '../../domain/ports/health_repository.dart';
import '../../domain/ports/storage_status.dart';
import '../backup/data_files.dart';
import 'encrypted_vault.dart';
import 'log_repository.dart';
import 'vault_envelope.dart' show KeyDeriver, deriveInline;

export '../../domain/ports/storage_status.dart';

class StorageChoice {
  const StorageChoice(
    this.repository, {
    this.reason = StorageReason.saving,
    this.detail,
    this.notes = const [],
    this.files,
    this.vault,
    this.derive = deriveInline,
  });

  /// The store to use. While [vault] is set this is only the memory store a
  /// session falls back to when the user declines to open the vault.
  final HealthRepository repository;

  /// Staging, production and portable builds (F006): the encrypted vault
  /// that must be created or unlocked before anything is saved.
  final EncryptedVault? vault;

  /// How keys are derived on this platform (an isolate on native).
  final KeyDeriver derive;

  /// Where development backups and exports go; null when this build may not
  /// write unencrypted files or has no place. Encrypted vaults get theirs
  /// when opened ([OpenedVault.files]).
  final DataFiles? files;
  final StorageReason reason;

  /// Extra context for [reason] (a variable name or an error code).
  final String? detail;
  final List<StorageNote> notes;
}

/// The browser's profile gate: only development builds save there, because
/// encrypted browser storage is not built (gap G-32). Returns null when
/// this build may save. Other builds keep this tab's memory only; a backup
/// the person chooses can still be restored into it (G-29), and it is gone
/// when the tab closes.
StorageChoice? profileGate(AppConfig config) {
  if (config.mayPersistUnencrypted) return null;
  final sink = MemoryLogSink();
  return StorageChoice(
    LogRepository(
      sink: sink,
      durability: StorageDurability.memoryOnly,
      location: 'memory (not saved)',
    ),
    reason: StorageReason.profilePolicy,
    files: SessionDataFiles(sink),
  );
}
