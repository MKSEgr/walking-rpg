class HomeSnapshot {
  const HomeSnapshot({
    required this.dailySteps,
    required this.dailyGoal,
    required this.availableEnergy,
    required this.expeditionName,
    required this.expeditionProgress,
    required this.requiredEnergy,
    required this.pilotName,
    required this.pilotLevel,
    required this.petName,
    required this.petLevel,
  });

  final int dailySteps;
  final int dailyGoal;
  final int availableEnergy;
  final String expeditionName;
  final int expeditionProgress;
  final int requiredEnergy;
  final String pilotName;
  final int pilotLevel;
  final String petName;
  final int petLevel;

  double get dailyProgress {
    if (dailyGoal <= 0) {
      return 0;
    }
    return (dailySteps / dailyGoal).clamp(0.0, 1.0).toDouble();
  }

  double get expeditionProgressValue {
    if (requiredEnergy <= 0) {
      return 0;
    }
    return (expeditionProgress / requiredEnergy).clamp(0.0, 1.0).toDouble();
  }

  static const demo = HomeSnapshot(
    dailySteps: 0,
    dailyGoal: 6000,
    availableEnergy: 0,
    expeditionName: 'Сигнал из туманного сектора',
    expeditionProgress: 0,
    requiredEnergy: 30,
    pilotName: 'Навигатор',
    pilotLevel: 1,
    petName: 'Искра',
    petLevel: 1,
  );
}
