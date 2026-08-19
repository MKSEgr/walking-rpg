import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/auth/auth_models.dart';
import 'package:walking_rpg_mobile/core/auth/auth_session_controller.dart';
import 'package:walking_rpg_mobile/core/auth/oidc_client.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_recovery.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_runtime.dart';
import 'package:walking_rpg_mobile/core/localization/app_locale_scope.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/design_system/expedition_decision_dialog.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/pilot_portrait.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/account/application/account_export_coordinator.dart';
import 'package:walking_rpg_mobile/features/account/data/account_api_client.dart';
import 'package:walking_rpg_mobile/features/account/domain/account_deletion_receipt.dart';
import 'package:walking_rpg_mobile/features/home/data/io_home_transport.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

enum _AccountAction { exporting, deleting, loggingOut }

double _accountTextScale(BuildContext context) {
  return MediaQuery.textScalerOf(context).scale(16) / 16;
}

bool _usesCompactAccountLayout(
  BuildContext context,
  BoxConstraints constraints,
) {
  return constraints.maxWidth < 320 ||
      (constraints.maxWidth < 400 && _accountTextScale(context) > 1.3);
}

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.controller,
    required this.identity,
    required this.apiClient,
    this.exportCoordinator,
    this.idempotencyKeyFactory,
    this.commandRuntime,
    this.onOpenRecovery,
    this.onOpenValidation,
    this.recoveryCount = 0,
    this.recoveryUnavailable = false,
  });

  final AuthSessionController controller;
  final AuthIdentity identity;
  final AccountApiClient apiClient;
  final AccountExportCoordinator? exportCoordinator;
  final String Function()? idempotencyKeyFactory;
  final MobileCommandRuntime? commandRuntime;
  final Future<void> Function()? onOpenRecovery;
  final Future<void> Function()? onOpenValidation;
  final int recoveryCount;
  final bool recoveryUnavailable;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  _AccountAction? _action;
  AccountExportArtifact? _lastExport;
  String? _pendingDeletionKey;
  bool _dismissRequested = false;
  StreamSubscription<void>? _recoverySubscription;
  late int _recoveryCount;
  late bool _recoveryUnavailable;
  int _recoveryLoadGeneration = 0;

  bool get _busy => _action != null;

  @override
  void initState() {
    super.initState();
    _recoveryCount = widget.recoveryCount;
    _recoveryUnavailable = widget.recoveryUnavailable;
    widget.controller.addListener(_handleAuthStateChanged);
    _subscribeRecovery();
  }

  @override
  void didUpdateWidget(AccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.commandRuntime != widget.commandRuntime) {
      unawaited(_recoverySubscription?.cancel());
      _recoverySubscription = null;
      _recoveryCount = widget.recoveryCount;
      _recoveryUnavailable = widget.recoveryUnavailable;
      _subscribeRecovery();
    } else if (widget.commandRuntime == null &&
        (oldWidget.recoveryCount != widget.recoveryCount ||
            oldWidget.recoveryUnavailable != widget.recoveryUnavailable)) {
      _recoveryCount = widget.recoveryCount;
      _recoveryUnavailable = widget.recoveryUnavailable;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleAuthStateChanged);
    unawaited(_recoverySubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final ExpeditionPanelTone recoveryTone = _recoveryUnavailable
        ? ExpeditionPanelTone.neutral
        : _recoveryCount > 0
        ? ExpeditionPanelTone.energy
        : ExpeditionPanelTone.lumen;
    final Color recoveryAccent = _recoveryUnavailable
        ? colors.error
        : _recoveryCount > 0
        ? palette.energy
        : colors.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.accountTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: const <Widget>[AppLocaleMenuButton()],
      ),
      body: ExpeditionBackdrop(
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = _usesCompactAccountLayout(
                context,
                constraints,
              );
              return ListView(
                key: const Key('account-scroll'),
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 20,
                  compact ? 14 : 18,
                  compact ? 12 : 20,
                  32,
                ),
                children: <Widget>[
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _PilotDossier(
                            key: const Key('account-pilot-dossier'),
                            identity: widget.identity,
                            compact: compact,
                          ),
                          const SizedBox(height: 22),
                          ExpeditionSectionTitle(
                            title: context.l10n.accountAccessSectionTitle,
                            subtitle: context.l10n.accountAccessSectionSubtitle,
                            icon: Icons.hub_outlined,
                          ),
                          const SizedBox(height: 12),
                          _AccountLinkPanel(
                            key: const Key('account-command-recovery'),
                            compact: compact,
                            tone: recoveryTone,
                            leading: Badge(
                              backgroundColor: recoveryAccent,
                              textColor: _recoveryUnavailable
                                  ? colors.onError
                                  : _recoveryCount > 0
                                  ? palette.onEnergy
                                  : colors.onPrimary,
                              isLabelVisible:
                                  _recoveryUnavailable || _recoveryCount > 0,
                              label: Text(
                                _recoveryUnavailable
                                    ? '!'
                                    : _recoveryCount > 99
                                    ? '99+'
                                    : '$_recoveryCount',
                              ),
                              child: Icon(
                                Icons.cloud_sync_outlined,
                                color: recoveryAccent,
                              ),
                            ),
                            title: context.l10n.accountSavedActionsTitle,
                            subtitle: _recoveryUnavailable
                                ? context.l10n.accountQueueAttention
                                : _recoveryCount == 0
                                ? context.l10n.accountAllActionsSent
                                : context.l10n.accountPendingReview(
                                    _recoveryCount,
                                  ),
                            onTap: widget.onOpenRecovery == null
                                ? null
                                : () {
                                    unawaited(_openRecoveryAndRefresh());
                                  },
                          ),
                          if (widget.onOpenValidation != null) ...<Widget>[
                            const SizedBox(height: 12),
                            _AccountLinkPanel(
                              key: const Key('account-validation-center'),
                              compact: compact,
                              tone: ExpeditionPanelTone.resonance,
                              leading: Icon(
                                Icons.science_outlined,
                                color: palette.resonance,
                              ),
                              title: 'Validation Center',
                              subtitle: context.l10n.accountValidationSubtitle,
                              onTap: () {
                                unawaited(widget.onOpenValidation!());
                              },
                            ),
                          ],
                          const SizedBox(height: 22),
                          ExpeditionSectionTitle(
                            title: context.l10n.accountPersonalDataTitle,
                            subtitle: context.l10n.accountPersonalDataSubtitle,
                            icon: Icons.folder_shared_outlined,
                          ),
                          const SizedBox(height: 12),
                          ExpeditionPanel(
                            key: const Key('account-export-panel'),
                            padding: EdgeInsets.all(compact ? 16 : 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                ExpeditionSectionTitle(
                                  title: context.l10n.accountExportTitle,
                                  subtitle: context.l10n.accountExportSubtitle,
                                  icon: Icons.ios_share_outlined,
                                ),
                                const SizedBox(height: 14),
                                Text(context.l10n.accountExportDescription),
                                if (_lastExport != null) ...<Widget>[
                                  const SizedBox(height: 10),
                                  Text(
                                    context.l10n.accountLastExport(
                                      _lastExport!.fileName,
                                    ),
                                    key: const Key('account-last-export'),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                                const SizedBox(height: 18),
                                FilledButton.tonal(
                                  key: const Key('account-export-button'),
                                  onPressed: _busy ? null : _export,
                                  child: _AccountActionContent(
                                    icon: _action == _AccountAction.exporting
                                        ? const SizedBox.square(
                                            dimension: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.ios_share),
                                    label: _action == _AccountAction.exporting
                                        ? context.l10n.accountExportPreparing
                                        : context.l10n.accountExportAction,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _AccountDangerPanel(
                            key: const Key('account-danger-zone'),
                            compact: compact,
                            development: widget.identity.isDevelopment,
                            busy: _busy,
                            deleting: _action == _AccountAction.deleting,
                            retrying: _pendingDeletionKey != null,
                            onDelete: _confirmAndDelete,
                          ),
                          if (!widget.identity.isDevelopment) ...<Widget>[
                            const SizedBox(height: 12),
                            OutlinedButton(
                              key: const Key('logout-button'),
                              onPressed: _busy ? null : _logout,
                              child: _AccountActionContent(
                                icon: _action == _AccountAction.loggingOut
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.logout),
                                label: context.l10n.accountLogoutAction,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _export() async {
    setState(() {
      _action = _AccountAction.exporting;
    });
    try {
      final String json = await widget.apiClient.exportAccount();
      final AccountExportCoordinator coordinator =
          widget.exportCoordinator ??
          AccountExportCoordinator.fromEnvironment();
      final AccountExportArtifact artifact = await coordinator.saveAndShare(
        json,
        sharePositionOrigin: _shareOrigin(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _lastExport = artifact;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.accountExportReady(artifact.fileName)),
        ),
      );
    } on Object catch (error) {
      _showError(
        _accountErrorMessage(
          context.l10n,
          error,
          operation: context.l10n.accountExportOperation,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _action = null;
        });
      }
    }
  }

  Future<void> _confirmAndDelete() async {
    final bool intentConfirmed = await _confirmDeletionIntent();
    if (!intentConfirmed || !mounted) {
      return;
    }
    final bool phraseConfirmed = await _confirmDeletionPhrase();
    if (!phraseConfirmed || !mounted) {
      return;
    }
    final String idempotencyKey =
        _pendingDeletionKey ??
        widget.idempotencyKeyFactory?.call() ??
        _newIdempotencyKey();
    _pendingDeletionKey = idempotencyKey;
    setState(() {
      _action = _AccountAction.deleting;
    });
    try {
      await widget.controller.reauthenticateForSensitiveAction();
      final AccountDeletionReceipt receipt = await widget.apiClient
          .requestDeletion(idempotencyKey: idempotencyKey);
      await widget.controller.logout(
        completionNotice: context.l10n.accountDeletedNotice(receipt.receiptId),
      );
    } on AuthUserCancelledException {
      _showError(context.l10n.accountIdentityCancelled);
    } on Object catch (error) {
      _showError(
        _accountErrorMessage(
          context.l10n,
          error,
          operation: context.l10n.accountDeleteOperation,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _action = null;
        });
      }
    }
  }

  Future<void> _logout() async {
    setState(() {
      _action = _AccountAction.loggingOut;
    });
    await widget.controller.logout();
  }

  Future<bool> _confirmDeletionIntent() async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return ExpeditionDecisionDialog(
              key: const Key('account-delete-intent-dialog'),
              badgeLabel: context.l10n.accountDeleteIntentBadge,
              title: context.l10n.accountDeleteIntentTitle,
              message: context.l10n.accountDeleteIntentMessage,
              icon: Icons.delete_forever_outlined,
              confirmLabel: context.l10n.accountContinue,
              confirmButtonKey: const Key('account-delete-continue'),
              destructive: true,
              onCancel: () => Navigator.pop(context, false),
              onConfirm: () => Navigator.pop(context, true),
            );
          },
        ) ??
        false;
  }

  Future<bool> _confirmDeletionPhrase() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const _DeletionPhraseDialog();
          },
        ) ??
        false;
  }

  Rect? _shareOrigin() {
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  void _handleAuthStateChanged() {
    if (!mounted ||
        _dismissRequested ||
        widget.controller.state == AuthLifecycleState.authenticated) {
      return;
    }
    _dismissRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        unawaited(Navigator.maybeOf(context)?.maybePop());
      }
    });
  }

  void _subscribeRecovery() {
    final MobileCommandRuntime? runtime = widget.commandRuntime;
    if (runtime == null) {
      return;
    }
    _recoverySubscription = runtime.changes.listen((void _) {
      unawaited(_refreshRecoveryStatus(runtime));
    });
    unawaited(_refreshRecoveryStatus(runtime));
  }

  Future<void> _refreshRecoveryStatus(MobileCommandRuntime runtime) async {
    final int generation = ++_recoveryLoadGeneration;
    try {
      final MobileCommandRecoverySnapshot snapshot = await runtime
          .recoverySnapshot();
      if (!mounted ||
          generation != _recoveryLoadGeneration ||
          !identical(widget.commandRuntime, runtime)) {
        return;
      }
      setState(() {
        _recoveryCount = snapshot.totalCount;
        _recoveryUnavailable = false;
      });
    } on Object {
      if (!mounted ||
          generation != _recoveryLoadGeneration ||
          !identical(widget.commandRuntime, runtime)) {
        return;
      }
      setState(() {
        _recoveryUnavailable = true;
      });
    }
  }

  Future<void> _openRecoveryAndRefresh() async {
    final Future<void> Function()? openRecovery = widget.onOpenRecovery;
    if (openRecovery == null) {
      return;
    }
    try {
      await openRecovery();
    } finally {
      final MobileCommandRuntime? runtime = widget.commandRuntime;
      if (mounted && runtime != null) {
        await _refreshRecoveryStatus(runtime);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PilotDossier extends StatelessWidget {
  const _PilotDossier({
    super.key,
    required this.identity,
    required this.compact,
  });

  final AuthIdentity identity;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool development = identity.isDevelopment;
    final String sessionDescription = development
        ? context.l10n.accountDevelopmentSessionDescription
        : context.l10n.accountOidcSessionDescription;
    final Widget avatar = PilotPortrait(
      key: const Key('account-pilot-portrait'),
      name: identity.displayName,
      size: compact ? 80 : 72,
      highlighted: !development,
    );
    final Widget details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.accountPilotDossierLabel,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          identity.displayName,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 3),
        Text(
          sessionDescription,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            ExpeditionBadge(
              label: development
                  ? context.l10n.accountLocalSessionBadge
                  : context.l10n.accountOidcVerifiedBadge,
              icon: development
                  ? Icons.developer_mode_outlined
                  : Icons.verified_user_outlined,
              tone: development
                  ? ExpeditionPanelTone.resonance
                  : ExpeditionPanelTone.lumen,
              allowWrap: compact,
            ),
          ],
        ),
      ],
    );

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: context.l10n.accountPilotDossierSemantics(
        identity.displayName,
        sessionDescription,
      ),
      child: ExpeditionPanel(
        tone: development
            ? ExpeditionPanelTone.resonance
            : ExpeditionPanelTone.lumen,
        padding: EdgeInsets.all(compact ? 16 : 20),
        child: compact
            ? Column(
                key: const Key('account-pilot-dossier-compact'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[avatar, const SizedBox(height: 14), details],
              )
            : Row(
                key: const Key('account-pilot-dossier-wide'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  avatar,
                  const SizedBox(width: 16),
                  Expanded(child: details),
                ],
              ),
      ),
    );
  }
}

class _AccountLinkPanel extends StatelessWidget {
  const _AccountLinkPanel({
    super.key,
    required this.compact,
    required this.tone,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final bool compact;
  final ExpeditionPanelTone tone;
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return ExpeditionPanel(
        tone: tone,
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  key: const Key('account-link-compact'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        leading,
                        const Spacer(),
                        if (onTap != null)
                          const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return ExpeditionPanel(
      tone: tone,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 8,
            ),
            leading: leading,
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: onTap == null
                ? null
                : const Icon(Icons.chevron_right_rounded),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

class _AccountDangerPanel extends StatelessWidget {
  const _AccountDangerPanel({
    super.key,
    required this.compact,
    required this.development,
    required this.busy,
    required this.deleting,
    required this.retrying,
    required this.onDelete,
  });

  final bool compact;
  final bool development;
  final bool busy;
  final bool deleting;
  final bool retrying;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.error.withValues(alpha: 0.55)),
        color: Color.alphaBlend(
          colors.error.withValues(alpha: 0.08),
          colors.surfaceContainerHigh.withValues(alpha: 0.96),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.shadow,
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 20),
        child: Column(
          key: Key(
            compact
                ? 'account-danger-zone-compact'
                : 'account-danger-zone-wide',
          ),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.warning_amber_rounded, color: colors.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.accountDeleteSectionTitle,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: colors.error),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              development
                  ? context.l10n.accountDeleteDevelopmentMessage
                  : context.l10n.accountDeleteMessage,
            ),
            const SizedBox(height: 18),
            FilledButton(
              key: const Key('account-delete-button'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: busy || development ? null : onDelete,
              child: _AccountActionContent(
                icon: deleting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_forever),
                label: deleting
                    ? context.l10n.accountDeleting
                    : retrying
                    ? context.l10n.accountDeleteRetry
                    : context.l10n.accountDeleteAction,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountActionContent extends StatelessWidget {
  const _AccountActionContent({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        icon,
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _DeletionPhraseDialog extends StatefulWidget {
  const _DeletionPhraseDialog();

  @override
  State<_DeletionPhraseDialog> createState() => _DeletionPhraseDialogState();
}

class _DeletionPhraseDialogState extends State<_DeletionPhraseDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String phrase = context.l10n.accountDeletePhrase;
    final bool confirmed = _controller.text.trim() == phrase;
    return ExpeditionDecisionDialog(
      key: const Key('account-delete-phrase-dialog'),
      badgeLabel: context.l10n.accountDeletePhraseBadge,
      title: context.l10n.accountDeletePhraseTitle,
      message: context.l10n.accountDeletePhraseMessage(phrase),
      icon: Icons.lock_outline,
      confirmLabel: context.l10n.accountDeleteForever,
      confirmButtonKey: const Key('account-delete-confirm'),
      destructive: true,
      onCancel: () => Navigator.pop(context, false),
      onConfirm: confirmed ? () => Navigator.pop(context, true) : null,
      content: TextField(
        key: const Key('account-delete-phrase'),
        controller: _controller,
        autofocus: true,
        autocorrect: false,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          hintText: phrase,
        ),
      ),
    );
  }

  void _handleChanged() {
    setState(() {});
  }
}

String _accountErrorMessage(
  AppLocalizations l10n,
  Object error, {
  required String operation,
}) {
  if (error is AccountApiException) {
    if (error.statusCode == 401) {
      return l10n.accountErrorSessionExpired(operation);
    }
    if (error.code == 'FRESH_AUTHENTICATION_REQUIRED') {
      return l10n.accountErrorFreshAuthentication;
    }
    if (error.statusCode == 403) {
      return l10n.accountErrorForbidden;
    }
    if (error.statusCode == 409) {
      return l10n.accountErrorConflict;
    }
    if (error.statusCode == 410 || error.code == 'ACCOUNT_DELETED') {
      return l10n.accountErrorDeleted;
    }
    if (error.retryable) {
      return l10n.accountErrorRetryable;
    }
    return l10n.accountErrorGeneric(operation);
  }
  if (error is HomeNetworkException) {
    return l10n.accountErrorNetwork;
  }
  if (error is AuthSensitiveActionException ||
      error is AuthReauthenticationRequiredException ||
      error is AuthAccountDeletedException) {
    return l10n.accountErrorSensitiveAction;
  }
  if (error is FormatException) {
    return l10n.accountErrorInvalidResponse;
  }
  return l10n.accountErrorGeneric(operation);
}

String _newIdempotencyKey() {
  final Random random = Random.secure();
  final StringBuffer value = StringBuffer('account-delete-');
  for (int index = 0; index < 16; index += 1) {
    value.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return value.toString();
}
