import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material;
import 'package:musyn/services/smart_library.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';

const smartLibraryMoods = [
  'Calm', 'Focus', 'Energy', 'Feel good', 'Romance', 'Sad', 'Sleep', 'Party',
];

Future<void> showTrackOrganizationSheet(
  BuildContext context,
  Map song,
) async {
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => _TrackOrganizationSheet(song: song),
  );
}

class _TrackOrganizationSheet extends StatefulWidget {
  const _TrackOrganizationSheet({required this.song});
  final Map song;

  @override
  State<_TrackOrganizationSheet> createState() =>
      _TrackOrganizationSheetState();
}

class _TrackOrganizationSheetState extends State<_TrackOrganizationSheet> {
  late int rating;
  late int energy;
  late Set<String> tagIds;
  late Set<String> moods;

  @override
  void initState() {
    super.initState();
    final library = SmartLibrary.instance;
    rating = library.ratingFor(widget.song);
    energy = library.energyFor(widget.song);
    tagIds = library.tagIdsFor(widget.song);
    moods = library.moodsFor(widget.song);
  }

  @override
  Widget build(BuildContext context) {
    final dark = isAppDarkMode(context);
    final library = SmartLibrary.instance;
    return CupertinoPopupSurface(
      child: SafeArea(
        top: false,
        child: Material(
          color: musynElevatedSurface(dark),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 5,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey3,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Rate & organize', style: MusynStyle.sectionTitle(
                  dark ? CupertinoColors.white : CupertinoColors.black,
                )),
                const SizedBox(height: 4),
                Text(
                  widget.song['title']?.toString() ?? 'Track',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: dark
                      ? CupertinoColors.systemGrey
                      : CupertinoColors.secondaryLabel),
                ),
                const SizedBox(height: 20),
                _label('RATING'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(5, (index) {
                    final value = index + 1;
                    return CupertinoButton(
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(48, 48),
                      onPressed: () async {
                        setState(() => rating = rating == value ? 0 : value);
                        await library.rate(widget.song, rating);
                      },
                      child: Icon(
                        value <= rating
                            ? CupertinoIcons.star_fill
                            : CupertinoIcons.star,
                        color: value <= rating
                            ? CupertinoColors.systemYellow
                            : CupertinoColors.systemGrey,
                        size: 27,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                _label('MOOD'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final mood in smartLibraryMoods)
                      _chip(mood, moods.contains(mood), () {
                        setState(() => moods.contains(mood)
                            ? moods.remove(mood)
                            : moods.add(mood));
                        _saveOrganization();
                      }),
                  ],
                ),
                if (library.tags.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _label('TAGS'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in library.tags)
                        _chip(tag['name'].toString(),
                            tagIds.contains(tag['id'].toString()), () {
                          final id = tag['id'].toString();
                          setState(() => tagIds.contains(id)
                              ? tagIds.remove(id)
                              : tagIds.add(id));
                          _saveOrganization();
                        }),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                _label('ENERGY'),
                CupertinoSlidingSegmentedControl<int>(
                  groupValue: energy,
                  children: const {
                    0: Padding(padding: EdgeInsets.all(8), child: Text('Low')),
                    1: Padding(padding: EdgeInsets.all(8), child: Text('Medium')),
                    2: Padding(padding: EdgeInsets.all(8), child: Text('High')),
                  },
                  onValueChanged: (value) {
                    if (value == null) return;
                    setState(() => energy = value);
                    _saveOrganization();
                  },
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(
      fontSize: 12, fontWeight: FontWeight.w700,
      color: CupertinoColors.systemGrey, letterSpacing: .5,
    )),
  );

  Widget _chip(String text, bool selected, VoidCallback tap) =>
      CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minSize: 0,
        color: selected
            ? CupertinoTheme.of(context).primaryColor
            : CupertinoColors.systemGrey5.resolveFrom(context),
        borderRadius: BorderRadius.circular(18),
        onPressed: tap,
        child: Text(text, style: TextStyle(
          color: selected ? CupertinoColors.black : null,
          fontSize: 14, fontWeight: FontWeight.w600,
        )),
      );

  void _saveOrganization() {
    SmartLibrary.instance.organize(
      widget.song,
      tagIds: tagIds,
      moods: moods,
      energy: energy,
    );
  }
}
