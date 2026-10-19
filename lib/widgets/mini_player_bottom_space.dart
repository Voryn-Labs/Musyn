import 'package:flutter/cupertino.dart';

/// The shell reserves its own viewport for playback and navigation controls.
class MiniPlayerBottomSpace extends StatelessWidget {
  const MiniPlayerBottomSpace({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(height: 20);
}

class SliverMiniPlayerBottomSpace extends StatelessWidget {
  const SliverMiniPlayerBottomSpace({super.key});
  @override
  Widget build(BuildContext context) =>
      const SliverToBoxAdapter(child: MiniPlayerBottomSpace());
}
