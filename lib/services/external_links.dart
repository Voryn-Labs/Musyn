import 'package:flutter/services.dart';

class ExternalLinks {
  static const channel = MethodChannel('com.vorynlabs.musyn/links');
  static Future<void> open(Uri uri) async {
    if (uri.scheme != 'https')
      throw ArgumentError('Only secure web links are supported');
    final opened = await channel.invokeMethod<bool>('open', uri.toString());
    if (opened != true) throw StateError('Could not open the link.');
  }
}
