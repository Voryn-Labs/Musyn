import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// User-supplied provider material lives in Keychain, never Hive or logs.
class ProviderAccess extends ChangeNotifier {
  ProviderAccess({
    this.channel = const MethodChannel('com.vorynlabs.musyn/provider_access'),
  });
  static final instance = ProviderAccess();
  final MethodChannel channel;
  String? _key;
  String redact(String text) =>
      _key == null ? text : text.replaceAll(_key!, '[provider key redacted]');
  bool get configured => _key != null;
  List<int>? get mediaKey => _key == null ? null : utf8.encode(_key!);

  Future<void> initialize() async {
    try {
      final value = await channel.invokeMethod<String>('read');
      _key = value != null && utf8.encode(value).length == 8 ? value : null;
    } on PlatformException {
      _key = null;
    } on MissingPluginException {
      _key = null;
    }
    notifyListeners();
  }

  Future<void> save(String value) async {
    if (utf8.encode(value).length != 8) {
      throw const FormatException(
        'The media URL key must contain exactly 8 UTF-8 bytes.',
      );
    }
    await channel.invokeMethod<void>('write', {'value': value});
    _key = value;
    notifyListeners();
  }

  Future<void> remove() async {
    await channel.invokeMethod<void>('delete');
    _key = null;
    notifyListeners();
  }
}
