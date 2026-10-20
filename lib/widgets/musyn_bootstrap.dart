import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';

/// Holds the branded launch briefly while initialization runs in parallel.
class MusynBootstrap extends StatefulWidget {
  const MusynBootstrap({
    super.key,
    required this.initialize,
    required this.readyBuilder,
    this.minimumDisplay = const Duration(milliseconds: 1800),
  });
  final Future<void> Function(ValueChanged<String> report) initialize;
  final WidgetBuilder readyBuilder;
  final Duration minimumDisplay;
  @override
  State<MusynBootstrap> createState() => _MusynBootstrapState();
}

class _MusynBootstrapState extends State<MusynBootstrap> {
  bool _ready = false;
  bool _failed = false;
  bool _slow = false;
  Timer? _slowTimer;
  String _status = 'Preparing your library';
  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_ready) setState(() => _slow = true);
    });
    setState(() {
      _failed = false;
      _slow = false;
      _status = 'Preparing your library';
    });
    try {
      await Future.wait<void>([
        widget.initialize((status) {
          if (mounted) setState(() => _status = status);
        }),
        Future<void>.delayed(widget.minimumDisplay),
      ], eagerError: true);
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
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: SizedBox(
              height: math.max(box.maxHeight, _slow || _failed ? 520 : 320),
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                          const SizedBox(height: 24),
                          const Text(
                            'By Voryn Labs',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFAAA3A3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_slow || _failed)
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: math.max(
                        MediaQuery.paddingOf(context).bottom,
                        24,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_failed) ...[
                            const CupertinoActivityIndicator(),
                            const SizedBox(height: 10),
                            Text(
                              _status,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          ] else ...[
                            const Text(
                              'Musyn could not start. Try again to open your library and player.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                            CupertinoButton(
                              onPressed: _start,
                              child: const Text('Try again'),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
