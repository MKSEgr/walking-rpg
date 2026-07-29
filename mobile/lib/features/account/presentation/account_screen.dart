import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/auth/auth_models.dart';
import 'package:walking_rpg_mobile/core/auth/auth_session_controller.dart';
import 'package:walking_rpg_mobile/core/auth/oidc_client.dart';
import 'package:walking_rpg_mobile/features/account/application/account_export_coordinator.dart';
import 'package:walking_rpg_mobile/features/account/data/account_api_client.dart';
import 'package:walking_rpg_mobile/features/account/domain/account_deletion_receipt.dart';
import 'package:walking_rpg_mobile/features/home/data/io_home_transport.dart';

enum _AccountAction { exporting, deleting, loggingOut }

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.controller,
    required this.identity,
    required this.apiClient,
    this.exportCoordinator,
    this.idempotencyKeyFactory,
  });

  final AuthSessionController controller;
  final AuthIdentity identity;
  final AccountApiClient apiClient;
  final AccountExportCoordinator? exportCoordinator;
  final String Function()? idempotencyKeyFactory;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  _AccountAction? _action;
  AccountExportArtifact? _lastExport;
  String? _pendingDeletionKey;
  bool _dismissRequested = false;

  bool get _busy => _action != null;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleAuthStateChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleAuthStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Аккаунт и данные')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(widget.identity.displayName),
                subtitle: Text(
                  widget.identity.isDevelopment
                      ? 'Локальный development-режим'
                      : 'Защищённая OIDC-сессия',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Экспорт данных',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Walking RPG сформирует JSON-файл с игровым прогрессом, '
                      'активностью, устройствами и историей операций.',
                    ),
                    if (_lastExport != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        'Последний экспорт: ${_lastExport!.fileName}',
                        key: const Key('account-last-export'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      key: const Key('account-export-button'),
                      onPressed: _busy ? null : _export,
                      icon: _action == _AccountAction.exporting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.ios_share),
                      label: Text(
                        _action == _AccountAction.exporting
                            ? 'Готовим файл...'
                            : 'Создать и передать JSON',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Удаление аккаунта',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.identity.isDevelopment
                          ? 'Постоянное удаление доступно только после входа '
                                'через OIDC.'
                          : 'Операция безвозвратно удалит игровые данные. '
                                'Перед запросом потребуется повторно подтвердить '
                                'личность.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('account-delete-button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      ),
                      onPressed: _busy || widget.identity.isDevelopment
                          ? null
                          : _confirmAndDelete,
                      icon: _action == _AccountAction.deleting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_forever),
                      label: Text(
                        _action == _AccountAction.deleting
                            ? 'Удаляем аккаунт...'
                            : _pendingDeletionKey == null
                            ? 'Удалить аккаунт'
                            : 'Повторить запрос удаления',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!widget.identity.isDevelopment) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('logout-button'),
                onPressed: _busy ? null : _logout,
                icon: _action == _AccountAction.loggingOut
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout),
                label: const Text('Выйти и очистить локальные данные'),
              ),
            ],
          ],
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
        SnackBar(content: Text('Экспорт готов: ${artifact.fileName}')),
      );
    } on Object catch (error) {
      _showError(
        _accountErrorMessage(error, operation: 'экспортировать данные'),
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
        completionNotice:
            'Игровой аккаунт удалён. Квитанция: ${receipt.receiptId}',
      );
    } on AuthUserCancelledException {
      _showError('Подтверждение личности отменено. Данные не удалены.');
    } on Object catch (error) {
      _showError(_accountErrorMessage(error, operation: 'удалить аккаунт'));
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
            return AlertDialog(
              title: const Text('Удалить аккаунт?'),
              content: const Text(
                'Будут удалены игровой прогресс, история активности, '
                'инвентарь, участие в отрядах и серверные настройки. '
                'Отменить операцию после подтверждения нельзя.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  key: const Key('account-delete-continue'),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Продолжить'),
                ),
              ],
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

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DeletionPhraseDialog extends StatefulWidget {
  const _DeletionPhraseDialog();

  @override
  State<_DeletionPhraseDialog> createState() => _DeletionPhraseDialogState();
}

class _DeletionPhraseDialogState extends State<_DeletionPhraseDialog> {
  final TextEditingController _controller = TextEditingController();

  bool get _confirmed => _controller.text.trim() == 'УДАЛИТЬ';

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
    return AlertDialog(
      title: const Text('Последнее подтверждение'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('Введите УДАЛИТЬ заглавными буквами:'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('account-delete-phrase'),
            controller: _controller,
            autofocus: true,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'УДАЛИТЬ',
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          key: const Key('account-delete-confirm'),
          onPressed: _confirmed ? () => Navigator.pop(context, true) : null,
          child: const Text('Удалить навсегда'),
        ),
      ],
    );
  }

  void _handleChanged() {
    setState(() {});
  }
}

String _accountErrorMessage(Object error, {required String operation}) {
  if (error is AccountApiException) {
    if (error.statusCode == 401) {
      return 'Сессия истекла. Войдите снова, чтобы $operation.';
    }
    if (error.code == 'FRESH_AUTHENTICATION_REQUIRED') {
      return 'Identity provider не подтвердил свежий вход. '
          'Повторите операцию после интерактивной авторизации.';
    }
    if (error.statusCode == 403) {
      return 'У аккаунта нет права выполнить операцию.';
    }
    if (error.statusCode == 409) {
      return 'Backend обнаружил конфликт запроса. Повторите операцию.';
    }
    if (error.statusCode == 410 || error.code == 'ACCOUNT_DELETED') {
      return 'Игровой аккаунт уже удалён. Завершите локальную сессию.';
    }
    if (error.retryable) {
      return 'Backend временно недоступен. Запрос можно безопасно повторить.';
    }
    return error.message;
  }
  if (error is HomeNetworkException) {
    return 'Нет соединения с backend. Запрос можно повторить.';
  }
  if (error is AuthSensitiveActionException ||
      error is AuthReauthenticationRequiredException ||
      error is AuthAccountDeletedException) {
    return error.toString();
  }
  if (error is FormatException) {
    return 'Backend вернул некорректный ответ: $error';
  }
  return 'Не удалось $operation: $error';
}

String _newIdempotencyKey() {
  final Random random = Random.secure();
  final StringBuffer value = StringBuffer('account-delete-');
  for (int index = 0; index < 16; index += 1) {
    value.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return value.toString();
}
