import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musyn/services/provider_access.dart';
import 'package:musyn/services/settings_manager.dart';

Future<void> configureFixtureProvider() async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        ProviderAccess.instance.channel,
        (_) async => null,
      );
  await ProviderAccess.instance.save('fixture!');
  jiosaavnEnabled.value = true;
}
