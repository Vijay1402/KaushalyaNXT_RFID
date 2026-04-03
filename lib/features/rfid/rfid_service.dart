import 'package:flutter/services.dart';

class RfidService {
  static const MethodChannel _channel = MethodChannel('com.reon.rfid');

  Future<bool> isBluetoothEnabled() async {
    final bool? ok = await _channel.invokeMethod<bool>('isBluetoothEnabled');
    return ok ?? false;
  }

  /// Returns a list of { "address": "...", "name": "..." } maps.
  Future<List<Map<String, String>>> scanBleDevices({int timeoutMs = 15000}) async {
    final List<dynamic>? result = await _channel.invokeMethod<List<dynamic>>(
      'scanBleDevices',
      {'timeoutMs': timeoutMs},
    );
    if (result == null) return const [];

    return result
        .whereType<Map>()
        .map((e) => {
              'address': (e['address'] as String?) ?? '',
              'name': (e['name'] as String?) ?? '',
            })
        .toList();
  }

  Future<bool> connectDevice(String deviceAddress) async {
    final bool? ok = await _channel.invokeMethod<bool>(
      'connectDevice',
      {'deviceAddress': deviceAddress},
    );
    return ok ?? false;
  }

  Future<bool> configureReaderSession({
    required int frequencyMode,
    required bool multiTagMode,
  }) async {
    final bool? ok = await _channel.invokeMethod<bool>(
      'configureReaderSession',
      {
        'frequencyMode': frequencyMode,
        'multiTagMode': multiTagMode,
      },
    );
    return ok ?? false;
  }

  Future<Map<String, String>> readUserBank({required String deviceAddress}) async {
    final dynamic res = await _channel.invokeMethod<dynamic>(
      'readUserBank',
      {'deviceAddress': deviceAddress},
    );
    if (res is Map) {
      return res.map((key, value) => MapEntry(
            key.toString(),
            value?.toString() ?? '',
          ));
    }
    return const {};
  }

  Future<Map<String, String>> scanTagIdentity({
    required String deviceAddress,
    int timeoutMs = 5000,
  }) async {
    final dynamic res = await _channel.invokeMethod<dynamic>(
      'scanTagIdentity',
      {
        'deviceAddress': deviceAddress,
        'timeoutMs': timeoutMs,
      },
    );
    if (res is Map) {
      return res.map((key, value) => MapEntry(
            key.toString(),
            value?.toString() ?? '',
          ));
    }
    return const {};
  }

  Future<bool> writeUserBank({
    required String deviceAddress,
    required String hexUserBank,
    required String newEpcHex,
  }) async {
    final bool? ok = await _channel.invokeMethod<bool>(
      'writeUserBank',
      {
        'deviceAddress': deviceAddress,
        'hexUserBank': hexUserBank,
        'newEpcHex': newEpcHex,
      },
    );
    return ok ?? false;
  }
}

