import 'package:walking_rpg_mobile/core/commands/mobile_command.dart';

abstract interface class MobileCommandStore {
  Future<List<MobileCommand>> load();

  Future<void> save(List<MobileCommand> commands);
}
