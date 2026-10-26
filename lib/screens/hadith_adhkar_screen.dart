import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../providers/bookmarks_provider.dart';
import '../providers/activity_provider.dart';
import '../services/data_service.dart';
import '../models/adhkar.dart';
import '../models/hadith.dart';
import 'hadith_explorer_screen.dart';

final adhkarCategoriesProvider = FutureProvider<List<AdhkarCategory>>((ref) async {
  return DataService.loadAdhkarCategories();
});

final hadithCollectionsProvider = FutureProvider<List<HadithCollection>>((ref) async {
  return DataService.loadHadithCollections();
});

final hadithDataProvider = FutureProvider<List<Hadith>>((ref) async {
  return DataService.loadHadiths();
});

class HadithAdhkarScreen extends ConsumerWidget {
  const HadithAdhkarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.palette;
    final isRTL = settings.language == 'ku' || settings.language == 'ar';

    final tabAdhkar = settings.language == 'ku' ? 'زیکر و پەرستشەکان' : settings.language == 'ar' ? 'الأذكار والدعوات' : 'Adhkar & Dua';
    final tabHadith = settings.language == 'ku' ? 'فەرموودەكان' : settings.language == 'ar' ? 'موسوعة الأحاديث' : 'Hadiths';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                settings.language == 'ku'
                    ? 'زیکر و فەرموودەکان'
                    : settings.language == 'ar'
                        ? 'الأذكار والأحاديث'
                        : 'Hadith & Adhkar',
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar', fontWeight: FontWeight.bold),
              ),
            ],
          ),
          centerTitle: true,
          backgroundColor: Theme.of(context).cardColor,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.white.withOpacity(0.4),
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Rabar', fontSize: 14),
            unselectedLabelStyle: TextStyle(fontFamily: 'Rabar', fontSize: 13),
            tabs: [
              Tab(text: tabAdhkar, icon: Icon(Icons.menu_book_outlined, size: 20)),
              Tab(text: tabHadith, icon: Icon(Icons.auto_stories_outlined, size: 20)),
            ],
          ),
        ),
        body: Directionality(
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          child: const TabBarView(
            physics: BouncingScrollPhysics(),
            children: [
              AdhkarTab(),
              HadithTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== ADHKAR TAB ====================
class AdhkarTab extends ConsumerStatefulWidget {
  const AdhkarTab({super.key});

  @override
  ConsumerState<AdhkarTab> createState() => _AdhkarTabState();
}

class _AdhkarTabState extends ConsumerState<AdhkarTab> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _getAdhkarCategoryIcon(String catId) {
    switch (catId.toLowerCase()) {
      case 'morning':
        return Icons.wb_sunny_rounded;
      case 'evening':
        return Icons.nightlight_round;
      case '2':
        return Icons.bedtime_rounded;
      case '3':
        return Icons.wb_twilight_rounded;
      case '4':
      case '5':
        return Icons.clean_hands_rounded;
      case '6':
      case '7':
        return Icons.water_drop_rounded;
      case '8':
      case '9':
        return Icons.home_rounded;
      case '10':
      case '11':
      case '12':
      case 'mosque':
        return Icons.mosque_rounded;
      case 'adhan':
        return Icons.volume_up_rounded;
      case 'prayer':
        return Icons.access_time_filled_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'travel':
        return Icons.explore_rounded;
      case 'hajj':
        return Icons.flag_rounded;
      default:
        return Icons.auto_stories_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final categoriesAsync = ref.watch(adhkarCategoriesProvider);

    return categoriesAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
      error: (err, stack) => Center(child: Text('Error: $err', style: TextStyle(color: Colors.redAccent))),
      data: (categories) {
        final filtered = categories.where((cat) {
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          final ku = cat.ku.toLowerCase();
          final ar = cat.ar.toLowerCase();
          final en = cat.en.toLowerCase();
          return ku.contains(q) || ar.contains(q) || en.contains(q);
        }).toList();

        return Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: const TextStyle(color: Colors.white, fontFamily: 'Rabar'),
                decoration: InputDecoration(
                  hintText: settings.language == 'ar'
                      ? 'البحث في أذكار الصباح، المساء، بعد الصلاة...'
                      : settings.language == 'en'
                          ? 'Search morning, evening, after prayer adhkar...'
                          : 'گەڕان بەدوای زیکرەکانی بەیانیان، ئێواران، دوای نوێژ...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontFamily: 'Rabar', fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.04))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                ),
              ),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        settings.language == 'ar'
                            ? 'لم يتم العثور على أي ذكر'
                            : settings.language == 'en'
                                ? 'No adhkar found'
                                : 'هیچ زیکرێک نەدۆزرایەوە',
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontFamily: 'Rabar'),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final cat = filtered[index];
                        final name = settings.language == 'ar' ? cat.ar : settings.language == 'en' ? cat.en : cat.ku;

                        Color catColor = Theme.of(context).colorScheme.primary;
                        try {
                          final hex = cat.color.replaceAll('#', '');
                          if (hex.length == 6) {
                            catColor = Color(int.parse('FF$hex', radix: 16));
                          }
                        } catch (_) {}

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.15)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Material(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(18),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AdhkarDetailsScreen(
                                      categoryId: cat.id,
                                      categoryName: name,
                                    ),
                                  ),
                                );
                              },
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: catColor.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: catColor.withOpacity(0.4)),
                                ),
                                child: Center(
                                  child: Icon(_getAdhkarCategoryIcon(cat.id), color: catColor, size: 22),
                                ),
                              ),
                              title: Text(
                                name,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Rabar'),
                              ),
                              subtitle: Text(
                                cat.ar,
                                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary.withOpacity(0.8), fontFamily: 'Traditional Arabic', fontWeight: FontWeight.bold),
                              ),
                              trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ==================== ADHKAR DETAILS SCREEN (COUNTER) ====================
class AdhkarDetailsScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final String categoryName;

  const AdhkarDetailsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  ConsumerState<AdhkarDetailsScreen> createState() => _AdhkarDetailsScreenState();
}

class _AdhkarDetailsScreenState extends ConsumerState<AdhkarDetailsScreen> {
  Map<String, int> _counts = {};
  bool _isLoading = true;
  List<AdhkarItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final allData = await DataService.loadAdhkarData();
      final categoryItems = allData[widget.categoryId] ?? [];
      setState(() {
        _items = categoryItems;
        _counts = {for (var item in categoryItems) item.id: 0};
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetAllCounts() {
    setState(() {
      _counts = {for (var item in _items) item.id: 0};
    });
    final lang = ref.read(settingsProvider).language;
    final resetMsg = lang == 'ku'
        ? 'ژمارەی هەموو زیکرەکان سەردەمی نوێ کرایەوە'
        : lang == 'ar'
            ? 'تمت إعادة تعيين عدّادات جميع الأذكار'
            : 'All adhkar counts have been reset';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(resetMsg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isRTL = settings.language == 'ku' || settings.language == 'ar';

    final totalTarget = _items.fold<int>(0, (sum, item) => sum + item.repeat);
    final currentTotal = _counts.values.fold<int>(0, (sum, count) => sum + count);
    final completedItemsCount = _items.where((item) => (_counts[item.id] ?? 0) >= item.repeat).length;
    final progress = totalTarget > 0 ? (currentTotal / totalTarget).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.categoryName, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar')),
        centerTitle: true,
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.restart_alt, color: Theme.of(context).colorScheme.primary),
            tooltip: settings.language == 'en' ? 'Reset All' : settings.language == 'ar' ? 'إعادة ضبط الكل' : 'ڕێکخستنەوەی ژمارەر',
            onPressed: _resetAllCounts,
          ),
        ],
      ),
      body: Directionality(
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
            : _items.isEmpty
                ? Center(
                    child: Text(
                      settings.language == 'ar'
                          ? 'لا توجد أذكار في هذه الفئة'
                          : settings.language == 'en'
                              ? 'No adhkar in this category'
                              : 'هیچ زیکرێک لەم دەستەیەدا نییە',
                      style: const TextStyle(color: Colors.white, fontFamily: 'Rabar'),
                    ),
                  )
                : Column(
                    children: [
                      // OVERALL PROGRESS CARD
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2))),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  settings.language == 'en'
                                      ? 'Completed: $completedItemsCount of ${_items.length}'
                                      : settings.language == 'ar'
                                          ? 'المكتمل: $completedItemsCount من ${_items.length}'
                                          : 'تەواوبوو: $completedItemsCount لە ${_items.length} زیکر',
                                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                                ),
                                Text(
                                  '${(progress * 100).toInt()}%',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: Colors.white.withOpacity(0.05),
                                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ADHKAR CARDS LIST
                      Expanded(
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            final currentCount = _counts[item.id] ?? 0;
                            final targetCount = item.repeat;
                            final isCompleted = currentCount >= targetCount;

                            final translation = settings.language == 'en'
                                ? item.translationEn
                                : settings.language == 'ar'
                                    ? ''
                                    : item.translationKu;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: isCompleted ? const Color(0xFF10B981).withOpacity(0.08) : Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isCompleted ? const Color(0xFF10B981) : Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                  width: isCompleted ? 1.5 : 1.0,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Header & Toolbar Row
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isCompleted
                                                ? const Color(0xFF10B981).withOpacity(0.18)
                                                : Theme.of(context).colorScheme.primary.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isCompleted
                                                  ? const Color(0xFF10B981).withOpacity(0.5)
                                                  : Theme.of(context).colorScheme.primary.withOpacity(0.25),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isCompleted) ...[
                                                const Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
                                                const SizedBox(width: 4),
                                              ] else ...[
                                                Icon(Icons.tag, size: 14, color: Theme.of(context).colorScheme.primary),
                                                const SizedBox(width: 2),
                                              ],
                                              Text(
                                                settings.language == 'en'
                                                    ? 'Dhikr #${index + 1}'
                                                    : settings.language == 'ar'
                                                        ? 'الذكر #${index + 1}'
                                                        : 'زیکری #${index + 1}',
                                                style: TextStyle(
                                                  color: isCompleted ? const Color(0xFF10B981) : Theme.of(context).colorScheme.primary,
                                                  fontFamily: 'Rabar',
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Reset single count
                                            IconButton(
                                              icon: const Icon(Icons.refresh, color: Colors.white30, size: 18),
                                              padding: const EdgeInsets.all(6),
                                              constraints: const BoxConstraints(),
                                              visualDensity: VisualDensity.compact,
                                              tooltip: settings.language == 'en' ? 'Reset' : settings.language == 'ar' ? 'إعادة ضبط' : 'سفڕکردنەوە',
                                              onPressed: () {
                                                setState(() => _counts[item.id] = 0);
                                              },
                                            ),
                                            const SizedBox(width: 4),
                                            // Bookmark Button
                                            IconButton(
                                              icon: const Icon(Icons.bookmark_border, color: Color(0xFF10B981), size: 18),
                                              padding: const EdgeInsets.all(6),
                                              constraints: const BoxConstraints(),
                                              visualDensity: VisualDensity.compact,
                                              tooltip: settings.language == 'en' ? 'Bookmark' : settings.language == 'ar' ? 'حفظ' : 'پاشەکەوت',
                                              onPressed: () {
                                                ref.read(bookmarksProvider.notifier).addBookmark(
                                                  BookmarkItem(
                                                    id: 'adhkar-${item.id}',
                                                    title: widget.categoryName,
                                                    subtitle: item.arabic,
                                                    type: 'adhkar',
                                                  ),
                                                );
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text(settings.language == 'en' ? 'Adhkar saved' : settings.language == 'ar' ? 'تم الحفظ' : 'زیکرەکە پاشەکەوت کرا')),
                                                );
                                              },
                                            ),
                                            const SizedBox(width: 4),
                                            // Copy Button
                                            IconButton(
                                              icon: const Icon(Icons.copy, color: Color(0xFF3B82F6), size: 18),
                                              padding: const EdgeInsets.all(6),
                                              constraints: const BoxConstraints(),
                                              visualDensity: VisualDensity.compact,
                                              tooltip: settings.language == 'en' ? 'Copy' : settings.language == 'ar' ? 'نسخ' : 'کۆپی',
                                              onPressed: () {
                                                final fullText = '${item.arabic}\n\n$translation';
                                                Clipboard.setData(ClipboardData(text: fullText));
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text(settings.language == 'en' ? 'Copied to clipboard' : settings.language == 'ar' ? 'تم النسخ' : 'زیکرەکە کۆپی کرا')),
                                                );
                                              },
                                            ),
                                            const SizedBox(width: 4),
                                            // Share Button
                                            IconButton(
                                              icon: const Icon(Icons.share, color: Color(0xFFEC4899), size: 18),
                                              padding: const EdgeInsets.all(6),
                                              constraints: const BoxConstraints(),
                                              visualDensity: VisualDensity.compact,
                                              tooltip: settings.language == 'en' ? 'Share' : settings.language == 'ar' ? 'مشاركة' : 'بەشداری پێکردن',
                                              onPressed: () {
                                                final fullText = '${item.arabic}\n\n$translation';
                                                Share.share(fullText);
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 10),

                                    // ARABIC TEXT
                                    Text(
                                      item.arabic,
                                      style: GoogleFonts.amiri(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        height: 2.0,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.right,
                                      textDirection: TextDirection.rtl,
                                    ),
                                    SizedBox(height: 12),

                                    // TRANSLATION
                                    if (translation.isNotEmpty) ...[
                                      Text(
                                        translation,
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.6,
                                          color: Colors.white.withOpacity(0.8),
                                          fontFamily: 'Rabar',
                                        ),
                                        textAlign: isRTL ? TextAlign.right : TextAlign.left,
                                      ),
                                      SizedBox(height: 12),
                                    ],

                                    // SOURCE / VIRTUE TAG IF AVAILABLE
                                    if (item.source.isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.verified_outlined, color: Theme.of(context).colorScheme.primary, size: 18),
                                            SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                item.source,
                                                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                    ],

                                    // COUNTER BUTTON / STATUS
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                         onTap: isCompleted
                                             ? null
                                             : () {
                                                 HapticFeedback.lightImpact();
                                                 setState(() {
                                                   _counts[item.id] = currentCount + 1;
                                                 });
                                                 ref.read(activityProvider.notifier).logActivity(1);
                                               },
                                         borderRadius: BorderRadius.circular(16),
                                         child: AnimatedContainer(
                                           duration: const Duration(milliseconds: 200),
                                           padding: const EdgeInsets.symmetric(vertical: 14),
                                           decoration: BoxDecoration(
                                             color: isCompleted
                                                 ? const Color(0xFF10B981).withOpacity(0.2)
                                                 : Theme.of(context).colorScheme.primary.withOpacity(0.12),
                                             borderRadius: BorderRadius.circular(16),
                                             border: Border.all(
                                               color: isCompleted
                                                   ? const Color(0xFF10B981)
                                                   : Theme.of(context).colorScheme.primary.withOpacity(0.4),
                                             ),
                                           ),
                                           child: Padding(
                                             padding: const EdgeInsets.symmetric(horizontal: 12),
                                             child: Row(
                                               mainAxisAlignment: MainAxisAlignment.center,
                                               children: [
                                                 if (isCompleted) ...[
                                                   const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 22),
                                                   const SizedBox(width: 8),
                                                   Flexible(
                                                     child: Text(
                                                       settings.language == 'en'
                                                           ? 'Completed ($targetCount of $targetCount times)'
                                                           : settings.language == 'ar'
                                                               ? 'اكتمل ($targetCount من $targetCount مرات)'
                                                               : 'تەواو بوو ($targetCount لە $targetCount جار)',
                                                       style: const TextStyle(
                                                         fontWeight: FontWeight.bold,
                                                         color: Color(0xFF10B981),
                                                         fontSize: 14,
                                                         fontFamily: 'Rabar',
                                                       ),
                                                       overflow: TextOverflow.ellipsis,
                                                     ),
                                                   ),
                                                 ] else ...[
                                                   Icon(Icons.touch_app, color: Theme.of(context).colorScheme.primary, size: 20),
                                                   const SizedBox(width: 8),
                                                   Flexible(
                                                     child: Text(
                                                       settings.language == 'en'
                                                           ? 'Recite $targetCount times ($currentCount / $targetCount)'
                                                           : settings.language == 'ar'
                                                               ? 'يُقرأ $targetCount مرات ($currentCount من $targetCount)'
                                                               : 'پێویستە $targetCount جار بخوێنرێت ($currentCount لە $targetCount)',
                                                       style: TextStyle(
                                                         color: Theme.of(context).colorScheme.primary,
                                                         fontFamily: 'Rabar',
                                                         fontWeight: FontWeight.bold,
                                                         fontSize: 14,
                                                       ),
                                                       overflow: TextOverflow.ellipsis,
                                                     ),
                                                   ),
                                                 ],
                                               ],
                                             ),
                                           ),
                                         ),
                                       ),
                                     ),
                                   ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

// ==================== HADITH TAB ====================
class HadithTab extends StatelessWidget {
  const HadithTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const HadithExplorer();
  }
}
