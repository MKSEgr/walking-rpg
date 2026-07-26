import 'package:permission_handler/permission_handler.dart';

enum ActivityRecognitionPermissionState {
  granted,
  denied,
  permanentlyDenied,
  restricted,
}

abstract interface class ActivityRecognitionGateway {
  Future<ActivityRecognitionPermissionState> check();

  Future<ActivityRecognitionPermissionState> request();
}

class PermissionHandlerActivityRecognitionGateway
    implements ActivityRecognitionGateway {
  const PermissionHandlerActivityRecognitionGateway();

  @override
  Future<ActivityRecognitionPermissionState> check() async {
    return _map(await Permission.activityRecognition.status);
  }

  @override
  Future<ActivityRecognitionPermissionState> request() async {
    return _map(await Permission.activityRecognition.request());
  }

  ActivityRecognitionPermissionState _map(PermissionStatus status) {
    if (status.isGranted) {
      return ActivityRecognitionPermissionState.granted;
    }
    if (status.isPermanentlyDenied) {
      return ActivityRecognitionPermissionState.permanentlyDenied;
    }
    if (status.isRestricted) {
      return ActivityRecognitionPermissionState.restricted;
    }
    return ActivityRecognitionPermissionState.denied;
  }
}

class NoopActivityRecognitionGateway implements ActivityRecognitionGateway {
  const NoopActivityRecognitionGateway();

  @override
  Future<ActivityRecognitionPermissionState> check() async {
    return ActivityRecognitionPermissionState.granted;
  }

  @override
  Future<ActivityRecognitionPermissionState> request() async {
    return ActivityRecognitionPermissionState.granted;
  }
}
