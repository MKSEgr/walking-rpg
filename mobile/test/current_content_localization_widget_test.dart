import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/localization/current_content_localizations.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('current content resolves every known stable ID in RU and EN', (
    WidgetTester tester,
  ) async {
    for (final _CatalogLocaleCase localeCase in _localeCases) {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          locale: localeCase.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              l10n = AppLocalizations.of(context)!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        l10n.currentExpeditionName('starter-expedition-v1', _fallback),
        localeCase.expeditionName,
      );
      expect(
        l10n.currentPilotName('navigator-v1', _fallback),
        localeCase.pilotName,
      );
      for (final MapEntry<String, String> pet in localeCase.petNames.entries) {
        expect(l10n.currentPetName(pet.key, _fallback), pet.value);
        expect(
          l10n.currentPetSpecies(pet.key, _fallback),
          localeCase.petSpecies[pet.key],
        );
      }

      for (final MapEntry<String, String> node in localeCase.nodes.entries) {
        expect(
          l10n.currentNodeName(node.key, _fallback),
          node.value,
          reason: '${localeCase.locale.languageCode} node ${node.key}',
        );
      }
      for (final MapEntry<String, _IdentityCopy> item
          in localeCase.items.entries) {
        expect(
          l10n.currentItemName(item.key, _fallback),
          item.value.name,
          reason: '${localeCase.locale.languageCode} item ${item.key}',
        );
        expect(
          l10n.currentItemDescription(item.key, _fallback),
          item.value.description,
          reason:
              '${localeCase.locale.languageCode} item description ${item.key}',
        );
      }
      expect(
        l10n.currentEquipmentSlotName('NAVIGATION', _fallback),
        localeCase.equipment.name,
      );
      expect(
        l10n.currentEquipmentSlotDescription('NAVIGATION', _fallback),
        localeCase.equipment.description,
      );
      for (final MapEntry<String, _IdentityCopy> recipe
          in localeCase.recipes.entries) {
        expect(
          l10n.currentRecipeName(recipe.key, _fallback),
          recipe.value.name,
        );
        expect(
          l10n.currentRecipeDescription(recipe.key, _fallback),
          recipe.value.description,
        );
      }
      for (final MapEntry<String, _IdentityCopy> upgrade
          in localeCase.upgrades.entries) {
        expect(
          l10n.currentUpgradeName(upgrade.key, _fallback),
          upgrade.value.name,
        );
        expect(
          l10n.currentUpgradeDescription(upgrade.key, _fallback),
          upgrade.value.description,
        );
      }
    }
  });

  testWidgets('unknown and missing stable IDs preserve literal copy', (
    WidgetTester tester,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            l10n = AppLocalizations.of(context)!;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(l10n.currentExpeditionName('future', _fallback), _fallback);
    expect(l10n.currentNodeName('future', _fallback), _fallback);
    expect(l10n.currentPilotName(null, _fallback), _fallback);
    expect(l10n.currentPilotName('future', _fallback), _fallback);
    expect(l10n.currentPetName(null, _fallback), _fallback);
    expect(l10n.currentPetName('future', _fallback), _fallback);
    expect(l10n.currentPetSpecies(null, _fallback), _fallback);
    expect(l10n.currentPetSpecies('future', _fallback), _fallback);
    expect(l10n.currentItemName('future', _fallback), _fallback);
    expect(l10n.currentItemDescription('future', _fallback), _fallback);
    expect(l10n.currentEquipmentSlotName('future', _fallback), _fallback);
    expect(
      l10n.currentEquipmentSlotDescription('future', _fallback),
      _fallback,
    );
    expect(l10n.currentRecipeName('future', _fallback), _fallback);
    expect(l10n.currentRecipeDescription('future', _fallback), _fallback);
    expect(l10n.currentUpgradeName('future', _fallback), _fallback);
    expect(l10n.currentUpgradeDescription('future', _fallback), _fallback);
  });
}

const String _fallback = 'Серверная строка будущего контента';

class _IdentityCopy {
  const _IdentityCopy(this.name, this.description);

  final String name;
  final String description;
}

class _CatalogLocaleCase {
  const _CatalogLocaleCase({
    required this.locale,
    required this.expeditionName,
    required this.pilotName,
    required this.petNames,
    required this.petSpecies,
    required this.nodes,
    required this.items,
    required this.equipment,
    required this.recipes,
    required this.upgrades,
  });

  final Locale locale;
  final String expeditionName;
  final String pilotName;
  final Map<String, String> petNames;
  final Map<String, String> petSpecies;
  final Map<String, String> nodes;
  final Map<String, _IdentityCopy> items;
  final _IdentityCopy equipment;
  final Map<String, _IdentityCopy> recipes;
  final Map<String, _IdentityCopy> upgrades;
}

const List<_CatalogLocaleCase> _localeCases = <_CatalogLocaleCase>[
  _CatalogLocaleCase(
    locale: Locale('ru'),
    expeditionName: 'Сигнал из туманного сектора',
    pilotName: 'Навигатор',
    petNames: <String, String>{
      'spark-v1': 'Искра',
      'moss-v1': 'Мох',
      'rune-v1': 'Навигатор',
    },
    petSpecies: <String, String>{
      'spark-v1': 'люмин',
      'moss-v1': 'терра',
      'rune-v1': 'эхо',
    },
    nodes: <String, String>{
      'outer-beacon': 'Внешний маяк',
      'lumen-gate': 'Люминовые ворота',
      'ash-orbit': 'Пепельная орбита',
      'glass-marsh': 'Стеклянные топи',
      'silent-quarry': 'Тихий карьер',
      'copper-ravine': 'Медный разлом',
      'ion-garden': 'Ионный сад',
      'frost-antenna': 'Ледяная антенна',
      'obsidian-crossing': 'Обсидиановая переправа',
      'pulse-foundry': 'Импульсная литейная',
      'mirror-delta': 'Зеркальная дельта',
      'storm-archive': 'Грозовой архив',
      'ember-station': 'Угольная станция',
      'aurora-bridge': 'Мост сияния',
      'void-orchard': 'Сад пустоты',
      'star-well': 'Звёздный колодец',
      'horizon-spire': 'Шпиль горизонта',
      'dawn-relay': 'Ретранслятор рассвета',
      'resonance-pocket': 'Резонансный карман',
      'storm-scriptorium': 'Грозовой скрипторий',
      'root-memory': 'Память корней',
      'light-canopy': 'Световая крона',
      'spectrum-observatory': 'Спектральная обсерватория',
      'second-dawn-threshold': 'Порог второго рассвета',
      'uncharted-verge': 'Неизведанный рубеж',
      'constellation-sanctuary': 'Святилище созвездий',
      'hidden-signal-observatory': 'Обсерватория скрытого сигнала',
      'memory-constellation': 'Созвездие памяти',
      'dawn-meridian': 'Меридиан рассвета',
      'first-light-causeway': 'Переход первого света',
    },
    items: <String, _IdentityCopy>{
      'lumen-shard': _IdentityCopy(
        'Люминовый осколок',
        'Стабильный фрагмент светового ядра, пригодный для будущих улучшений.',
      ),
      'echo-thread': _IdentityCopy(
        'Нить эха',
        'Тонкая энергетическая нить, сохранившая маршрут через хранилище.',
      ),
      'ash-seed': _IdentityCopy(
        'Семя пепла',
        'Тёплое зерно из пепельной орбиты, реагирующее на движение пилота.',
      ),
      'prism-dust': _IdentityCopy(
        'Призматическая пыль',
        'Мелкие кристаллы, меняющие спектр рядом с активным питомцем.',
      ),
      'ion-bloom': _IdentityCopy(
        'Ионный цветок',
        'Редкий материал, накопивший заряд в садах первой главы.',
      ),
      'dawn-fragment': _IdentityCopy(
        'Фрагмент рассвета',
        'Сезонный материал из последнего ретранслятора первой главы.',
      ),
      'resonance-compass': _IdentityCopy(
        'Резонансный компас',
        'Уникальный прибор, собранный из люминовых осколков и нити эха.',
      ),
      'prism-sextant': _IdentityCopy(
        'Призматический секстант',
        'Уникальный прибор, сводящий свет поздних маршрутов в карту скрытого спектра.',
      ),
    },
    equipment: _IdentityCopy(
      'Навигационный прибор',
      'Один уникальный инструмент, влияющий на доступные маршруты.',
    ),
    recipes: <String, _IdentityCopy>{
      'resonance-compass-v1': _IdentityCopy(
        'Собрать резонансный компас',
        'Соединить световое ядро с живой нитью маршрута.',
      ),
      'prism-sextant-v1': _IdentityCopy(
        'Собрать призматический секстант',
        'Свести пыль, ионный заряд и свет рассвета в карту скрытого спектра.',
      ),
    },
    upgrades: <String, _IdentityCopy>{
      'prism-sextant-calibration-v1': _IdentityCopy(
        'Откалибровать призматический секстант',
        'Закрепить карту невидимого спектра и повысить точность прибора.',
      ),
      'prism-sextant-second-dawn-attunement-v1': _IdentityCopy(
        'Настроить секстант на второй рассвет',
        'Закрепить в приборе координаты нового горизонта.',
      ),
    },
  ),
  _CatalogLocaleCase(
    locale: Locale('en'),
    expeditionName: 'Signal from the Fog Sector',
    pilotName: 'Navigator',
    petNames: <String, String>{
      'spark-v1': 'Spark',
      'moss-v1': 'Moss',
      'rune-v1': 'Navigator',
    },
    petSpecies: <String, String>{
      'spark-v1': 'lumin',
      'moss-v1': 'terra',
      'rune-v1': 'echo',
    },
    nodes: <String, String>{
      'outer-beacon': 'Outer Beacon',
      'lumen-gate': 'Lumen Gate',
      'ash-orbit': 'Ash Orbit',
      'glass-marsh': 'Glass Marsh',
      'silent-quarry': 'Silent Quarry',
      'copper-ravine': 'Copper Rift',
      'ion-garden': 'Ion Garden',
      'frost-antenna': 'Frost Antenna',
      'obsidian-crossing': 'Obsidian Crossing',
      'pulse-foundry': 'Pulse Foundry',
      'mirror-delta': 'Mirror Delta',
      'storm-archive': 'Storm Archive',
      'ember-station': 'Ember Station',
      'aurora-bridge': 'Aurora Bridge',
      'void-orchard': 'Void Orchard',
      'star-well': 'Star Well',
      'horizon-spire': 'Horizon Spire',
      'dawn-relay': 'Dawn Relay',
      'resonance-pocket': 'Resonance Pocket',
      'storm-scriptorium': 'Storm Scriptorium',
      'root-memory': 'Root Memory',
      'light-canopy': 'Light Canopy',
      'spectrum-observatory': 'Spectrum Observatory',
      'second-dawn-threshold': 'Second Dawn Threshold',
      'uncharted-verge': 'Uncharted Verge',
      'constellation-sanctuary': 'Constellation Sanctuary',
      'hidden-signal-observatory': 'Hidden Signal Observatory',
      'memory-constellation': 'Memory Constellation',
      'dawn-meridian': 'Dawn Meridian',
      'first-light-causeway': 'First Light Causeway',
    },
    items: <String, _IdentityCopy>{
      'lumen-shard': _IdentityCopy(
        'Lumen Shard',
        'A stable fragment of a light core, suitable for future upgrades.',
      ),
      'echo-thread': _IdentityCopy(
        'Echo Thread',
        'A thin energy thread preserving a route through the vault.',
      ),
      'ash-seed': _IdentityCopy(
        'Ash Seed',
        'A warm seed from the ash orbit that responds to the pilot’s movement.',
      ),
      'prism-dust': _IdentityCopy(
        'Prismatic Dust',
        'Fine crystals that shift their spectrum near the active companion.',
      ),
      'ion-bloom': _IdentityCopy(
        'Ion Bloom',
        'A rare material charged in the gardens of the first chapter.',
      ),
      'dawn-fragment': _IdentityCopy(
        'Dawn Fragment',
        'A seasonal material from the final relay of the first chapter.',
      ),
      'resonance-compass': _IdentityCopy(
        'Resonance Compass',
        'A unique instrument assembled from lumen shards and an echo thread.',
      ),
      'prism-sextant': _IdentityCopy(
        'Prismatic Sextant',
        'A unique instrument that turns the light of late routes into a map of the hidden spectrum.',
      ),
    },
    equipment: _IdentityCopy(
      'Navigation instrument',
      'One unique instrument that affects available routes.',
    ),
    recipes: <String, _IdentityCopy>{
      'resonance-compass-v1': _IdentityCopy(
        'Assemble a Resonance Compass',
        'Bind the light core to the living route thread.',
      ),
      'prism-sextant-v1': _IdentityCopy(
        'Assemble a Prismatic Sextant',
        'Combine dust, ion charge, and dawnlight into a map of the hidden spectrum.',
      ),
    },
    upgrades: <String, _IdentityCopy>{
      'prism-sextant-calibration-v1': _IdentityCopy(
        'Calibrate the Prismatic Sextant',
        'Fix the invisible-spectrum map and improve the instrument’s precision.',
      ),
      'prism-sextant-second-dawn-attunement-v1': _IdentityCopy(
        'Attune the Sextant to the Second Dawn',
        'Fix the coordinates of a new horizon in the instrument.',
      ),
    },
  ),
];
