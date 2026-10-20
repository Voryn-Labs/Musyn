import 'package:flutter/cupertino.dart';
import 'package:musyn/services/audio/audio_runtime.dart';
import 'package:musyn/services/common_services.dart'
    show invalidateAllSongStreamCaches;
import 'package:musyn/services/data_manager.dart';
import 'package:musyn/services/provider_access.dart';
import 'package:musyn/services/settings_manager.dart';
import 'package:musyn/theme/app_themes.dart';

class ProviderAccessPage extends StatefulWidget {
  const ProviderAccessPage({super.key});
  @override
  State<ProviderAccessPage> createState() => _ProviderAccessPageState();
}

class _ProviderAccessPageState extends State<ProviderAccessPage> {
  final _key = TextEditingController();
  bool _busy = false;
  String? _status;
  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _save({bool remove = false}) async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      if (remove) {
        await ProviderAccess.instance.remove();
      } else {
        await ProviderAccess.instance.save(_key.text);
      }
      jiosaavnEnabled.value = !remove;
      await addOrUpdateData('settings', 'jiosaavnEnabled', !remove);
      if (remove) {
        preferredSource.value = 'auto';
        downloadSource.value = 'best';
        await addOrUpdateData('settings', 'preferredSource', 'auto');
        await addOrUpdateData('settings', 'downloadSource', 'best');
      }
      if (isAudioHandlerInitialized) audioHandler.clearPinnedSources();
      await invalidateAllSongStreamCaches();
      _key.clear();
      if (mounted)
        setState(
          () => _status = remove
              ? 'Key removed. YouTube Music is ready.'
              : 'Key saved securely. JioSaavn is enabled; availability is checked when you play.',
        );
    } on FormatException catch (e) {
      if (mounted) setState(() => _status = e.message);
    } catch (_) {
      if (mounted)
        setState(() => _status = 'Could not update secure storage. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: musynCanvas(isAppDarkMode(context)),
    navigationBar: const CupertinoNavigationBar(middle: Text('JioSaavn')),
    child: SafeArea(
      child: ListenableBuilder(
        listenable: ProviderAccess.instance,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(CupertinoIcons.waveform, size: 48),
            const SizedBox(height: 20),
            Text(
              'Your sources. Your choice.',
              style: CupertinoTheme.of(
                context,
              ).textTheme.navLargeTitleTextStyle,
            ),
            const SizedBox(height: 12),
            const Text(
              'YouTube Music works without a key. JioSaavn is optional and uses a media URL key you provide.',
            ),
            const SizedBox(height: 24),
            Text(
              ProviderAccess.instance.configured
                  ? 'A key is stored in your iPhone Keychain.'
                  : 'No key is configured.',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: _key,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              placeholder: ProviderAccess.instance.configured
                  ? 'Replace media URL key'
                  : 'Media URL key',
              padding: const EdgeInsets.all(16),
              onSubmitted: (_) {
                if (!_busy) _save();
              },
            ),
            const SizedBox(height: 10),
            Text(
              'Need setup help? Search “JioSaavn media URL key”. Use only a key you are authorized to use. Musyn does not provide or verify third-party keys.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 20),
            CupertinoButton.filled(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const CupertinoActivityIndicator()
                  : const Text('Save key'),
            ),
            if (ProviderAccess.instance.configured)
              CupertinoListTile(
                title: const Text('Use JioSaavn'),
                trailing: CupertinoSwitch(
                  value: jiosaavnEnabled.value,
                  onChanged: _busy
                      ? null
                      : (value) async {
                          setState(() => jiosaavnEnabled.value = value);
                          await addOrUpdateData(
                            'settings',
                            'jiosaavnEnabled',
                            value,
                          );
                          if (isAudioHandlerInitialized)
                            audioHandler.clearPinnedSources();
                        },
                ),
              ),
            if (ProviderAccess.instance.configured)
              CupertinoButton(
                onPressed: _busy ? null : () => _save(remove: true),
                child: const Text('Remove key'),
              ),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_status!, semanticsLabel: _status),
              ),
            const SizedBox(height: 24),
            const Text(
              'The key stays on this device and is excluded from diagnostics. A valid 8-byte key is required; entering an arbitrary value does not guarantee playback.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    ),
  );
}
