import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlayerOption {
  const PlayerOption(
    this.title,
    this.symbol,
    this.action, {
    this.selected = false,
  });
  final String title;
  final String symbol;
  final VoidCallback action;
  final bool selected;
}

/// The iOS menu is anchored to More, rather than covering the player in a sheet.
class PlayerOptionsButton extends StatefulWidget {
  const PlayerOptionsButton({
    super.key,
    required this.trackId,
    required this.options,
  });
  final String trackId;
  final List<PlayerOption> options;
  @override
  State<PlayerOptionsButton> createState() => _PlayerOptionsButtonState();
}

class _PlayerOptionsButtonState extends State<PlayerOptionsButton> {
  MethodChannel? _channel;
  Future<void> _configure() async {
    try {
      await _channel?.invokeMethod<void>('configure', {
        'id': widget.trackId,
        'dark': CupertinoTheme.brightnessOf(context) == Brightness.dark,
        'items': [
          for (var i = 0; i < widget.options.length; i++)
            {
              'index': i,
              'title': widget.options[i].title,
              'symbol': widget.options[i].symbol,
              'selected': widget.options[i].selected,
            },
        ],
      });
    } on PlatformException {
      /* A disposed native menu cannot affect playback. */
    } on MissingPluginException {
      /* View may be removed during a rapid skip. */
    }
  }

  @override
  void didUpdateWidget(covariant PlayerOptionsButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    unawaited(_configure());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_configure());
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS && !kIsWeb) {
      return SizedBox(
        width: 44,
        height: 44,
        child: UiKitView(
          viewType: 'com.vorynlabs.musyn/player_menu',
          onPlatformViewCreated: (id) {
            final channel = MethodChannel(
              'com.vorynlabs.musyn/player_menu/$id',
            );
            _channel = channel;
            channel.setMethodCallHandler((call) async {
              if (!mounted || call.method != 'action' || call.arguments is! Map)
                return;
              final args = call.arguments as Map;
              final index = args['index'];
              if (args['id'] == widget.trackId &&
                  index is int &&
                  index >= 0 &&
                  index < widget.options.length)
                widget.options[index].action();
            });
            unawaited(_configure());
          },
        ),
      );
    }
    return CupertinoButton(
      padding: const EdgeInsets.all(10),
      onPressed: () => showCupertinoModalPopup<void>(
        context: context,
        builder: (sheet) => CupertinoActionSheet(
          actions: [
            for (final option in widget.options)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(sheet);
                  option.action();
                },
                child: Text(option.title),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheet),
            child: const Text('Cancel'),
          ),
        ),
      ),
      child: Semantics(
        label: 'Track options',
        child: const Icon(CupertinoIcons.ellipsis, size: 24),
      ),
    );
  }
}
