import 'package:flutter/cupertino.dart';

/// Predefined browse categories for the Search page matching BitChord's
/// Explore/Browse genres and moods grid.
class BrowseCategory {
  const BrowseCategory({
    required this.title,
    required this.searchQuery,
    required this.gradientColors,
    required this.icon,
  });

  final String title;
  final String searchQuery;
  final List<Color> gradientColors;
  final IconData icon;
}

const List<BrowseCategory> defaultBrowseCategories = [
  BrowseCategory(
    title: 'Top Charts',
    searchQuery: 'Top 100 Global',
    gradientColors: [Color(0xFFE52D27), Color(0xFFB31217)],
    icon: CupertinoIcons.chart_bar_square_fill,
  ),
  BrowseCategory(
    title: 'New Releases',
    searchQuery: 'New Music Releases',
    gradientColors: [Color(0xFF8A2387), Color(0xFFE94057)],
    icon: CupertinoIcons.sparkles,
  ),
  BrowseCategory(
    title: 'Pop Hits',
    searchQuery: 'Top Pop Songs',
    gradientColors: [Color(0xFFFA709A), Color(0xFFFEE140)],
    icon: CupertinoIcons.music_note,
  ),
  BrowseCategory(
    title: 'Hip-Hop & Rap',
    searchQuery: 'Top Hip Hop',
    gradientColors: [Color(0xFF2C3E50), Color(0xFF000000)],
    icon: CupertinoIcons.mic_fill,
  ),
  BrowseCategory(
    title: 'Bollywood Hits',
    searchQuery: 'Latest Bollywood Songs',
    gradientColors: [Color(0xFFFF512F), Color(0xFFDD2476)],
    icon: CupertinoIcons.star_fill,
  ),
  BrowseCategory(
    title: 'Punjabi Hits',
    searchQuery: 'Top Punjabi Songs',
    gradientColors: [Color(0xFFF7971E), Color(0xFFFFD200)],
    icon: CupertinoIcons.flame_fill,
  ),
  BrowseCategory(
    title: 'Chill & Relax',
    searchQuery: 'Chill Acoustic Beats',
    gradientColors: [Color(0xFF4CA1AF), Color(0xFF2C3E50)],
    icon: CupertinoIcons.moon_stars_fill,
  ),
  BrowseCategory(
    title: 'Workout Energy',
    searchQuery: 'Gym Workout Motivation Music',
    gradientColors: [Color(0xFFF857A6), Color(0xFFFF5858)],
    icon: CupertinoIcons.bolt_fill,
  ),
  BrowseCategory(
    title: 'Focus & Study',
    searchQuery: 'Deep Focus Lo-Fi Study Beats',
    gradientColors: [Color(0xFF3A6073), Color(0xFF16222F)],
    icon: CupertinoIcons.book_fill,
  ),
  BrowseCategory(
    title: 'Party & Dance',
    searchQuery: 'Club Dance Party Hits',
    gradientColors: [Color(0xFF654EA3), Color(0xFFEAAFC8)],
    icon: CupertinoIcons.speaker_3_fill,
  ),
  BrowseCategory(
    title: 'Rock & Metal',
    searchQuery: 'Best Rock Classics',
    gradientColors: [Color(0xFF434343), Color(0xFF000000)],
    icon: CupertinoIcons.guitars,
  ),
  BrowseCategory(
    title: 'Romance & Love',
    searchQuery: 'Romantic Love Songs',
    gradientColors: [Color(0xFFFF758C), Color(0xFFFF7EB3)],
    icon: CupertinoIcons.heart_fill,
  ),
];
