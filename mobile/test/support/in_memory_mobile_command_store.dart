import 'package:walking_rpg_mobile/core/commands/mobile_command.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_store.dart';

final class InMemoryMobileCommandStore implements MobileCommandStore {
  InMemoryMobileCommandStore([
    Iterable<MobileCommand> initial = const <MobileCommand>[],
  ]) : _commands = <MobileCommand>[...initial];

  List<MobileCommand> _commands;

  List<MobileCommand> get snapshot =>
      List<MobileCommand>.unmodifiable(_commands);

  @override
  Future<List<MobileCommand>> load() async {
    return <MobileCommand>[..._commands];
  }

  @override
  Future<void> save(List<MobileCommand> commands) async {
    _commands = <MobileCommand>[...commands];
  }

  @override
  Future<void> deleteOwner(String ownerId) async {
    _commands = _commands
        .where((MobileCommand command) => command.ownerId != ownerId)
        .toList(growable: false);
  }
}
