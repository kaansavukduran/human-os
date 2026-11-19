/// The vault gate (ladder F006): before a staging, production or portable
/// build shows anything, the encrypted vault is created, unlocked or
/// recovered, or the user keeps the session in memory only. Every path is
/// explained without false promises (v0.24 key loss, DR-09).
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/bootstrap.dart';
import '../../core/redact.dart';
import '../../data/crypto/recovery_key.dart';
import '../../data/crypto/vault_crypto.dart' show CryptoFailure;
import '../../data/local/encrypted_vault.dart';
import '../../data/local/vault_envelope.dart' show VaultEnvelopeError;
import '../../data/local/vault_log.dart' show VaultFormatError;
import '../../domain/ports/storage_status.dart';
import '../../l10n/strings.dart';

enum _Mode {
  create,
  recoveryKey,
  confirmKey,
  unlock,
  recover,
  keyLost,
  unreadable,
}

/// Two different groups of a recovery key to type back (G-38), numbered
/// 1 to [recoveryKeyGroups] from the left, in ascending order.
(int, int) pickConfirmGroups(Random random) {
  final a = random.nextInt(recoveryKeyGroups) + 1;
  var b = random.nextInt(recoveryKeyGroups - 1) + 1;
  if (b >= a) b++;
  return a < b ? (a, b) : (b, a);
}

/// A recovery key has eight groups of four characters.
const int recoveryKeyGroups = 8;

/// Whether [typed] is group [n] (1-based) of [key]. Read like a typed
/// recovery key: case, spaces and dashes do not matter, and 0, 1 and 8
/// count as O, I and B. The whole key, pasted from a password manager,
/// counts as well (its group [n] is compared).
bool groupMatches(String key, int n, String typed) {
  final clean = typed
      .toUpperCase()
      .replaceAll(RegExp(r'[\s\-]'), '')
      .replaceAll('0', 'O')
      .replaceAll('1', 'I')
      .replaceAll('8', 'B');
  final groups = key.split('-');
  if (n < 1 || n > groups.length) return false;
  final want = groups[n - 1];
  if (clean.length == want.length) return clean == want;
  return clean == groups.join('');
}

/// What a gate step had already written when opening the app failed.
enum _Wrote { vault, passphrase }

/// Opening the app failed after the step changed the vault file.
class _OpenAfterWriteFailed implements Exception {
  const _OpenAfterWriteFailed(this.cause, this.wrote);

  final Object cause;
  final _Wrote wrote;
}

/// Codes meaning "written by a newer Human OS": the data is fine, this app
/// is too old. Such a vault is explained and never set aside.
const Set<String> newerVaultCodes = {
  'ENVELOPE_NEWER',
  'VAULT_NEWER',
  'RECORD_SCHEMA_NEWER',
};

/// Unreadable states whose file must stay where it is: a newer app's data,
/// or a file that could not be read now (a lock or permissions) and may be
/// perfectly healthy.
const Set<String> keepInPlaceCodes = {...newerVaultCodes, 'VAULT_READ_FAILED'};

class VaultGateScreen extends StatefulWidget {
  const VaultGateScreen({
    super.key,
    required this.gate,
    required this.onReady,
    this.lockedNotice = false,
    this.random,
  });

  final VaultGate gate;

  /// Shown because the app locked itself (G-36): the unlock screen says
  /// that saved records are kept and unsaved typing was cleared.
  final bool lockedNotice;

  /// Picks the recovery key groups to type back; a secure source when null
  /// (tests pass a seeded one).
  final Random? random;

  /// Called once with the app's services (vault opened, or memory only).
  final void Function(AppServices services) onReady;

  @override
  State<VaultGateScreen> createState() => _VaultGateScreenState();
}

class _VaultGateScreenState extends State<VaultGateScreen> {
  late _Mode _mode;
  String? _unreadableCode;
  bool _busy = false;
  String? _error;
  String? _keptAt;
  bool _obscure = true;

  /// Held only between "Continue" and "Create": the recovery key is shown
  /// once, then both are dropped.
  String? _newPassphrase;
  String? _recoveryKey;

  /// The two groups asked for (1-based); new ones at every showing.
  (int, int)? _groups;
  String? _groupError1;
  String? _groupError2;
  late final Random _random = widget.random ?? Random.secure();
  final _group1 = TextEditingController();
  final _group2 = TextEditingController();
  final _group1Focus = FocusNode();
  final _group2Focus = FocusNode();

  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  final _key = TextEditingController();

  /// The passphrase field; it gets the focus back after a wrong try.
  final _passFocus = FocusNode();

  EncryptedVault get _vault => widget.gate.vault;

  @override
  void initState() {
    super.initState();
    final i = widget.gate.inspection;
    _mode = switch (i.access) {
      VaultAccess.create => _Mode.create,
      VaultAccess.unlock => _Mode.unlock,
      VaultAccess.unreadable => _Mode.unreadable,
    };
    _unreadableCode = i.code;
  }

  @override
  void dispose() {
    _pass.dispose();
    _confirm.dispose();
    _key.dispose();
    _passFocus.dispose();
    _group1.dispose();
    _group2.dispose();
    _group1Focus.dispose();
    _group2Focus.dispose();
    super.dispose();
  }

  void _go(_Mode mode) => setState(() {
    _mode = mode;
    _error = null;
    _pass.clear();
    _confirm.clear();
    _key.clear();
    _obscure = true;
    _group1.clear();
    _group2.clear();
    _groupError1 = null;
    _groupError2 = null;
    if (mode == _Mode.recoveryKey) {
      // Every showing asks for two new groups.
      _groups = pickConfirmGroups(_random);
    }
    if (mode != _Mode.recoveryKey && mode != _Mode.confirmKey) {
      _newPassphrase = null;
      _recoveryKey = null;
      _groups = null;
    }
  });

  /// Checks a new passphrase and its repetition; returns the error text.
  String? _checkNew(S s) {
    if (!passphraseLongEnough(_pass.text)) {
      return s.passphraseTooShort(minPassphraseLength);
    }
    if (_pass.text != _confirm.text) return s.passphrasesDiffer;
    return null;
  }

  /// Runs one gate step. [done] and [failed] name the redacted events it
  /// logs (master §37: event, success or failure, error type and code).
  Future<void> _run(
    Future<AppServices> Function() action,
    S s, {
    required String done,
    required String failed,
    String? wrongSecret,
  }) async {
    // One step at a time (Enter in a field while a key is derived).
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final services = await action();
      logEvent(done, fields: {'warnings': services.loadWarnings.length});
      _newPassphrase = null;
      _recoveryKey = null;
      _group1.clear();
      _group2.clear();
      _pass.clear();
      _confirm.clear();
      _key.clear();
      if (mounted) widget.onReady(services);
      return;
    } on _OpenAfterWriteFailed catch (f) {
      // The vault file already changed (created, or a new passphrase
      // stored): never "nothing changed", whatever a re-read would show
      // (review findings).
      logEvent(failed, error: f.cause);
      final code = errorCode(f.cause) ?? f.cause.runtimeType.toString();
      _go(_Mode.unlock);
      _error = f.wrote == _Wrote.vault
          ? s.vaultCreatedNotOpened(code)
          : s.passphraseReplacedNotOpened(code);
    } on CryptoFailure catch (e) {
      logEvent(failed, error: e);
      final wrong = e.code == 'NOT_AUTHENTIC' && wrongSecret != null;
      _error = wrong ? wrongSecret : s.gateFailed(e.code);
      // A wrong passphrase is cleared so the next try starts empty; a wrong
      // recovery key stays, so a typo in it can be fixed.
      if (wrong && _mode == _Mode.unlock) {
        _pass.clear();
        // Some platforms drop the field's focus while the key is derived;
        // give it back so the next try can be typed at once.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _passFocus.requestFocus();
        });
      }
    } on RecoveryKeyFormatError catch (e) {
      logEvent(failed, error: e);
      _error = s.recoveryKeyFormat;
    } on VaultFormatError catch (e) {
      // The key was right but the log inside cannot be used (written by a
      // newer app, or its header is damaged): explain, never overwrite.
      logEvent(failed, error: e);
      _unreadableCode = e.code;
      _mode = _Mode.unreadable;
    } on VaultEnvelopeError catch (e) {
      logEvent(failed, error: e);
      if (e.code == 'VAULT_EXISTS') {
        // Another start created a vault meanwhile: it is never overwritten.
        _go(_Mode.unlock);
      } else {
        _unreadableCode = e.code;
        _mode = _Mode.unreadable;
      }
    } catch (e) {
      logEvent(failed, error: e);
      final code = errorCode(e) ?? e.runtimeType.toString();
      if (failed == 'vault_create_failed' && await _vaultExistsNow()) {
        // The vault was written before the failure: never claim that
        // nothing changed; it opens with the passphrase just chosen
        // (review finding).
        _go(_Mode.unlock);
        _error = s.vaultCreatedNotOpened(code);
      } else {
        _error = s.gateFailed(code);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Opens the app on a vault that [wrote] has just changed.
  Future<AppServices> _openAfterWrite(OpenedVault opened, _Wrote wrote) async {
    try {
      return await widget.gate.open(opened);
    } catch (e) {
      throw _OpenAfterWriteFailed(e, wrote);
    }
  }

  Future<bool> _vaultExistsNow() async {
    try {
      return (await _vault.inspect()).access == VaultAccess.unlock;
    } catch (_) {
      return false;
    }
  }

  void _memoryOnly(S s) {
    final unreadable = _mode == _Mode.unreadable;
    _run(
      () => widget.gate.memoryOnly(
        unreadable ? StorageReason.vaultUnreadable : StorageReason.sessionOnly,
        detail: unreadable
            ? _unreadableCode
            : (widget.gate.inspection.access == VaultAccess.unlock &&
                      _keptAt == null
                  ? 'LOCKED_VAULT_KEPT'
                  : null),
      ),
      s,
      done: 'session_memory_only',
      failed: 'session_memory_only_failed',
    );
  }

  Future<void> _startNew(S s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.startNewTitle),
        content: Text(s.startNewBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton(
            key: const ValueKey('confirm-start-new'),
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(s.startNewVault),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final kept = await _vault.setAside();
      logEvent('vault_set_aside');
      _keptAt = kept;
      _go(_Mode.create);
    } catch (e) {
      logEvent('vault_set_aside_failed', error: e);
      _error = s.gateFailed(errorCode(e) ?? e.runtimeType.toString());
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _field(
    TextEditingController c,
    String label, {
    required String key,
    bool secret = true,
    bool newSecret = false,
    bool toggle = false,
    FocusNode? focusNode,
    VoidCallback? onSubmit,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextField(
      key: ValueKey(key),
      controller: c,
      focusNode: focusNode,
      // Read-only (not disabled) while a key is derived: the field keeps
      // its focus, so after a wrong passphrase the user can type again
      // without clicking back into it.
      readOnly: _busy,
      obscureText: secret && _obscure,
      enableSuggestions: false,
      autocorrect: false,
      keyboardType: secret ? TextInputType.visiblePassword : TextInputType.text,
      textCapitalization: secret
          ? TextCapitalization.none
          : TextCapitalization.characters,
      autofillHints: secret
          ? [newSecret ? AutofillHints.newPassword : AutofillHints.password]
          : null,
      onSubmitted: onSubmit == null ? null : (_) => onSubmit(),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: toggle
            ? IconButton(
                key: ValueKey('$key-show'),
                tooltip: S.of(context).showPassphrase,
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
      ),
    ),
  );

  List<Widget> _create(S s, TextTheme text) {
    void next() {
      final problem = _checkNew(s);
      if (problem != null) {
        setState(() => _error = problem);
        return;
      }
      final pass = _pass.text;
      _go(_Mode.recoveryKey);
      setState(() {
        _newPassphrase = pass;
        _recoveryKey = newRecoveryKey();
      });
    }

    return [
      _title(s.gateCreateTitle, text),
      Text(s.gateCreateBody, style: text.bodyLarge),
      if (_keptAt != null) ...[
        const SizedBox(height: 8),
        Text(
          s.vaultKeptAt(_keptAt!),
          key: const ValueKey('gate-kept-at'),
          style: text.bodyMedium,
        ),
      ],
      _field(
        _pass,
        s.passphrase,
        key: 'gate-passphrase',
        newSecret: true,
        toggle: true,
      ),
      _field(
        _confirm,
        s.passphraseRepeat,
        key: 'gate-passphrase-confirm',
        newSecret: true,
        onSubmit: next,
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          s.passphraseHint(minPassphraseLength),
          style: text.bodySmall,
        ),
      ),
      _errorText(text),
      _primary(s.gateContinue, 'gate-continue', next),
      _secondary(s.gateMemoryOnly, 'gate-memory-only', () => _memoryOnly(s)),
    ];
  }

  List<Widget> _showRecoveryKey(S s, TextTheme text) => [
    _title(s.recoveryKeyTitle, text),
    Text(s.recoveryKeyBody, style: text.bodyLarge),
    const SizedBox(height: 16),
    SelectableText(
      _recoveryKey ?? '',
      key: const ValueKey('gate-recovery-key'),
      style: text.titleMedium?.copyWith(
        fontFamily: 'monospace',
        letterSpacing: 1.2,
      ),
    ),
    _errorText(text),
    _primary(
      s.recoveryKeyWrittenContinue,
      'gate-key-written',
      () => _go(_Mode.confirmKey),
    ),
    _secondary(s.gateBack, 'gate-back', () => _go(_Mode.create)),
  ];

  /// Types back two groups of the key just shown (G-38). A wrong group
  /// says which one and keeps both fields; there is no limit on tries.
  List<Widget> _confirmKey(S s, TextTheme text) {
    final (a, b) = _groups!;
    void create() {
      final key = _recoveryKey!;
      String? check(int n, String typed) => typed.trim().isEmpty
          ? s.confirmGroupEmpty(n)
          : (groupMatches(key, n, typed) ? null : s.confirmGroupWrong(n));
      final e1 = check(a, _group1.text);
      final e2 = check(b, _group2.text);
      if (e1 != null || e2 != null) {
        setState(() {
          _groupError1 = e1;
          _groupError2 = e2;
          _error = s.confirmKeySummary;
        });
        (e1 != null ? _group1Focus : _group2Focus).requestFocus();
        return;
      }
      setState(() {
        _groupError1 = null;
        _groupError2 = null;
      });
      _run(
        () async => _openAfterWrite(
          await _vault.create(passphrase: _newPassphrase!, recoveryKey: key),
          _Wrote.vault,
        ),
        s,
        done: 'vault_created',
        failed: 'vault_create_failed',
      );
    }

    Widget group(
      int n,
      TextEditingController c,
      FocusNode focus,
      String? error,
      void Function() clearError, {
      required bool last,
    }) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        key: ValueKey('gate-confirm-group-$n'),
        controller: c,
        focusNode: focus,
        readOnly: _busy,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.visiblePassword,
        textCapitalization: TextCapitalization.characters,
        textInputAction: last ? TextInputAction.done : TextInputAction.next,
        onChanged: (_) {
          if (error != null) {
            setState(() {
              clearError();
              _error = null;
            });
          }
        },
        onSubmitted: (_) => last ? create() : _group2Focus.requestFocus(),
        decoration: InputDecoration(
          labelText: s.confirmGroupLabel(n),
          helperText: s.confirmGroupHint,
          errorText: error,
          errorMaxLines: 4,
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
        ),
      ),
    );

    return [
      _title(s.confirmKeyTitle, text),
      Text(
        s.confirmKeyBody(a, b),
        key: const ValueKey('gate-confirm-body'),
        style: text.bodyLarge,
      ),
      group(
        a,
        _group1,
        _group1Focus,
        _groupError1,
        () => _groupError1 = null,
        last: false,
      ),
      group(
        b,
        _group2,
        _group2Focus,
        _groupError2,
        () => _groupError2 = null,
        last: true,
      ),
      _errorText(text),
      _primary(s.createVault, 'gate-create-vault', create),
      _secondary(
        s.showKeyAgain,
        'gate-show-key-again',
        () => _go(_Mode.recoveryKey),
      ),
      _secondary(s.gateBack, 'gate-back', () => _go(_Mode.create)),
    ];
  }

  List<Widget> _unlock(S s, TextTheme text) {
    void go() => _run(
      () async => widget.gate.open(await _vault.unlock(_pass.text)),
      s,
      done: 'vault_unlocked',
      failed: 'vault_unlock_failed',
      wrongSecret: s.wrongPassphrase,
    );
    return [
      _title(s.unlockTitle, text),
      if (widget.lockedNotice) ...[
        Text(
          s.appLockedNotice,
          key: const ValueKey('gate-locked-notice'),
          style: text.bodyLarge,
        ),
        const SizedBox(height: 8),
      ],
      Text(s.unlockBody, style: text.bodyLarge),
      _field(
        _pass,
        s.passphrase,
        key: 'gate-passphrase',
        toggle: true,
        focusNode: _passFocus,
        onSubmit: go,
      ),
      _errorText(text),
      _primary(s.unlock, 'gate-unlock', go),
      _secondary(s.useRecoveryKey, 'gate-use-recovery', () {
        _go(_Mode.recover);
      }),
      _secondary(s.gateMemoryOnly, 'gate-memory-only', () => _memoryOnly(s)),
    ];
  }

  List<Widget> _recover(S s, TextTheme text) {
    void go() {
      final problem = _checkNew(s);
      if (problem != null) {
        setState(() => _error = problem);
        return;
      }
      _run(
        () async => _openAfterWrite(
          await _vault.recover(
            recoveryKey: _key.text,
            newPassphrase: _pass.text,
          ),
          _Wrote.passphrase,
        ),
        s,
        done: 'vault_recovered',
        failed: 'vault_recover_failed',
        wrongSecret: s.wrongRecoveryKey,
      );
    }

    return [
      _title(s.recoverTitle, text),
      Text(s.recoverBody, style: text.bodyLarge),
      _field(
        _key,
        s.recoveryKeyLabel,
        key: 'gate-recovery-input',
        secret: false,
      ),
      _field(
        _pass,
        s.newPassphrase,
        key: 'gate-passphrase',
        newSecret: true,
        toggle: true,
      ),
      _field(
        _confirm,
        s.newPassphraseRepeat,
        key: 'gate-passphrase-confirm',
        newSecret: true,
        onSubmit: go,
      ),
      _errorText(text),
      _primary(s.recoverButton, 'gate-recover', go),
      _secondary(s.backToUnlock, 'gate-back', () => _go(_Mode.unlock)),
      _secondary(s.lostBoth, 'gate-lost-both', () => _go(_Mode.keyLost)),
    ];
  }

  List<Widget> _keyLost(S s, TextTheme text) => [
    _title(s.keyLostTitle, text),
    Text(s.keyLostBody, style: text.bodyLarge),
    _errorText(text),
    _secondary(s.backToUnlock, 'gate-back', () => _go(_Mode.unlock)),
    _secondary(s.gateMemoryOnly, 'gate-memory-only', () => _memoryOnly(s)),
    if (_vault.canSetAside)
      _secondary(s.startNewVault, 'gate-start-new', () => _startNew(s)),
  ];

  List<Widget> _unreadable(S s, TextTheme text) {
    final code = _unreadableCode ?? 'ENVELOPE_UNREADABLE';
    return [
      _title(s.unreadableTitle, text),
      Text(
        s.unreadableBody(code),
        key: const ValueKey('gate-unreadable-body'),
        style: text.bodyLarge,
      ),
      _errorText(text),
      _secondary(s.gateMemoryOnly, 'gate-memory-only', () => _memoryOnly(s)),
      // A newer vault is the user's data for a newer app: never set aside.
      if (_vault.canSetAside && !keepInPlaceCodes.contains(code))
        _secondary(s.startNewVault, 'gate-start-new', () => _startNew(s)),
    ];
  }

  Widget _title(String t, TextTheme text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        const Icon(Icons.lock_outline),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(t, style: text.headlineSmall),
          ),
        ),
      ],
    ),
  );

  Widget _errorText(TextTheme text) => _error == null
      ? const SizedBox(height: 12)
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              key: const ValueKey('gate-error'),
              style: text.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        );

  Widget _primary(String label, String key, VoidCallback? onPressed) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: FilledButton(
      key: ValueKey(key),
      onPressed: _busy ? null : onPressed,
      child: Text(label),
    ),
  );

  Widget _secondary(String label, String key, VoidCallback onPressed) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextButton(
          key: ValueKey(key),
          onPressed: _busy ? null : onPressed,
          child: Text(label, textAlign: TextAlign.center),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final children = switch (_mode) {
      _Mode.create => _create(s, text),
      _Mode.recoveryKey => _showRecoveryKey(s, text),
      _Mode.confirmKey => _confirmKey(s, text),
      _Mode.unlock => _unlock(s, text),
      _Mode.recover => _recover(s, text),
      _Mode.keyLost => _keyLost(s, text),
      _Mode.unreadable => _unreadable(s, text),
    };
    return Scaffold(
      key: ValueKey('vault-gate-${_mode.name}'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                ...children,
                if (_busy) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(
                    s.derivingKey,
                    key: const ValueKey('gate-working'),
                    style: text.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
