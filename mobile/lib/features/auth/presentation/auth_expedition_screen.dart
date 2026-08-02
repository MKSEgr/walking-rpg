import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/design_system/chapter_vista.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

/// Presentation-only entry screen for the existing authentication lifecycle.
///
/// The screen does not start or interpret OIDC itself. Authentication state,
/// messages and the sign-in callback remain owned by the session controller at
/// the application boundary.
class AuthExpeditionScreen extends StatelessWidget {
  const AuthExpeditionScreen({
    super.key,
    required this.reauthentication,
    required this.busy,
    required this.onSignIn,
    this.message,
    this.notice,
  });

  final bool reauthentication;
  final bool busy;
  final VoidCallback onSignIn;
  final String? message;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ExpeditionBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wide = constraints.maxWidth >= 900;
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 40 : 20,
                    24,
                    wide ? 40 : 20,
                    32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              const Expanded(child: _ExpeditionEntryStory()),
                              const SizedBox(width: 32),
                              SizedBox(
                                width: 380,
                                child: _SignInPanel(
                                  reauthentication: reauthentication,
                                  busy: busy,
                                  message: message,
                                  notice: notice,
                                  onSignIn: onSignIn,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              const _ExpeditionEntryStory(compact: true),
                              const SizedBox(height: 20),
                              _SignInPanel(
                                reauthentication: reauthentication,
                                busy: busy,
                                message: message,
                                notice: notice,
                                onSignIn: onSignIn,
                              ),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ExpeditionEntryStory extends StatelessWidget {
  const _ExpeditionEntryStory({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ExpeditionBadge(
          key: Key('auth-signal-badge'),
          label: 'Сигнал маяка 01',
          icon: Icons.sensors,
          tone: ExpeditionPanelTone.resonance,
        ),
        const SizedBox(height: 18),
        Text(
          'Walking RPG',
          key: const Key('auth-title'),
          style: compact
              ? Theme.of(context).textTheme.headlineLarge
              : Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Твой маршрут начинается с реальных шагов',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        Text(
          'Шаги становятся ENERGY, ENERGY открывает путь, а каждое решение '
          'оставляет след в экспедиции.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        ChapterVista(
          key: const Key('auth-chapter-vista'),
          semanticLabel: 'Туманный сектор и сигнальный маяк',
          height: compact ? 184 : 224,
        ),
        const SizedBox(height: 14),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            ExpeditionBadge(
              label: 'Без GPS',
              icon: Icons.location_disabled,
              tone: ExpeditionPanelTone.neutral,
            ),
            ExpeditionBadge(
              label: 'Только шаги · чтение',
              icon: Icons.directions_walk,
              tone: ExpeditionPanelTone.neutral,
            ),
          ],
        ),
      ],
    );
  }
}

class _SignInPanel extends StatelessWidget {
  const _SignInPanel({
    required this.reauthentication,
    required this.busy,
    required this.message,
    required this.notice,
    required this.onSignIn,
  });

  final bool reauthentication;
  final bool busy;
  final String? message;
  final String? notice;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    return ExpeditionPanel(
      key: const Key('auth-sign-in-panel'),
      tone: reauthentication
          ? ExpeditionPanelTone.resonance
          : ExpeditionPanelTone.lumen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: ExpeditionBadge(
              label: reauthentication
                  ? 'Требуется повторный вход'
                  : 'Канал экспедиции',
              icon: reauthentication
                  ? Icons.restart_alt
                  : Icons.shield_outlined,
              tone: reauthentication
                  ? ExpeditionPanelTone.resonance
                  : ExpeditionPanelTone.lumen,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            reauthentication ? 'Вернуться в экспедицию' : 'Открыть экспедицию',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            reauthentication
                ? 'Сессия завершена. Войдите снова, чтобы продолжить '
                      'синхронизацию и игровые действия.'
                : 'Войдите через корпоративную учётную запись. Авторизация '
                      'откроется в системном браузере.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (message != null && message!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            _AuthStatus(
              key: const Key('auth-message'),
              message: message!,
              icon: Icons.error_outline,
              color: colors.error,
            ),
          ],
          if (notice != null && notice!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            _AuthStatus(
              key: const Key('auth-notice'),
              message: notice!,
              icon: Icons.check_circle_outline,
              color: colors.primary,
            ),
          ],
          const SizedBox(height: 18),
          DecoratedBox(
            decoration: BoxDecoration(
              color: palette.panelHighlight.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.panelBorder),
            ),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.open_in_browser_outlined, size: 21),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Пароль не вводится и не хранится в приложении.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('oidc-sign-in-button'),
            onPressed: busy ? null : onSignIn,
            icon: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward),
            label: Text(
              busy ? 'Открываем защищённый вход...' : 'Войти в экспедицию',
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthStatus extends StatelessWidget {
  const _AuthStatus({
    super.key,
    required this.message,
    required this.icon,
    required this.color,
  });

  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.38)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
