// lib/services/device_info_service.dart
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceInfoService {
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  static const String _deviceIdentifierKey = 'unique_device_identifier';

  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdentifierKey);

    if (deviceId == null || deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdentifierKey, deviceId);
      print('Generated and stored new device ID: $deviceId');
    } else {
      print('Retrieved existing device ID: $deviceId');
    }
    return deviceId;
  }

  Future<String> getDeviceModelName() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfoPlugin.androidInfo;
        return "${androidInfo.manufacturer} ${androidInfo.model}";
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfoPlugin.iosInfo;
        return iosInfo.name ?? iosInfo.model ?? "iOS Device";
      }
    } catch (e) {
      print("Failed to get device model name: $e");
    }
    return "Unknown Device";
  }
}
