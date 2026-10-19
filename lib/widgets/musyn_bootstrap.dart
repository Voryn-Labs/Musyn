import 'dart:async';
import 'package:flutter/cupertino.dart';

/// Shows the real initialization state; no artificial splash delay.
class MusynBootstrap extends StatefulWidget {
  const MusynBootstrap({
    super.key,
    required this.initialize,
    required this.readyBuilder,
  });
  final Future<void> Function(ValueChanged<String> report) initialize;
  final WidgetBuilder readyBuilder;
  @override
  State<MusynBootstrap> createState() => _MusynBootstrapState();
}

class _MusynBootstrapState extends State<MusynBootstrap> {
  bool _ready = false;
  bool _failed = false;
  String _status = 'Preparing your library';
  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    setState(() {
      _failed = false;
      _status = 'Preparing your library';
    });
    try {
      await widget.initialize((status) {
        if (mounted) setState(() => _status = status);
      });
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.readyBuilder(context);
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: Color(0xFFFFC5A7),
        primaryContrastingColor: Color(0xFF100E12),
      ),
      home: CupertinoPageScaffold(
        backgroundColor: const Color(0xFF100E12),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/branding/musyn-icon.png',
                          width: 112,
                          height: 112,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Musyn',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (!_failed) ...[
                        const CupertinoActivityIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          _status,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'Musyn could not start. Try again to open your library and player.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        CupertinoButton.filled(
                          onPressed: _start,
                          child: const Text('Try again'),
                        ),
                      ],
                      const SizedBox(height: 40),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/branding/voryn-mark.png',
                            width: 24,
                            height: 24,
                          ),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              'By Voryn Labs',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFFCAB78F),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
