import 'package:flutter/cupertino.dart';

/// The shell supplies the complete floating-bar obstruction once.
class MiniPlayerBottomSpace extends StatelessWidget {
  const MiniPlayerBottomSpace({super.key});
  @override
  Widget build(BuildContext context) =>
      SizedBox(height: MediaQuery.paddingOf(context).bottom + 16);
}

class SliverMiniPlayerBottomSpace extends StatelessWidget {
  const SliverMiniPlayerBottomSpace({super.key});
  @override
  Widget build(BuildContext context) =>
      const SliverToBoxAdapter(child: MiniPlayerBottomSpace());
}
