import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:musyn/theme/app_themes.dart';

const privacySections = <String, String>{
  'Your library stays local':
      'Musyn stores favorites, history, playlists, downloads and preferences on your device. Voryn Labs adds no advertising or analytics SDK. No diagnostic upload happens automatically.',
  'Music providers':
      'Search, audio, artwork and downloads contact YouTube/YouTube Music and, only when configured and enabled, JioSaavn. Lyrics contact LRCLIB. Providers receive the requests and your IP address and apply their own policies.',
  'Automatic animated artwork':
      'On supported iOS versions, automatic artwork is enabled unless you turn it off in Appearance. It sends the selected track title, artist and album metadata to Apple’s public catalog/pages and downloads a matching artwork clip from Apple’s media servers. It sends no account cookies or provider keys. Clips are cached locally (up to 80 MB / 20 files); clear them in Storage & diagnostics. Offline mode, Reduce Motion and Low Power Mode suppress new lookups.',
  'Optional lock-screen lyrics':
      'When enabled, Musyn fetches timed lyrics from LRCLIB or existing fallback lyric providers and shows the current line in place of the lock-screen artist. People who can see your lock screen may see these lyrics. Turn it off in Appearance or the player menu to restore the artist. Plain lyrics are never assigned invented timestamps.',
  'Optional accounts and keys':
      'YouTube Music sessions are stored in local app storage for account sync. Your optional JioSaavn media URL key is stored in iOS Keychain, never bundled or included in logs. Keychain entries may survive reinstall; remove a key in Settings before uninstalling if you want it deleted.',
  'Sharing diagnostics':
      'You can review redacted logs before choosing to upload them to dpaste. A paste is public to anyone with its URL and requests a seven-day expiry. Logs can still include song names and timings. GitHub issues are public; the app opens a draft and you decide whether to submit it.',
  'Contact':
      'Privacy questions: appsvorynlabs@gmail.com. Disconnect YouTube Music, remove your provider key, and clear history in Settings when needed.',
};
const termsSections = <String, String>{
  'Independent software':
      'Musyn is an independent Voryn Labs project, not affiliated with or endorsed by YouTube, Google, JioSaavn, Apple or Spotify. Provider names identify compatible services.',
  'Use with permission':
      'Use Musyn only for content and services you are entitled to access. Downloads do not grant ownership or redistribution rights. A user-supplied key does not grant permission or override a provider’s terms. Do not enter another person’s credentials.',
  'Availability':
      'Providers can change or restrict access. Playback, account sync, downloads and artwork availability are not guaranteed. iOS 26 features require a compatible system and may be limited by accessibility, power or system settings.',
  'Open-source license':
      'Musyn source is provided under GPL-3.0 with upstream notices and dependency licenses. Music, artwork and service trademarks retain their owners’ rights. Review LICENSE and docs/CREDITS.md in the repository.',
  'Installation and support':
      'The distributed IPA is unsigned and requires your signing identity or a compatible host. Keep backups of data you value. Report reproducible problems through Settings → Support. Software is provided without warranties to the extent permitted by applicable law; statutory rights remain unaffected.',
};

class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.title, required this.sections});
  final String title;
  final Map<String, String> sections;
  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: musynCanvas(isAppDarkMode(context)),
    navigationBar: CupertinoNavigationBar(middle: Text(title)),
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Musyn by Voryn Labs', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          const Text('Updated 21 October 2026', style: TextStyle(fontSize: 13)),
          for (final entry in sections.entries) ...[
            const SizedBox(height: 28),
            Text(
              entry.key,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            SelectableText(
              entry.value,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ],
      ),
    ),
  );
}
