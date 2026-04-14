import 'package:flutter/services.dart';

class RfidService {
  static const MethodChannel _channel = MethodChannel('com.reon.rfid');

  Future<bool> isBluetoothEnabled() async {
    final bool? ok = await _channel.invokeMethod<bool>('isBluetoothEnabled');
    return ok ?? false;
  }

  /// Returns a list of { "address": "...", "name": "..." } maps.
  Future<List<Map<String, String>>> scanBleDevices(
      {int timeoutMs = 15000}) async {
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
    bool requireTrigger = false,
  }) async {
    final bool? ok = await _channel.invokeMethod<bool>(
      'configureReaderSession',
      {
        'frequencyMode': frequencyMode,
        'multiTagMode': multiTagMode,
        'requireTrigger': requireTrigger,
      },
    );
    return ok ?? false;
  }

  Future<Map<String, String>> readUserBank({
    required String deviceAddress,
    String? targetEpc, // optional filter
  }) async {
    final dynamic res = await _channel.invokeMethod<dynamic>(
      'readUserBank',
      {
        'deviceAddress': deviceAddress,
        if (targetEpc != null && targetEpc.isNotEmpty) 'targetEpc': targetEpc,
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
    required String targetEpc,
  }) async {
    final bool? ok = await _channel.invokeMethod<bool>(
      'writeUserBank',
      {
        'deviceAddress': deviceAddress,
        'hexUserBank': hexUserBank,
        'targetEpc': targetEpc,
      },
    );
    return ok ?? false;
  }

  Future<String> readData({
    required String deviceAddress,
    required int bank,
    required int ptr,
    required int len,
    String pwd = '00000000',
    bool useFilter = false,
    int filterBank = 1,
    int filterPtr = 32,
    int filterLen = 96,
    String filterData = '',
  }) async {
    final dynamic res = await _channel.invokeMethod<dynamic>(
      'readData',
      {
        'deviceAddress': deviceAddress,
        'bank': bank,
        'ptr': ptr,
        'len': len,
        'pwd': pwd,
        'useFilter': useFilter,
        'filterBank': filterBank,
        'filterPtr': filterPtr,
        'filterLen': filterLen,
        'filterData': filterData,
      },
    );
    return res?.toString() ?? '';
  }

  Future<bool> writeData({
    required String deviceAddress,
    required int bank,
    required int ptr,
    required int len,
    String pwd = '00000000',
    required String data,
    bool useFilter = false,
    int filterBank = 1,
    int filterPtr = 32,
    int filterLen = 96,
    String filterData = '',
  }) async {
    final bool? ok = await _channel.invokeMethod<bool>(
      'writeData',
      {
        'deviceAddress': deviceAddress,
        'bank': bank,
        'ptr': ptr,
        'len': len,
        'pwd': pwd,
        'data': data,
        'useFilter': useFilter,
        'filterBank': filterBank,
        'filterPtr': filterPtr,
        'filterLen': filterLen,
        'filterData': filterData,
      },
    );
    return ok ?? false;
  }

  Future<String> getConnectionStatus() async {
    final dynamic res =
        await _channel.invokeMethod<dynamic>('getConnectionStatus');
    return res?.toString() ?? 'DISCONNECTED';
  }
}
