import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/services.dart';
import 'package:musyn/services/diagnostic_sharing.dart';
import 'package:musyn/services/external_links.dart';
import 'package:musyn/services/logger_service.dart';
import 'package:musyn/theme/app_themes.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});
  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  late String _preview = sanitizeDiagnostics(logger.getLogs());
  bool _busy = false;
  Uri? _link;
  String? _error;
  Future<void> _upload() async {
    final approved = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialog) => CupertinoAlertDialog(
        title: const Text('Upload these logs?'),
        content: const Text(
          'The preview below will be sent to dpaste.com as a public link with a requested seven-day expiry. It can still include song names and timings.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final link = await DiagnosticSharing().upload(_preview);
      if (mounted) setState(() => _link = link);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Upload failed. Retry or copy the preview instead.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _issue() async {
    try {
      await ExternalLinks.open(DiagnosticSharing.issue(log: _link));
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Could not open GitHub. Visit github.com/Voryn-Labs/Musyn/issues.',
        );
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: musynCanvas(isAppDarkMode(context)),
    navigationBar: const CupertinoNavigationBar(
      middle: Text('Diagnostics & support'),
    ),
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'A useful report starts here.',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text(
            'Review the preview before sharing. Credentials, URLs, emails and local paths are redacted. Song names and timings may remain. Nothing is uploaded automatically.',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 20),
          CupertinoButton.filled(
            onPressed: _busy || _preview.isEmpty ? null : _upload,
            child: _busy
                ? const CupertinoActivityIndicator()
                : const Text('Upload to dpaste'),
          ),
          CupertinoButton(
            onPressed: _busy ? null : _issue,
            child: const Text('Create GitHub issue'),
          ),
          if (_link != null) ...[
            SelectableText(_link.toString()),
            CupertinoButton(
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: _link.toString())),
              child: const Text('Copy diagnostic link'),
            ),
          ],
          if (_error != null)
            Text(
              _error!,
              style: const TextStyle(color: CupertinoColors.systemRed),
            ),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  onPressed: _preview.isEmpty
                      ? null
                      : () => Clipboard.setData(ClipboardData(text: _preview)),
                  child: const Text('Copy preview'),
                ),
              ),
              Expanded(
                child: CupertinoButton(
                  onPressed: _busy
                      ? null
                      : () {
                          logger.clearLogs();
                          setState(() {
                            _preview = '';
                            _link = null;
                          });
                        },
                  child: const Text('Clear logs'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Diagnostic preview',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SelectableText(
            _preview.isEmpty ? 'No diagnostic logs recorded.' : _preview,
            style: TextStyle(
              fontFamily: 'Menlo',
              fontSize: 11,
              height: 1.5,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    ),
  );
}
