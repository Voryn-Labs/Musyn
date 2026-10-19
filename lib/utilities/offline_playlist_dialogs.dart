import 'package:flutter/cupertino.dart';
import 'package:musyn/services/playlist_download_service.dart';
import 'package:musyn/utilities/flutter_toast.dart';
import 'package:musyn/widgets/confirmation_dialog.dart';

void showRemoveOfflinePlaylistDialog(BuildContext context, String playlistId) {
  showCupertinoDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return ConfirmationDialog(
        confirmationMessage: 'Remove this playlist and all downloaded tracks?',
        submitMessage: 'Remove',
        isDangerous: true,
        onCancel: () => Navigator.pop(context),
        onSubmit: () {
          offlinePlaylistService.removeOfflinePlaylist(playlistId);
          Navigator.pop(context);
          showToast(context, 'Playlist removed from downloads');
        },
      );
    },
  );
}
