import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/services/data_manager.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/widgets/content_state.dart';

class OfflineSearchPlaceholder extends StatelessWidget {
  const OfflineSearchPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: musynCanvas(isAppDarkMode(context)),
    navigationBar: const CupertinoNavigationBar(middle: Text('Search')),
    child: SafeArea(
      child: SingleChildScrollView(
        child: ContentState(
          icon: CupertinoIcons.wifi_slash,
          title: 'Search needs a connection',
          message:
              'Go online to search music, or listen to your saved downloads.',
          actionLabel: 'Go online',
          onAction: () {
            offlineMode.value = false;
            unawaited(addOrUpdateData('settings', 'offlineMode', false));
          },
          secondaryLabel: 'Open downloads',
          onSecondary: () => context.go('/library/downloads'),
        ),
      ),
    ),
  );
}
