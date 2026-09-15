import 'package:flutter_chrome_cast/entities/cast_session.dart';
import 'package:flutter_chrome_cast/enums/connection_state.dart';
import 'package:flutter_chrome_cast/models/ios/ios_cast_device.dart';

/// Represents a Google Cast session on iOS devices.
///
/// This class extends [GoogleCastSession] and provides additional
/// functionality specific to iOS, including a factory method for
/// creating an instance from a map (typically from JSON).
class IOSGoogleCastSessions extends GoogleCastSession {
  /// Creates an [IOSGoogleCastSessions] instance.
  ///
  /// All parameters are required and are passed to the superclass constructor.
  IOSGoogleCastSessions({
    required super.device,
    required super.sessionID,
    required super.connectionState,
    required super.currentDeviceMuted,
    required super.currentDeviceVolume,
    required super.deviceStatusText,
  });

  /// Creates an [IOSGoogleCastSessions] instance from a [Map] (e.g., JSON).
  ///
  /// Returns `null` if the input [json] is `null` or invalid.
  static IOSGoogleCastSessions? fromMap(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      final rawState = json['connectionState'];
      GoogleCastConnectState connState = GoogleCastConnectState.disconnected;
      if (rawState is int && rawState >= 0 && rawState < GoogleCastConnectState.values.length) {
        connState = GoogleCastConnectState.values[rawState];
      }

      final volume = (json['currentDeviceVolume'] as num?)?.toDouble() ?? 1.0;
      final muted = (json['currentDeviceMuted'] as bool?) ?? false;
      final statusText = (json['deviceStatusText'] as String?) ?? '';
      final sessionID = json['sessionID'] as String?;

      GoogleCastIosDevice? device;
      final deviceMap = json['device'];
      if (deviceMap is Map) {
        device = GoogleCastIosDevice.fromMap(Map<String, dynamic>.from(deviceMap));
      }

      return IOSGoogleCastSessions(
        device: device,
        sessionID: sessionID,
        connectionState: connState,
        currentDeviceMuted: muted,
        currentDeviceVolume: volume,
        deviceStatusText: statusText,
      );
    } catch (_) {
      return null;
    }
  }
}
