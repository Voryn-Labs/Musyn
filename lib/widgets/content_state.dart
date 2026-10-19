import 'package:flutter/cupertino.dart';
import 'package:musyn/theme/musyn_style.dart';

/// Explicit loading, empty and failure states with a useful next action.
class ContentState extends StatelessWidget {
  const ContentState({
    super.key,
    required this.title,
    required this.message,
    this.icon = CupertinoIcons.music_note_2,
    this.loading = false,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });
  final String title;
  final String message;
  final IconData icon;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const CupertinoActivityIndicator(radius: 14)
            else
              Icon(icon, size: 38, color: CupertinoColors.systemGrey),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: MusynStyle.sectionTitle(
                CupertinoTheme.of(context).textTheme.textStyle.color!,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: CupertinoColors.systemGrey,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: onAction,
                child: Text(actionLabel!, textAlign: TextAlign.center),
              ),
            ],
            if (secondaryLabel != null && onSecondary != null)
              CupertinoButton(
                onPressed: onSecondary,
                child: Text(secondaryLabel!, textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    ),
  );
}
