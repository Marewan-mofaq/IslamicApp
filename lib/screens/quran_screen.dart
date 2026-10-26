import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../providers/bookmarks_provider.dart';
import '../services/data_service.dart';
import 'surah_view_screen.dart';

final surahInfoFutureProvider = FutureProvider<List<dynamic>>((ref) async {
  return DataService.loadSurahInfo();
});

class QuranScreen extends ConsumerStatefulWidget {
  const QuranScreen({super.key});

  @override
  ConsumerState<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends ConsumerState<QuranScreen> with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  // Last read data
  int? _lastSurahId;
  String? _lastSurahName;
  int? _lastAyahNum;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLastRead();
  }

  Future<void> _loadLastRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _lastSurahId = prefs.getInt('lastReadSurahId');
        _lastSurahName = prefs.getString('lastReadSurahName');
        _lastAyahNum = prefs.getInt('lastReadAyahNum');
      });
    } catch (_) {}
  }

  static const Map<int, List<int>> _juzToSurahIds = {
    1: [1, 2],
    2: [2],
    3: [2, 3],
    4: [3, 4],
    5: [4],
    6: [4, 5],
    7: [5, 6],
    8: [6, 7],
    9: [7, 8],
    10: [8, 9],
    11: [9, 10, 11],
    12: [11, 12],
    13: [12, 13, 14],
    14: [15, 16],
    15: [17, 18],
    16: [18, 19, 20],
    17: [21, 22],
    18: [23, 24, 25],
    19: [25, 26, 27],
    20: [27, 28, 29],
    21: [29, 30, 31, 32, 33],
    22: [33, 34, 35, 36],
    23: [36, 37, 38, 39],
    24: [39, 40, 41],
    25: [41, 42, 43, 44, 45],
    26: [46, 47, 48, 49, 50, 51],
    27: [51, 52, 53, 54, 55, 56, 57],
    28: [58, 59, 60, 61, 62, 63, 64, 65, 66],
    29: [67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77],
    30: [78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114],
  };

  void _showJuzSurahsModal(BuildContext context, int juzNum, List<dynamic> allSurahs, String lang) {
    final surahIds = _juzToSurahIds[juzNum] ?? [1];
    final surahsInJuz = allSurahs.where((s) => surahIds.contains(s['id'])).toList();
    if (surahsInJuz.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final firstS = surahsInJuz.first;
        final lastS = surahsInJuz.last;
        final titleText = lang == 'ku' ? 'پارەی $juzNum (Juz $juzNum)' : (lang == 'ar' ? 'الجزء $juzNum' : 'Juz $juzNum');
        final subtitleText = lang == 'ku'
            ? 'لە سورەتی ${firstS['name_ku']} تا ${lastS['name_ku']} • ${surahsInJuz.length} سورەت'
            : (lang == 'ar'
                ? 'من سورة ${firstS['name_ar']} إلى ${lastS['name_ar']} • ${surahsInJuz.length} سورة'
                : 'From Surah ${firstS['name_en']} to ${lastS['name_en']} • ${surahsInJuz.length} Surahs');

        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titleText,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                              fontFamily: 'Rabar',
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            subtitleText,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white60,
                              fontFamily: 'Rabar',
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10, height: 24),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: surahsInJuz.length,
                    itemBuilder: (context, index) {
                      final surah = surahsInJuz[index];
                      final id = surah['id'] as int;
                      final nameKu = surah['name_ku'] ?? '';
                      final nameAr = surah['name_ar'] ?? '';
                      final nameEn = surah['name_en'] ?? '';
                      final type = surah['type'] ?? 'Meccan';
                      final totalAyahs = surah['verses_count'] as int;

                      final localizedType = type == 'Meccan'
                          ? (lang == 'ku' ? 'مەککی' : lang == 'ar' ? 'مكية' : 'Meccan')
                          : (lang == 'ku' ? 'مەدەننی' : lang == 'ar' ? 'مدنية' : 'Medinan');
                      final startPage = surah['page'] as int? ?? (DataService.surahStartPages[id] ?? 1);
                      final pageLabel = lang == 'ku' ? 'لاپەڕە $startPage' : (lang == 'ar' ? 'ص $startPage' : 'p. $startPage');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Material(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.4)),
                            ),
                            child: Center(
                              child: Text(
                                '$id',
                                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lang == 'ku' ? nameKu : lang == 'ar' ? nameAr : nameEn,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    fontFamily: 'Rabar',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                nameAr,
                                style: GoogleFonts.amiri(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            '$localizedType • $totalAyahs ${lang == 'ku' ? 'ئایەت' : lang == 'ar' ? 'آيات' : 'Ayahs'} • $pageLabel',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                              fontFamily: 'Rabar',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF10B981)),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SurahViewScreen(
                                  surahId: id,
                                  surahNameKu: nameKu,
                                  surahNameAr: nameAr,
                                  surahNameEn: nameEn,
                                ),
                              ),
                            ).then((_) => _loadLastRead());
                          },
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
      },
    );
  }

  String _normalizeDigits(String input) {
    const easternArabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const westernArabic = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String result = input;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(easternArabic[i], westernArabic[i]);
    }
    return result;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.palette;
    final surahsAsync = ref.watch(surahInfoFutureProvider);
    final bookmarks = ref.watch(bookmarksProvider).where((b) => b.type == 'quran').toList();
    final isRTL = settings.language == 'ku' || settings.language == 'ar';

    final title = settings.language == 'ku' ? 'قورئانی پیرۆز' : settings.language == 'ar' ? 'القرآن الكريم' : 'Holy Quran';
    final searchPlaceholder = settings.language == 'ku'
        ? 'گەڕان بەدوای ناوی سورەت، ژمارە، لاپەڕە یان پارە...'
        : settings.language == 'ar'
        ? 'البحث عن سورة، رقم، صفحة أو جزء...'
        : 'Search Surah, Number, Page or Juz...';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded, color: theme.primaryColor, size: 22),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Rabar')),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Directionality(
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: Column(
          children: [
            // ━━━ LAST READ CARD (QURAN MAJEED GOLD RESUME BANNER) ━━━
            if (_lastSurahId != null && _lastSurahName != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SurahViewScreen(
                          surahId: _lastSurahId!,
                          surahNameKu: _lastSurahName!,
                          surahNameAr: _lastSurahName!,
                          surahNameEn: _lastSurahName!,
                          initialAyahId: _lastAyahNum ?? 1,
                        ),
                      ),
                    ).then((_) => _loadLastRead());
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [theme.cardColor, theme.backgroundColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.bookmark_added, color: Colors.white, size: 24),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                settings.language == 'ar'
                                    ? 'آخر قراءة'
                                    : (settings.language == 'en' ? 'Continue Reading' : 'کۆتا خوێندنەوە'),
                                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '${_lastSurahName!} • ${settings.language == 'ku' ? 'ئایەتی' : settings.language == 'ar' ? 'الآية' : 'Ayah'} ${_lastAyahNum ?? 1}',
                                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Text(
                                settings.language == 'ku'
                                    ? 'درێژەدان'
                                    : settings.language == 'ar'
                                        ? 'متابعة'
                                        : 'Resume',
                                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward, color: Theme.of(context).colorScheme.primary),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
                style: TextStyle(color: Colors.white, fontFamily: 'Rabar'),
                decoration: InputDecoration(
                  hintText: searchPlaceholder,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontFamily: 'Rabar'),
                  prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.white54),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.03),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.04))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                ),
              ),
            ),

            // Tab Bar (Surahs, 30 Juz, Bookmarks)
            TabBar(
              controller: _tabController,
              indicatorColor: Theme.of(context).colorScheme.primary,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.white.withOpacity(0.4),
              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
              tabs: [
                Tab(
                  text: settings.language == 'ku'
                      ? 'سوورەتەکان (١١٤)'
                      : settings.language == 'ar'
                          ? 'السور (١١٤)'
                          : 'Surahs (114)',
                ),
                Tab(
                  text: settings.language == 'ku'
                      ? '٣٠ پارە (Juz)'
                      : settings.language == 'ar'
                          ? '٣٠ جزء'
                          : '30 Juz',
                ),
                Tab(
                  text: settings.language == 'ku'
                      ? 'پاشەکەوتەکان'
                      : settings.language == 'ar'
                          ? 'المحفوظات'
                          : 'Bookmarks',
                ),
              ],
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 1. SURAHS LIST (QURAN MAJEED ELEGANT CARDS)
                  surahsAsync.when(
                    loading: () => Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
                    error: (err, stack) => Center(child: Text('Error: $err', style: TextStyle(color: Colors.white))),
                    data: (surahs) {
                      final normalizedQuery = _normalizeDigits(_searchQuery);
                      final filteredSurahs = surahs.where((s) {
                        if (_searchQuery.isEmpty) return true;
                        final nameKu = (s['name_ku'] ?? '').toString().toLowerCase();
                        final nameAr = (s['name_ar'] ?? '').toString().toLowerCase();
                        final nameEn = (s['name_en'] ?? '').toString().toLowerCase();
                        final idStr = (s['id'] ?? '').toString();
                        final pageStr = (s['page'] ?? '').toString();
                        return nameKu.contains(_searchQuery) ||
                            nameAr.contains(_searchQuery) ||
                            nameEn.contains(_searchQuery) ||
                            idStr == normalizedQuery ||
                            pageStr == normalizedQuery ||
                            _searchQuery == 'p$pageStr' ||
                            _searchQuery == 'لاپەڕە $pageStr' ||
                            _searchQuery == 'صفحة $pageStr';
                      }).toList();

                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        itemCount: filteredSurahs.length,
                        itemBuilder: (context, index) {
                          final surah = filteredSurahs[index];
                          final id = surah['id'] as int;
                          final nameKu = surah['name_ku'] ?? '';
                          final nameAr = surah['name_ar'] ?? '';
                          final nameEn = surah['name_en'] ?? '';
                          final type = surah['type'] ?? 'Meccan';
                          final totalAyahs = surah['verses_count'] as int;
                          final startPage = surah['page'] as int? ?? (DataService.surahStartPages[id] ?? 1);

                          final localizedType = type == 'Meccan'
                              ? (settings.language == 'ku'
                                  ? 'مەککی'
                                  : settings.language == 'ar'
                                      ? 'مكية'
                                      : 'Meccan')
                              : (settings.language == 'ku'
                                  ? 'مەدەننی'
                                  : settings.language == 'ar'
                                      ? 'مدنية'
                                      : 'Medinan');

                          final versesLabel = settings.language == 'ku'
                              ? 'ئایەت'
                              : settings.language == 'ar'
                                  ? 'آيات'
                                  : 'Ayahs';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.15)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
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
                                      builder: (context) => SurahViewScreen(
                                        surahId: id,
                                        surahNameKu: nameKu,
                                        surahNameAr: nameAr,
                                        surahNameEn: nameEn,
                                      ),
                                    ),
                                  ).then((_) => _loadLastRead());
                                },
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.4)),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$id',
                                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        nameAr,
                                        style: GoogleFonts.amiri(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      nameKu,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.6),
                                        fontFamily: 'Rabar',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.04),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            localizedType,
                                            style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6), fontFamily: 'Rabar'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '• $totalAyahs $versesLabel',
                                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4), fontFamily: 'Rabar'),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                                          ),
                                          child: Text(
                                            settings.language == 'ku'
                                                ? 'لاپەڕە $startPage'
                                                : (settings.language == 'ar' ? 'ص $startPage' : 'p. $startPage'),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).colorScheme.primary,
                                              fontFamily: 'Rabar',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  // 2. JUZ LIST (30 JUZ)
                  surahsAsync.when(
                    loading: () => Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
                    error: (err, stack) => Center(child: Text('Error', style: TextStyle(color: Colors.white))),
                    data: (surahs) {
                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        itemCount: 30,
                        itemBuilder: (context, idx) {
                          final juzNum = idx + 1;
                          final surahIds = _juzToSurahIds[juzNum] ?? [1];
                          final firstId = surahIds.first;
                          final lastId = surahIds.last;
                          dynamic firstS;
                          dynamic lastS;
                          for (final s in surahs) {
                            if (s['id'] == firstId) firstS = s;
                            if (s['id'] == lastId) lastS = s;
                          }
                          firstS ??= surahs.first;
                          lastS ??= surahs.last;

                          final pageRange = DataService.juzPageRanges[juzNum] ?? [1, 21];
                          final pageRangeText = settings.language == 'ku'
                              ? 'لاپەڕە ${pageRange[0]} - ${pageRange[1]}'
                              : (settings.language == 'ar'
                                  ? 'الصفحات ${pageRange[0]} - ${pageRange[1]}'
                                  : 'Pages ${pageRange[0]} - ${pageRange[1]}');

                          final subtitleRange = settings.language == 'ku'
                              ? (surahIds.length == 1
                                  ? 'سورەتی ${firstS['name_ku']} • $pageRangeText'
                                  : 'لە ${firstS['name_ku']} تا ${lastS['name_ku']} • $pageRangeText')
                              : (surahIds.length == 1
                                  ? 'سورة ${firstS['name_ar']} • $pageRangeText'
                                  : 'من ${firstS['name_ar']} إلى ${lastS['name_ar']} • $pageRangeText');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                            ),
                            child: Material(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(18),
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.12),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$juzNum',
                                      style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Rabar'),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  settings.language == 'ku'
                                      ? 'پارەی $juzNum (Juz $juzNum)'
                                      : settings.language == 'ar'
                                          ? 'الجزء $juzNum'
                                          : 'Juz $juzNum',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Rabar'),
                                ),
                                subtitle: Text(
                                  subtitleRange,
                                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontFamily: 'Rabar'),
                                ),
                                trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF10B981)),
                                onTap: () {
                                  _showJuzSurahsModal(context, juzNum, surahs, settings.language);
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  // 3. BOOKMARKS LIST
                  bookmarks.isEmpty
                      ? Center(
                          child: Text(
                            settings.language == 'ku'
                                ? 'هیچ ئایەتێک نیشانەنەکراوە'
                                : settings.language == 'ar'
                                    ? 'لا توجد آيات محفوظة'
                                    : 'No bookmarked verses',
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontFamily: 'Rabar'),
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          itemCount: bookmarks.length,
                          itemBuilder: (context, idx) {
                            final b = bookmarks[idx];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                              ),
                              child: Material(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(18),
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  leading: Icon(Icons.bookmark, color: Theme.of(context).colorScheme.primary),
                                  title: Text(
                                    b.title,
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Rabar'),
                                  ),
                                  subtitle: Text(
                                    b.subtitle,
                                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    onPressed: () {
                                      ref.read(bookmarksProvider.notifier).removeBookmark(b.id);
                                    },
                                  ),
                                  onTap: () {
                                    if (b.surahId != null) {
                                      // Extract ayah number from bookmark id (format: quran-{surahId}-{ayahNum})
                                      int initialAyah = 1;
                                      final parts = b.id.split('-');
                                      if (parts.length >= 3) {
                                        initialAyah = int.tryParse(parts.last) ?? 1;
                                      }
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SurahViewScreen(
                                            surahId: b.surahId!,
                                            surahNameKu: b.surahName ?? '',
                                            surahNameAr: b.surahName ?? '',
                                            surahNameEn: b.surahName ?? '',
                                            initialAyahId: initialAyah,
                                          ),
                                        ),
                                      ).then((_) => _loadLastRead());
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
