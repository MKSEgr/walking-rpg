import 'package:walking_rpg_mobile/features/activity/domain/step_reading.dart';

abstract interface class StepSource {
  Future<StepReading> read();
}
