import 'package:flutter_chrome_cast/entities/cast_device.dart';

/// Represents a Google Cast device specific to iOS platforms.
///
/// This class extends [GoogleCastDevice] to include iOS-specific properties
/// and construction from a map structure typically returned by iOS platform channels.
class GoogleCastIosDevice extends GoogleCastDevice {
  /// Optional index of the device in the iOS discovery list.
  final int? index;

  /// Creates a new [GoogleCastIosDevice] instance.
  ///
  /// All parameters except [index] are required and are passed to the base [GoogleCastDevice].
  GoogleCastIosDevice({
    required super.deviceID,
    required super.friendlyName,
    required super.modelName,
    required super.statusText,
    required super.deviceVersion,
    required super.isOnLocalNetwork,
    required super.category,
    required super.uniqueID,
    required this.index,
  });

  /// Creates a [GoogleCastIosDevice] from a map, typically from platform channel data.
  factory GoogleCastIosDevice.fromMap(Map<String, dynamic> map) {
    final devId = (map['deviceID'] as String?) ?? '';
    final friendly = (map['friendlyName'] as String?)?.trim();
    final model = map['modelName'] as String?;
    final resolvedFriendlyName = (friendly != null && friendly.isNotEmpty)
        ? friendly
        : (model != null && model.isNotEmpty)
            ? model
            : 'Cast Device';

    return GoogleCastIosDevice(
      deviceID: devId,
      friendlyName: resolvedFriendlyName,
      modelName: model,
      statusText: map['statusText'] as String?,
      deviceVersion: (map['deviceVersion'] as String?) ?? '',
      isOnLocalNetwork: (map['isOnLocalNetwork'] as bool?) ?? true,
      category: (map['category'] as String?) ?? '',
      uniqueID: (map['uniqueID'] as String?) ?? devId,
      index: map['index'] as int?,
    );
  }
}
