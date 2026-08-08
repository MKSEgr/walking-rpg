import 'dart:async';

import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/localization/app_locale_controller.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';

class AppLocaleScope extends InheritedNotifier<AppLocaleController> {
  const AppLocaleScope({
    super.key,
    required AppLocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLocaleController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppLocaleScope>()
        ?.notifier;
  }
}

class AppLocaleMenuButton extends StatelessWidget {
  const AppLocaleMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocaleController? controller = AppLocaleScope.maybeOf(context);
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: const Key('app-locale-menu-button'),
      tooltip: context.l10n.changeLanguageTooltip,
      onPressed: () {
        unawaited(showAppLocalePicker(context, controller));
      },
      icon: const Icon(Icons.language),
    );
  }
}

Future<void> showAppLocalePicker(
  BuildContext context,
  AppLocaleController controller,
) async {
  final AppLocale? selected = await showModalBottomSheet<AppLocale>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) {
      return _AppLocalePicker(selected: controller.selected);
    },
  );
  if (selected == null || selected == controller.selected || !context.mounted) {
    return;
  }
  try {
    await controller.select(selected);
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.languageSaveError)));
    }
  }
}

class _AppLocalePicker extends StatelessWidget {
  const _AppLocalePicker({required this.selected});

  final AppLocale selected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: <Widget>[
        Text(
          context.l10n.languageSheetTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(context.l10n.languagePreferenceScope),
        const SizedBox(height: 16),
        _LocaleListTile(
          key: const Key('app-locale-option-ru'),
          locale: AppLocale.russian,
          selected: selected == AppLocale.russian,
          title: context.l10n.russianLanguageNative,
          subtitle: context.l10n.russianLanguageDescription,
        ),
        _LocaleListTile(
          key: const Key('app-locale-option-en'),
          locale: AppLocale.english,
          selected: selected == AppLocale.english,
          title: context.l10n.englishLanguageNative,
          subtitle: context.l10n.englishLanguageDescription,
        ),
      ],
    );
  }
}

class _LocaleListTile extends StatelessWidget {
  const _LocaleListTile({
    super.key,
    required this.locale,
    required this.selected,
    required this.title,
    required this.subtitle,
  });

  final AppLocale locale;
  final bool selected;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: ListTile(
        key: Key('app-locale-tile-${locale.languageCode}'),
        selected: selected,
        leading: CircleAvatar(child: Text(locale.languageCode.toUpperCase())),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: selected ? const Icon(Icons.check_circle) : null,
        onTap: () => Navigator.of(context).pop(locale),
      ),
    );
  }
}

class AppLocaleChoiceScreen extends StatefulWidget {
  const AppLocaleChoiceScreen({super.key, required this.controller});

  final AppLocaleController controller;

  @override
  State<AppLocaleChoiceScreen> createState() => _AppLocaleChoiceScreenState();
}

class _AppLocaleChoiceScreenState extends State<AppLocaleChoiceScreen> {
  late AppLocale _selected;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = widget.controller.selected;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ExpeditionBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              key: const Key('app-locale-choice-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ExpeditionPanel(
                  tone: ExpeditionPanelTone.resonance,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ExpeditionBadge(
                          label: context.l10n.languageChoiceBadge,
                          icon: Icons.language,
                          tone: ExpeditionPanelTone.resonance,
                          allowWrap: true,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        context.l10n.appName,
                        key: const Key('app-locale-product-title'),
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.appNameRussian,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        context.l10n.languageChoiceTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(context.l10n.languageChoiceBody),
                      const SizedBox(height: 18),
                      _LocaleChoiceCard(
                        key: const Key('app-locale-choice-ru'),
                        locale: AppLocale.russian,
                        selected: _selected == AppLocale.russian,
                        title: context.l10n.russianLanguageNative,
                        subtitle: context.l10n.russianLanguageDescription,
                        onSelected: _select,
                      ),
                      const SizedBox(height: 10),
                      _LocaleChoiceCard(
                        key: const Key('app-locale-choice-en'),
                        locale: AppLocale.english,
                        selected: _selected == AppLocale.english,
                        title: context.l10n.englishLanguageNative,
                        subtitle: context.l10n.englishLanguageDescription,
                        onSelected: _select,
                      ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          key: const Key('app-locale-save-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        key: const Key('app-locale-continue'),
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.arrow_forward),
                        label: Text(
                          _saving
                              ? context.l10n.languageSaving
                              : context.l10n.languageContinue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _select(AppLocale locale) {
    if (_saving) {
      return;
    }
    setState(() {
      _selected = locale;
      _error = null;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.select(_selected);
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = context.l10n.languageSaveError;
        });
      }
    }
  }
}

class _LocaleChoiceCard extends StatelessWidget {
  const _LocaleChoiceCard({
    super.key,
    required this.locale,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onSelected,
  });

  final AppLocale locale;
  final bool selected;
  final String title;
  final String subtitle;
  final ValueChanged<AppLocale> onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? colors.primaryContainer.withValues(alpha: 0.42)
            : colors.surfaceContainerHighest.withValues(alpha: 0.62),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onSelected(locale),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                CircleAvatar(child: Text(locale.languageCode.toUpperCase())),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(subtitle),
                    ],
                  ),
                ),
                if (selected) ...<Widget>[
                  const SizedBox(width: 10),
                  const Icon(Icons.check_circle),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
