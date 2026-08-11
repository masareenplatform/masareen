import 'package:permission_handler/permission_handler.dart';

/// Requests the device permissions MASAREEN needs (camera for evidence,
/// location for GPS proof, notifications for alerts). On Android these surface
/// as the standard system grant dialogs the first time the user reaches the
/// home feed; once granted they never prompt again.
class PermissionService {
  static final PermissionService instance = PermissionService._();
  PermissionService._();

  Future<void> requestAll() async {
    await [
      Permission.camera,
      Permission.locationWhenInUse,
      Permission.notification,
    ].request();
  }
}



