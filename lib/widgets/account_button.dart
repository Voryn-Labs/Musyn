import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/services/download_activity.dart';
import 'package:musyn/services/navigation_paths.dart';
import 'package:musyn/services/playlist_download_service.dart';
import 'package:musyn/services/youtube_auth_service.dart';
import 'package:musyn/widgets/catalogue_artwork.dart';

/// Account/settings lives above the four peer tabs.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      downloadActivity.jobs,
      offlinePlaylistService.activeDownloadIds,
    ]),
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (downloadActivity.jobs.value.any((job) => job.active) ||
            offlinePlaylistService.activeDownloadIds.value.isNotEmpty)
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, 44),
            onPressed: () =>
                context.push(NavigationPaths.downloadsPath(context)),
            child: Icon(
              CupertinoIcons.arrow_down_circle,
              semanticLabel: 'Active downloads',
              color: CupertinoTheme.of(context).primaryColor,
            ),
          ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          onPressed: () => context.push('/settings'),
          child: Semantics(
            label: 'Account and settings',
            button: true,
            child: ValueListenableBuilder<String?>(
              valueListenable: YouTubeAuthService().userAvatarUrl,
              builder: (context, avatar, _) => avatar == null || avatar.isEmpty
                  ? Icon(
                      CupertinoIcons.person_crop_circle,
                      size: 30,
                      color: CupertinoTheme.of(context).primaryColor,
                    )
                  : ClipOval(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CatalogueArtwork(imageUrl: avatar),
                      ),
                    ),
            ),
          ),
        ),
      ],
    ),
  );
}
