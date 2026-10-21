import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:musyn/services/vocal_reduction.dart';

class VocalReductionControls extends StatelessWidget {
  const VocalReductionControls({super.key, required this.item});
  final MediaItem item;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vocalReduction,
    builder: (context, _) {
      final state = vocalReduction;
      if (state.phase == VocalPhase.ready) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
          child: Column(
            children: [
              const Text(
                'Vocals',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              CupertinoSlider(
                value: state.level,
                onChanged: (value) => unawaited(state.setLevel(value)),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Instrumental', style: TextStyle(fontSize: 11)),
                  Text('Original', style: TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ),
        );
      }
      if (state.phase == VocalPhase.preparing) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              const CupertinoActivityIndicator(radius: 8),
              const SizedBox(width: 10),
              Expanded(
                child: Text(state.status, style: const TextStyle(fontSize: 12)),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: () => unawaited(state.disable()),
                child: const Text('Cancel', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: Column(
          children: [
            if (state.phase == VocalPhase.failed)
              Text(
                state.status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            CupertinoButton(
              padding: const EdgeInsets.all(8),
              onPressed: () => unawaited(state.enable(item)),
              child: const Text(
                'Reduce vocals',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      );
    },
  );
}
