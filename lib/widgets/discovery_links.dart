import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/services/navigation_paths.dart';
import 'package:musyn/theme/app_themes.dart';

/// Catalogue destinations, never invented chart results or placeholder searches.
class DiscoveryLinks extends StatelessWidget {
  const DiscoveryLinks({super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _link(
        context,
        CupertinoIcons.compass,
        'Moods & genres',
        'Find music for your day',
        () => context.go('/explore'),
      ),
      const SizedBox(height: 8),
      _link(
        context,
        CupertinoIcons.chart_bar,
        'Charts',
        'Browse chart playlists by provider',
        () => context.push(NavigationPaths.chartsPath(context)),
      ),
    ],
  );
  Widget _link(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback open,
  ) => CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: open,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: musynElevatedSurface(isAppDarkMode(context)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 26, color: CupertinoTheme.of(context).primaryColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CupertinoTheme.of(context).textTheme.textStyle.color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: CupertinoColors.systemGrey,
          ),
        ],
      ),
    ),
  );
}
