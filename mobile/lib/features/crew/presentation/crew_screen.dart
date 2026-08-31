import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/cache/cached_snapshot_banner.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/core/localization/current_content_localizations.dart';
import 'package:walking_rpg_mobile/core/localization/current_platform_content_localizations.dart';
import 'package:walking_rpg_mobile/core/localization/mandatory_journey_localizations.dart';
import 'package:walking_rpg_mobile/core/navigation/navigation_chrome_insets.dart';
import 'package:walking_rpg_mobile/design_system/companion_portrait.dart';
import 'package:walking_rpg_mobile/design_system/expedition_read_state.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/pilot_portrait.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/home/data/home_api_client.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/platform/data/platform_api_client.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_command_result.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';
import 'package:walking_rpg_mobile/features/recovery/presentation/mobile_command_recovery_action.dart';

typedef CrewSnapshotLoader = Future<PlatformSnapshot> Function();
typedef CrewHomeLoader = Future<HomeSnapshot> Function();
typedef CrewCommandExecutor =
    Future<PlatformCommandResult> Function({
      required String commandType,
      required Map<String, Object?> payload,
      required String idempotencyKey,
    });
typedef CrewIdempotencyKeyFactory = String Function(String commandType);

enum _CrewAppAction { refresh, account }

class CrewScreen extends StatefulWidget {
  const CrewScreen({
    super.key,
    this.loader,
    this.homeLoader,
    this.commandExecutor,
    this.idempotencyKeyFactory,
    this.onServerStateChanged,
    this.onOpenAccount,
    this.onOpenRecovery,
    this.recoveryCount = 0,
    this.recoveryUnavailable = false,
    this.authoritativeRefreshGeneration = 0,
  });

  final CrewSnapshotLoader? loader;
  final CrewHomeLoader? homeLoader;
  final CrewCommandExecutor? commandExecutor;
  final CrewIdempotencyKeyFactory? idempotencyKeyFactory;
  final VoidCallback? onServerStateChanged;
  final VoidCallback? onOpenAccount;
  final VoidCallback? onOpenRecovery;
  final int recoveryCount;
  final bool recoveryUnavailable;
  final int authoritativeRefreshGeneration;

  @override
  State<CrewScreen> createState() => _CrewScreenState();
}

class _CrewScreenState extends State<CrewScreen> {
  late Future<_CrewViewData> _dataFuture;
  String? _busyCommand;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  @override
  void didUpdateWidget(CrewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loader != widget.loader ||
        oldWidget.homeLoader != widget.homeLoader ||
        oldWidget.authoritativeRefreshGeneration !=
            widget.authoritativeRefreshGeneration) {
      _dataFuture = _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool compactChrome =
        MediaQuery.sizeOf(context).width < 380 ||
        MediaQuery.textScalerOf(context).scale(16) > 21;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          compactChrome
              ? context.l10n.navigationCrewLabel
              : context.l10n.crewTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          MobileCommandRecoveryAction(
            key: const Key('crew-command-recovery'),
            onPressed: widget.onOpenRecovery,
            count: widget.recoveryCount,
            unavailable: widget.recoveryUnavailable,
          ),
          if (compactChrome)
            _CrewAppActionsMenu(
              refreshEnabled: _busyCommand == null,
              onRefresh: _reload,
              onOpenAccount: widget.onOpenAccount,
            )
          else ...<Widget>[
            IconButton(
              tooltip: context.l10n.homeRefreshTooltip,
              onPressed: _busyCommand == null ? _reload : null,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: context.l10n.accountTooltip,
              onPressed: widget.onOpenAccount,
              icon: const Icon(Icons.account_circle_outlined),
            ),
          ],
        ],
      ),
      body: ExpeditionBackdrop(
        child: SafeArea(
          child: FutureBuilder<_CrewViewData>(
            future: _dataFuture,
            builder:
                (BuildContext context, AsyncSnapshot<_CrewViewData> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ExpeditionReadState.loading(
                      key: const Key('crew-loading-state'),
                      title: context.l10n.crewLoadingTitle,
                      message: context.l10n.crewLoadingMessage,
                    );
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return ExpeditionReadState.failure(
                      key: const Key('crew-error-state'),
                      title: context.l10n.crewLoadFailureTitle,
                      message: context.l10n.crewLoadFailureMessage,
                      details:
                          snapshot.error?.toString() ??
                          context.l10n.platformMissingSnapshotDetails,
                      primaryActionKey: const Key('crew-retry'),
                      primaryActionLabel: context.l10n.crewRefresh,
                      onPrimaryAction: _reload,
                    );
                  }
                  return _CrewBody(
                    data: snapshot.data!,
                    busy: _busyCommand != null,
                    onCommand: _executeCommand,
                    onRefresh: _reload,
                  );
                },
          ),
        ),
      ),
    );
  }

  Future<_CrewViewData> _loadData() async {
    final CrewSnapshotLoader platformLoader =
        widget.loader ?? PlatformApiClient.fromEnvironment().fetchSnapshot;
    final CrewHomeLoader homeLoader =
        widget.homeLoader ??
        () => HomeApiClient.fromEnvironment().fetchHome(DateTime.now());
    final List<Object> snapshots = await Future.wait<Object>(<Future<Object>>[
      platformLoader(),
      homeLoader(),
    ]);
    return _CrewViewData(
      platform: snapshots[0] as PlatformSnapshot,
      home: snapshots[1] as HomeSnapshot,
    );
  }

  Future<void> _executeCommand(
    String commandType,
    Map<String, Object?> payload,
  ) async {
    if (_busyCommand != null) {
      return;
    }
    final CrewCommandExecutor executor =
        widget.commandExecutor ?? PlatformApiClient.fromEnvironment().execute;
    setState(() {
      _busyCommand = commandType;
    });
    try {
      final _CrewViewData currentData = await _dataFuture;
      final PlatformCommandResult result = await executor(
        commandType: commandType,
        payload: payload,
        idempotencyKey: _nextKey(commandType),
      );
      final CrewHomeLoader homeLoader =
          widget.homeLoader ??
          () => HomeApiClient.fromEnvironment().fetchHome(DateTime.now());
      final HomeSnapshot home = await _refreshHomeOrFallback(
        homeLoader,
        currentData.home,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _dataFuture = Future<_CrewViewData>.value(
          _CrewViewData(platform: result.snapshot, home: home),
        );
      });
      widget.onServerStateChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.currentPlatformCommandMessage(
              result.commandType,
              result.message,
            ),
          ),
        ),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.platformCommandFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyCommand = null;
        });
      }
    }
  }

  Future<HomeSnapshot> _refreshHomeOrFallback(
    CrewHomeLoader loader,
    HomeSnapshot fallback,
  ) async {
    try {
      return await loader();
    } on Object {
      // The command was already accepted by the server. Keep the last Home
      // snapshot instead of reporting a mutation failure or inviting a
      // duplicate retry with a new idempotency key.
      return fallback;
    }
  }

  String _nextKey(String commandType) {
    return widget.idempotencyKeyFactory?.call(commandType) ??
        '${commandType.toLowerCase()}-'
            '${DateTime.now().toUtc().microsecondsSinceEpoch}';
  }

  void _reload() {
    if (_busyCommand != null) {
      return;
    }
    setState(() {
      _dataFuture = _loadData();
    });
  }
}

class _CrewViewData {
  const _CrewViewData({required this.platform, required this.home});

  final PlatformSnapshot platform;
  final HomeSnapshot home;

  bool get isReadOnly => platform.isCached;
}

class _CrewBody extends StatelessWidget {
  const _CrewBody({
    required this.data,
    required this.busy,
    required this.onCommand,
    required this.onRefresh,
  });

  final _CrewViewData data;
  final bool busy;
  final void Function(String commandType, Map<String, Object?> payload)
  onCommand;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final PlatformSnapshot platform = data.platform;
    final HomeSnapshot home = data.home;
    final PlatformPet activePet = platform.activePet;
    final Set<String> equippedCosmeticIds =
        platform.userState.equippedCosmeticIds;
    final List<PlatformSkill> unlockedSkills = platform.content.skills
        .where(
          (PlatformSkill skill) =>
              platform.userState.unlockedSkills.contains(skill.skillId),
        )
        .toList(growable: false);
    final List<HomeEquipmentSlot> equippedSlots = home.equipment
        .where((HomeEquipmentSlot slot) => slot.isEquipped)
        .toList(growable: false);
    final List<PlatformCosmetic> crewCosmetics = platform.content.cosmetics
        .where(
          (PlatformCosmetic cosmetic) =>
              cosmetic.slot == 'PILOT' || cosmetic.slot == 'PET',
        )
        .toList(growable: false);
    final bool blocked = busy || data.isReadOnly;
    final cacheMetadata = platform.cacheMetadata ?? home.cacheMetadata;
    final double bottomDockInset = NavigationChromeInsets.bottomDockInsetOf(
      context,
    );

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        key: const Key('crew-screen-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 16, 16, 36 + bottomDockInset),
        children: <Widget>[
          if (cacheMetadata != null) ...<Widget>[
            CachedSnapshotBanner(metadata: cacheMetadata),
            const SizedBox(height: 12),
          ],
          _CrewHero(
            home: home,
            pet: activePet,
            cosmetics: platform.content.cosmetics,
            equippedCosmeticIds: equippedCosmeticIds,
          ),
          const SizedBox(height: 16),
          _SectionHeading(
            title: context.l10n.homePilotLabel,
            subtitle: context.l10n.crewPilotSubtitle,
            icon: Icons.explore_outlined,
          ),
          const SizedBox(height: 8),
          _PilotCard(
            home: home,
            skills: unlockedSkills,
            equippedCosmeticIds: equippedCosmeticIds,
          ),
          const SizedBox(height: 16),
          _SectionHeading(
            title: context.l10n.homeActiveCompanion,
            subtitle: context.l10n.crewActivePetSubtitle,
            icon: Icons.pets_outlined,
          ),
          const SizedBox(height: 8),
          _ActivePetCard(
            pet: activePet,
            equippedCosmeticIds: equippedCosmeticIds,
            busy: blocked,
            onEvolve: () => onCommand('EVOLVE_PET', <String, Object?>{
              'petId': activePet.petId,
            }),
          ),
          const SizedBox(height: 16),
          _SectionHeading(
            title: context.l10n.platformPetsTitle,
            subtitle: context.l10n.platformPetsSubtitle,
            icon: Icons.diversity_1_outlined,
          ),
          const SizedBox(height: 8),
          for (final PlatformPet pet in platform.userState.pets) ...<Widget>[
            _PetRosterCard(
              pet: pet,
              equippedCosmeticIds: equippedCosmeticIds,
              busy: blocked,
              onSelect: () => onCommand('SELECT_PET', <String, Object?>{
                'petId': pet.petId,
              }),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          _SectionHeading(
            title: context.l10n.platformSkillsTitle,
            subtitle: context.l10n.platformSkillsSubtitle,
            icon: Icons.hub_outlined,
          ),
          const SizedBox(height: 8),
          _SkillsPanel(skills: unlockedSkills),
          const SizedBox(height: 16),
          _SectionHeading(
            title: context.l10n.homeEquipmentTitle,
            subtitle: context.l10n.homeEquipmentSubtitle,
            icon: Icons.backpack_outlined,
          ),
          const SizedBox(height: 8),
          _EquipmentPanel(slots: equippedSlots),
          const SizedBox(height: 16),
          _SectionHeading(
            title: context.l10n.crewAppearanceTitle,
            subtitle: context.l10n.crewAppearanceSubtitle,
            icon: Icons.auto_awesome_outlined,
          ),
          const SizedBox(height: 8),
          if (crewCosmetics.isEmpty)
            ExpeditionPanel(child: Text(context.l10n.crewAppearanceEmpty))
          else
            for (final PlatformCosmetic cosmetic in crewCosmetics) ...<Widget>[
              _CosmeticCard(
                cosmetic: cosmetic,
                owned: platform.userState.ownedCosmetics.contains(
                  cosmetic.cosmeticId,
                ),
                active: equippedCosmeticIds.contains(cosmetic.cosmeticId),
                busy: blocked,
                onEquip: () => onCommand('EQUIP_COSMETIC', <String, Object?>{
                  'cosmeticId': cosmetic.cosmeticId,
                }),
              ),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('crew-refresh'),
            onPressed: busy ? null : onRefresh,
            icon: const Icon(Icons.sync),
            label: Text(context.l10n.crewRefresh),
          ),
        ],
      ),
    );
  }
}

class _CrewHero extends StatelessWidget {
  const _CrewHero({
    required this.home,
    required this.pet,
    required this.cosmetics,
    required this.equippedCosmeticIds,
  });

  final HomeSnapshot home;
  final PlatformPet pet;
  final List<PlatformCosmetic> cosmetics;
  final Set<String> equippedCosmeticIds;

  @override
  Widget build(BuildContext context) {
    final String pilotName = context.l10n.currentPilotName(
      home.pilotId ?? 'navigator-v1',
      home.pilotName,
    );
    final String petName = context.l10n.currentPetName(pet.petId, pet.name);
    final String petSpecies = context.l10n.currentPetSpecies(
      pet.petId,
      pet.species,
    );
    final List<String> equippedNames = cosmetics
        .where(
          (PlatformCosmetic cosmetic) =>
              equippedCosmeticIds.contains(cosmetic.cosmeticId),
        )
        .map(
          (PlatformCosmetic cosmetic) => context.l10n
              .currentPlatformCosmeticName(cosmetic.cosmeticId, cosmetic.name),
        )
        .toList(growable: false);
    return ExpeditionPanel(
      key: const Key('crew-hero'),
      tone: ExpeditionPanelTone.resonance,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -72,
              right: -44,
              child: _CrewGlowOrb(
                color: context.walkingRpgPalette.resonance,
                size: 190,
              ),
            ),
            Positioned(
              bottom: -88,
              left: -64,
              child: _CrewGlowOrb(
                color: context.walkingRpgPalette.energy,
                size: 180,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ExpeditionBadge(
                    label: context.l10n.crewOverviewBadge,
                    icon: Icons.route_outlined,
                    tone: ExpeditionPanelTone.resonance,
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final Widget portraits = _CrewPortraitStage(
                            pilotName: pilotName,
                            pet: pet,
                            petName: petName,
                            petSpecies: petSpecies,
                            equippedCosmeticIds: equippedCosmeticIds,
                          );
                          final Widget copy = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                context.l10n.platformCrewTitle(petName),
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                equippedNames.isEmpty
                                    ? context.l10n.platformNoActiveCosmetics
                                    : context.l10n.platformEquippedCosmetics(
                                        equippedNames.join(' · '),
                                      ),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  _CrewMetric(
                                    icon: Icons.navigation_outlined,
                                    label: context.l10n.homePilotLabel,
                                    value: '${home.pilotLevel}',
                                    color: context.walkingRpgPalette.energy,
                                  ),
                                  _CrewMetric(
                                    icon: Icons.favorite_outline,
                                    label: context.l10n.platformBondLabel,
                                    value: '${pet.bond}',
                                    color: context.walkingRpgPalette.resonance,
                                  ),
                                  _CrewMetric(
                                    icon: Icons.auto_awesome_outlined,
                                    label: context.l10n.homeActiveCompanion,
                                    value: context.l10n.companionFormLabel(
                                      pet.evolutionStage,
                                    ),
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ],
                              ),
                            ],
                          );
                          if (constraints.maxWidth < 420) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                portraits,
                                const SizedBox(height: 14),
                                copy,
                              ],
                            );
                          }
                          return Row(
                            children: <Widget>[
                              portraits,
                              const SizedBox(width: 18),
                              Expanded(child: copy),
                            ],
                          );
                        },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrewPortraitStage extends StatelessWidget {
  const _CrewPortraitStage({
    required this.pilotName,
    required this.pet,
    required this.petName,
    required this.petSpecies,
    required this.equippedCosmeticIds,
  });

  final String pilotName;
  final PlatformPet pet;
  final String petName;
  final String petSpecies;
  final Set<String> equippedCosmeticIds;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('crew-portrait-stage'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: context.walkingRpgPalette.resonance.withValues(alpha: 0.34),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PilotPortrait(
              key: const Key('crew-pilot-portrait'),
              name: pilotName,
              size: 86,
              highlighted: true,
              equippedCosmeticIds: equippedCosmeticIds,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 30,
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          context.walkingRpgPalette.energy,
                          context.walkingRpgPalette.resonance,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.link,
                    size: 17,
                    color: context.walkingRpgPalette.resonance,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 30,
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          context.walkingRpgPalette.energy,
                          context.walkingRpgPalette.resonance,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            CompanionPortrait(
              key: const Key('crew-active-pet-portrait'),
              petId: pet.petId,
              name: petName,
              species: petSpecies,
              evolutionStage: pet.evolutionStage,
              active: true,
              size: 86,
              equippedCosmeticIds: equippedCosmeticIds,
            ),
          ],
        ),
      ),
    );
  }
}

class _CrewMetric extends StatelessWidget {
  const _CrewMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '$label · $value',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrewGlowOrb extends StatelessWidget {
  const _CrewGlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color.withValues(alpha: 0.2),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _PilotCard extends StatelessWidget {
  const _PilotCard({
    required this.home,
    required this.skills,
    required this.equippedCosmeticIds,
  });

  final HomeSnapshot home;
  final List<PlatformSkill> skills;
  final Set<String> equippedCosmeticIds;

  @override
  Widget build(BuildContext context) {
    final String pilotName = context.l10n.currentPilotName(
      home.pilotId ?? 'navigator-v1',
      home.pilotName,
    );
    return ExpeditionPanel(
      key: const Key('crew-pilot-card'),
      tone: ExpeditionPanelTone.lumen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PilotPortrait(
                name: pilotName,
                size: 68,
                equippedCosmeticIds: equippedCosmeticIds,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      pilotName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      context.l10n.platformJourneyPilotProgression(
                        home.pilotLevel,
                        home.pilotCurrentExperience,
                        home.pilotNextLevelExperience,
                        home.remainingPilotExperience,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Icon(
                Icons.bolt_outlined,
                size: 17,
                color: context.walkingRpgPalette.energy,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  context.l10n.homePilotExperienceProgress(
                    home.pilotCurrentExperience,
                    home.pilotNextLevelExperience,
                    home.remainingPilotExperience,
                  ),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: context.l10n.homePilotExperienceProgress(
              home.pilotCurrentExperience,
              home.pilotNextLevelExperience,
              home.remainingPilotExperience,
            ),
            child: LinearProgressIndicator(
              key: const Key('crew-pilot-xp-progress'),
              value: home.pilotExperienceProgress,
              minHeight: 9,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          if (skills.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: <Widget>[
                for (final PlatformSkill skill in skills)
                  Chip(
                    avatar: const Icon(Icons.bolt_outlined, size: 18),
                    label: Text(
                      context.l10n.currentPlatformSkillName(
                        skill.skillId,
                        skill.name,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivePetCard extends StatelessWidget {
  const _ActivePetCard({
    required this.pet,
    required this.equippedCosmeticIds,
    required this.busy,
    required this.onEvolve,
  });

  final PlatformPet pet;
  final Set<String> equippedCosmeticIds;
  final bool busy;
  final VoidCallback onEvolve;

  @override
  Widget build(BuildContext context) {
    final String petName = context.l10n.currentPetName(pet.petId, pet.name);
    final String petSpecies = context.l10n.currentPetSpecies(
      pet.petId,
      pet.species,
    );
    final double bondProgress = pet.isFullyEvolved
        ? 1.0
        : (pet.bond / pet.evolutionBond).clamp(0.0, 1.0).toDouble();
    return ExpeditionPanel(
      key: const Key('crew-active-pet-card'),
      tone: ExpeditionPanelTone.resonance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CompanionPortrait(
                petId: pet.petId,
                name: petName,
                species: petSpecies,
                evolutionStage: pet.evolutionStage,
                active: true,
                size: 82,
                equippedCosmeticIds: equippedCosmeticIds,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.platformPetLevelSemantics(
                        petName,
                        pet.level,
                      ),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$petSpecies · '
                      '${context.l10n.companionFormLabel(pet.evolutionStage)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ExpeditionBadge(
                      label: context.l10n.platformInSquadBadge,
                      icon: Icons.check_circle_outline,
                      tone: ExpeditionPanelTone.resonance,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Icon(
                Icons.favorite_outline,
                size: 17,
                color: context.walkingRpgPalette.resonance,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${context.l10n.platformBondLabel}: ${pet.bond}'
                  '${pet.isFullyEvolved ? '' : ' / ${pet.evolutionBond}'}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            key: const Key('crew-pet-bond-progress'),
            value: bondProgress,
            minHeight: 9,
            borderRadius: BorderRadius.circular(99),
          ),
          if (pet.canEvolve) ...<Widget>[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: Key('crew-evolve-pet-${pet.petId}'),
              onPressed: busy ? null : onEvolve,
              icon: const Icon(Icons.auto_awesome),
              label: Text(context.l10n.platformEvolveCompanion),
            ),
          ],
        ],
      ),
    );
  }
}

class _PetRosterCard extends StatelessWidget {
  const _PetRosterCard({
    required this.pet,
    required this.equippedCosmeticIds,
    required this.busy,
    required this.onSelect,
  });

  final PlatformPet pet;
  final Set<String> equippedCosmeticIds;
  final bool busy;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final String petName = context.l10n.currentPetName(pet.petId, pet.name);
    final String petSpecies = context.l10n.currentPetSpecies(
      pet.petId,
      pet.species,
    );
    final Widget portrait = CompanionPortrait(
      petId: pet.petId,
      name: petName,
      species: petSpecies,
      evolutionStage: pet.evolutionStage,
      active: pet.active,
      size: 58,
      equippedCosmeticIds: equippedCosmeticIds,
    );
    final Widget details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.platformCompanionLevelShort(petName, pet.level),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 3),
        Text(
          '$petSpecies · ${context.l10n.platformBondLabel} ${pet.bond}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final Widget status = pet.active
        ? Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          )
        : FilledButton.tonal(
            key: Key('crew-select-pet-${pet.petId}'),
            onPressed: busy ? null : onSelect,
            child: Text(context.l10n.platformSelectCompanion),
          );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact =
            constraints.maxWidth < 390 ||
            MediaQuery.textScalerOf(context).scale(16) > 21;
        return ExpeditionPanel(
          key: Key('crew-pet-${pet.petId}'),
          tone: pet.active
              ? ExpeditionPanelTone.lumen
              : ExpeditionPanelTone.neutral,
          padding: const EdgeInsets.all(14),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        portrait,
                        const SizedBox(width: 12),
                        Expanded(child: details),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (pet.active)
                      Align(alignment: Alignment.centerLeft, child: status)
                    else
                      SizedBox(width: double.infinity, child: status),
                  ],
                )
              : Row(
                  children: <Widget>[
                    portrait,
                    const SizedBox(width: 12),
                    Expanded(child: details),
                    const SizedBox(width: 8),
                    status,
                  ],
                ),
        );
      },
    );
  }
}

class _SkillsPanel extends StatelessWidget {
  const _SkillsPanel({required this.skills});

  final List<PlatformSkill> skills;

  @override
  Widget build(BuildContext context) {
    return ExpeditionPanel(
      key: const Key('crew-skills-card'),
      child: skills.isEmpty
          ? Text(context.l10n.crewSkillsEmpty)
          : Column(
              children: <Widget>[
                for (
                  int index = 0;
                  index < skills.length;
                  index += 1
                ) ...<Widget>[
                  _SkillRow(skill: skills[index]),
                  if (index != skills.length - 1) const Divider(height: 22),
                ],
              ],
            ),
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({required this.skill});

  final PlatformSkill skill;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.bolt_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.currentPlatformSkillName(
                  skill.skillId,
                  skill.name,
                ),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 3),
              Text(
                context.l10n.currentPlatformSkillDescription(
                  skill.skillId,
                  skill.description,
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EquipmentPanel extends StatelessWidget {
  const _EquipmentPanel({required this.slots});

  final List<HomeEquipmentSlot> slots;

  @override
  Widget build(BuildContext context) {
    return ExpeditionPanel(
      key: const Key('crew-equipment-card'),
      child: slots.isEmpty
          ? Text(context.l10n.crewEquipmentEmpty)
          : Column(
              children: <Widget>[
                for (
                  int index = 0;
                  index < slots.length;
                  index += 1
                ) ...<Widget>[
                  _EquipmentRow(slot: slots[index]),
                  if (index != slots.length - 1) const Divider(height: 22),
                ],
              ],
            ),
    );
  }
}

class _EquipmentRow extends StatelessWidget {
  const _EquipmentRow({required this.slot});

  final HomeEquipmentSlot slot;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.explore_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                slot.item == null
                    ? context.l10n.currentEquipmentSlotName(
                        slot.slotId,
                        slot.name,
                      )
                    : context.l10n.currentItemName(
                        slot.item!.itemId,
                        slot.item!.name,
                      ),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 3),
              Text(
                slot.item == null
                    ? context.l10n.currentEquipmentSlotDescription(
                        slot.slotId,
                        slot.description,
                      )
                    : context.l10n.currentItemDescription(
                        slot.item!.itemId,
                        slot.item!.description,
                      ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CosmeticCard extends StatelessWidget {
  const _CosmeticCard({
    required this.cosmetic,
    required this.owned,
    required this.active,
    required this.busy,
    required this.onEquip,
  });

  final PlatformCosmetic cosmetic;
  final bool owned;
  final bool active;
  final bool busy;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    final String name = context.l10n.currentPlatformCosmeticName(
      cosmetic.cosmeticId,
      cosmetic.name,
    );
    final String slot = cosmetic.slot == 'PILOT'
        ? context.l10n.platformCosmeticPilotSlot
        : context.l10n.platformCosmeticPetSlot;
    final Widget icon = CircleAvatar(
      backgroundColor: context.walkingRpgPalette.resonance.withValues(
        alpha: 0.14,
      ),
      child: Icon(
        cosmetic.slot == 'PILOT' ? Icons.explore_outlined : Icons.pets_outlined,
      ),
    );
    final Widget details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(name, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 3),
        Text(
          slot,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final Widget status = active
        ? Chip(label: Text(context.l10n.platformCosmeticEquipped))
        : owned
        ? FilledButton.tonal(
            key: Key('crew-equip-cosmetic-${cosmetic.cosmeticId}'),
            onPressed: busy ? null : onEquip,
            child: Text(context.l10n.platformEquipCosmetic),
          )
        : Tooltip(
            message: context.l10n.crewAppearanceLocked,
            child: const Icon(Icons.lock_outline),
          );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact =
            constraints.maxWidth < 390 ||
            MediaQuery.textScalerOf(context).scale(16) > 21;
        return ExpeditionPanel(
          key: Key('crew-cosmetic-${cosmetic.cosmeticId}'),
          tone: active
              ? ExpeditionPanelTone.resonance
              : ExpeditionPanelTone.neutral,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        icon,
                        const SizedBox(width: 12),
                        Expanded(child: details),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerLeft, child: status),
                  ],
                )
              : Row(
                  children: <Widget>[
                    icon,
                    const SizedBox(width: 12),
                    Expanded(child: details),
                    const SizedBox(width: 8),
                    status,
                  ],
                ),
        );
      },
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: <Color>[
            accent.withValues(alpha: 0.12),
            accent.withValues(alpha: 0),
          ],
        ),
        border: Border(
          left: BorderSide(color: accent.withValues(alpha: 0.72), width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CrewAppActionsMenu extends StatelessWidget {
  const _CrewAppActionsMenu({
    required this.refreshEnabled,
    required this.onRefresh,
    required this.onOpenAccount,
  });

  final bool refreshEnabled;
  final VoidCallback onRefresh;
  final VoidCallback? onOpenAccount;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_CrewAppAction>(
      key: const Key('crew-more-actions'),
      tooltip: context.l10n.moreActionsTooltip,
      icon: const Icon(Icons.more_vert),
      onSelected: (_CrewAppAction action) {
        switch (action) {
          case _CrewAppAction.refresh:
            onRefresh();
            break;
          case _CrewAppAction.account:
            onOpenAccount?.call();
            break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<_CrewAppAction>>[
        PopupMenuItem<_CrewAppAction>(
          key: const Key('crew-menu-refresh'),
          value: _CrewAppAction.refresh,
          enabled: refreshEnabled,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.refresh),
            title: Text(context.l10n.crewRefresh),
          ),
        ),
        PopupMenuItem<_CrewAppAction>(
          key: const Key('crew-menu-account'),
          value: _CrewAppAction.account,
          enabled: onOpenAccount != null,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(context.l10n.accountTooltip),
          ),
        ),
      ],
    );
  }
}
