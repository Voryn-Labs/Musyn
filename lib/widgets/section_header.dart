import 'package:flutter/cupertino.dart';
import 'package:musyn/widgets/section_title.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.actionButton,
  });
  final String title;
  final IconData? icon;
  final Widget? actionButton;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: SectionTitle(title, CupertinoColors.label)),
        if (actionButton != null) actionButton!,
      ],
    );
  }
}
