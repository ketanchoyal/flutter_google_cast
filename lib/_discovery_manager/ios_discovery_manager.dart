import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chrome_cast/entities/cast_device.dart';
import 'package:flutter_chrome_cast/models/ios/ios_cast_device.dart';
import 'package:rxdart/subjects.dart';
import 'discovery_manager_platform_interface.dart';

/// iOS-specific implementation of the Google Cast discovery manager.
///
/// This class handles the discovery of Google Cast devices on iOS platform
/// using method channels to communicate with the native iOS implementation.
class GoogleCastDiscoveryManagerMethodChannelIOS
    implements GoogleCastDiscoveryManagerPlatformInterface {
  /// Creates a new instance of the iOS discovery manager.
  ///
  /// Sets up the method call handler to receive updates from the native side.
  GoogleCastDiscoveryManagerMethodChannelIOS() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  final _channel = const MethodChannel('google_cast.discovery_manager');

  final _devicesStreamController = BehaviorSubject<List<GoogleCastDevice>>()
    ..add([]);

  final _logStreamController = BehaviorSubject<String>();

  @override
  List<GoogleCastDevice> get devices => _devicesStreamController.value;

  @override
  Stream<List<GoogleCastDevice>> get devicesStream =>
      _devicesStreamController.stream;

  @override
  Stream<String> get logStream => _logStreamController.stream;

  @override
  Future<bool> isDiscoveryActiveForDeviceCategory(String deviceCategory) async {
    return await _channel.invokeMethod('isDiscoveryActiveForDeviceCategory', {
      'deviceCategory': deviceCategory,
    });
  }

  @override
  Future<void> startDiscovery() {
    return _channel.invokeMethod('startDiscovery');
  }

  @override
  Future<void> stopDiscovery() {
    return _channel.invokeMethod('stopDiscovery');
  }

  @override
  Future<List<GoogleCastDevice>> getDevices() async {
    try {
      final result = await _channel.invokeListMethod<dynamic>('getDevices');
      if (result != null) {
        _onDevicesChanged(result);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[GoogleCastDiscoveryManagerIOS] Error invoking getDevices: $e');
      }
    }
    return devices;
  }

  /// Queries the current native discovery manager state and cached devices count.
  Future<Map<String, dynamic>?> getDiscoveryStatus() async {
    return await _channel.invokeMapMethod<String, dynamic>('getDiscoveryStatus');
  }

  /// Queries the recent native Cast SDK diagnostic logs.
  Future<List<String>> getRecentLogs() async {
    final result = await _channel.invokeListMethod<String>('getRecentLogs');
    return result ?? [];
  }

  /// Handles device changes for testing purposes.
  /// This method is visible for testing and allows simulating device changes
  /// in unit tests by calling the internal [_onDevicesChanged] method.
  @visibleForTesting
  void onDevicesChanged(List arguments) {
    _onDevicesChanged(arguments);
  }

  /// Handles method calls from the platform channel for testing purposes.
  /// This method is visible for testing and allows simulating platform
  /// method calls in unit tests.
  @visibleForTesting
  Future<void> handleMethodCall(MethodCall call) {
    return _handleMethodCall(call);
  }

  void _onDevicesChanged(dynamic arguments) {
    if (arguments == null || arguments is! List) return;
    try {
      final parsedDevices = <GoogleCastDevice>[];
      for (final item in arguments) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          parsedDevices.add(GoogleCastIosDevice.fromMap(map));
        }
      }

      _devicesStreamController.add(parsedDevices);
    } catch (e, stack) {
      if (kDebugMode) {
        print('[GoogleCastDiscoveryManagerIOS] Error parsing device list: $e\n$stack');
      }
    }
  }

  Future _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onDevicesChanged':
        _onDevicesChanged(call.arguments);
        break;
      case 'onNativeLog':
        if (call.arguments is String) {
          _logStreamController.add(call.arguments as String);
        }
        break;
      default:
        if (kDebugMode) {
          print('No Handler for method ${call.method}');
        }
    }
  }
}
