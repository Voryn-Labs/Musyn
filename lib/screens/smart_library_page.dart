import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:musyn/services/smart_library.dart';
import 'package:musyn/theme/app_themes.dart';
import 'package:musyn/theme/musyn_style.dart';

class SmartLibraryPage extends StatefulWidget {
  const SmartLibraryPage({super.key});

  @override
  State<SmartLibraryPage> createState() => _SmartLibraryPageState();
}

class _SmartLibraryPageState extends State<SmartLibraryPage> {
  final library = SmartLibrary.instance;

  @override
  void initState() {
    super.initState();
    library.addListener(_refresh);
  }

  @override
  void dispose() {
    library.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final dark = isAppDarkMode(context);
    return CupertinoPageScaffold(
      backgroundColor: musynCanvas(dark),
      navigationBar: const CupertinoNavigationBar(middle: Text('Smart Library')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Text('Your music, your rules', style: MusynStyle.largeTitle(
              dark ? CupertinoColors.white : CupertinoColors.black,
            )),
            const SizedBox(height: 8),
            const Text(
              'Ratings, tags and listening history stay private on this device.',
              style: TextStyle(color: CupertinoColors.systemGrey),
            ),
            const SizedBox(height: 24),
            _header('Made for you'),
            CupertinoListSection.insetGrouped(
              margin: EdgeInsets.zero,
              children: [
                _collection('five-star', 'Five-star tracks',
                    'Your highest-rated music', CupertinoIcons.star_fill),
                _collection('forgotten', 'Rediscover',
                    'Favorites unheard for 30 days', CupertinoIcons.sparkles),
                _collection('never-played', 'Never played',
                    'Saved music waiting for a first listen', CupertinoIcons.play_circle),
                _collection('offline-favorites', 'Offline favorites',
                    'Loved music ready without a connection', CupertinoIcons.arrow_down_circle_fill),
              ],
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: _header('Tags')),
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: _createTag,
                child: const Icon(CupertinoIcons.plus_circle),
              ),
            ]),
            if (library.tags.isEmpty)
              _empty('Add tags such as Workout, Vinyl or Road trip.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final tag in library.tags) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: musynSecondarySurface(dark),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(tag['name'].toString()),
                )],
              ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: _header('Custom collections')),
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: _createCollection,
                child: const Icon(CupertinoIcons.plus_circle),
              ),
            ]),
            if (library.collections.isEmpty)
              _empty('Build a collection from ratings, moods, tags or source.')
            else
              CupertinoListSection.insetGrouped(
                margin: EdgeInsets.zero,
                children: [for (final item in library.collections)
                  CupertinoListTile(
                    leading: const Icon(CupertinoIcons.slider_horizontal_3),
                    title: Text(item['name'].toString()),
                    subtitle: Text('${library.songsForCollection(item).length} tracks'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => context.push('/library/smart/custom', extra: item),
                  )],
              ),
          ],
        ),
      ),
    );
  }

  Widget _collection(String id, String title, String subtitle, IconData icon) =>
      CupertinoListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const CupertinoListTileChevron(),
        onTap: () => context.push('/library/smart/$id'),
      );

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
  );

  Widget _empty(String text) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: CupertinoColors.systemGrey6.resolveFrom(context),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(text, style: const TextStyle(color: CupertinoColors.systemGrey)),
  );

  Future<void> _createTag() async {
    final controller = TextEditingController();
    await showCupertinoDialog<void>(context: context, builder: (dialog) =>
      CupertinoAlertDialog(
        title: const Text('New tag'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(controller: controller, placeholder: 'Tag name', autofocus: true),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
          CupertinoDialogAction(isDefaultAction: true, onPressed: () async {
            if (controller.text.trim().isNotEmpty) await library.createTag(controller.text);
            if (dialog.mounted) Navigator.pop(dialog);
          }, child: const Text('Add')),
        ],
      ),
    );
  }

  Future<void> _createCollection() async {
    final name = TextEditingController();
    var rating = 4;
    await showCupertinoModalPopup<void>(context: context, builder: (sheet) =>
      StatefulBuilder(builder: (context, setSheet) => CupertinoActionSheet(
        title: const Text('New smart collection'),
        message: Column(children: [
          const SizedBox(height: 8),
          CupertinoTextField(controller: name, placeholder: 'Collection name'),
          const SizedBox(height: 16),
          const Text('Minimum rating'),
          const SizedBox(height: 8),
          CupertinoSlidingSegmentedControl<int>(
            groupValue: rating,
            children: const {1: Text('1★'), 2: Text('2★'), 3: Text('3★'), 4: Text('4★'), 5: Text('5★')},
            onValueChanged: (v) { if (v != null) setSheet(() => rating = v); },
          ),
        ]),
        actions: [CupertinoActionSheetAction(onPressed: () async {
          final clean = name.text.trim();
          if (clean.isEmpty) return;
          await library.saveCollection(name: clean, matchAll: true,
            rules: [{'field': 'rating', 'value': rating}]);
          if (sheet.mounted) Navigator.pop(sheet);
        }, child: const Text('Create'))],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(sheet), child: const Text('Cancel')),
      )),
    );
  }
}
