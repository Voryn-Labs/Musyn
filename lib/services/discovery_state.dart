import 'package:flutter/foundation.dart';

/// Shared catalogue snapshots, independent of the screens presenting them.
final ValueNotifier<List<Map<String, dynamic>>> saavnCharts = ValueNotifier([]);
final ValueNotifier<List<Map<String, dynamic>>> ytChartPlaylists =
    ValueNotifier([]);

final ValueNotifier<List> searchHistoryNotifier = ValueNotifier<List>([]);
