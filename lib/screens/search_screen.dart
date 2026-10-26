import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../services/data_service.dart';
import '../models/hadith.dart';
import '../models/adhkar.dart';
import 'surah_view_screen.dart';
import 'hadith_adhkar_screen.dart';
import 'kids_stories_screen.dart';
import 'utilities_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _isSearching = false;

  List<Hadith> _hadiths = [];
  List<AdhkarCategory> _adhkarCategories = [];
  Map<String, List<AdhkarItem>> _adhkarData = {};
  List<dynamic> _surahs = [];
  List<dynamic> _qa = [];
  List<dynamic> _kidsStories = [];

  List<SearchResult> _results = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    try {
      final hadiths = await DataService.loadHadiths();
      final adhkarCats = await DataService.loadAdhkarCategories();
      final adhkarItems = await DataService.loadAdhkarData();
      final surahInfo = await DataService.loadSurahInfo();
      final qaList = await DataService.loadQA();
      final kids = await DataService.loadKidsStories();

      if (mounted) {
        setState(() {
          _hadiths = hadiths;
          _adhkarCategories = adhkarCats;
          _adhkarData = adhkarItems;
          _surahs = surahInfo;
          _qa = qaList;
          _kidsStories = kids;
        });
      }
    } catch (e) {
      debugPrint('Error loading datasets: $e');
    }
  }

  Future<void> _performSearch(String text) async {
    if (!mounted) return;
    setState(() {
      _query = text;
    });

    if (text.trim().length < 2) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _isSearching = true);
    final q = text.toLowerCase().trim();
    final List<SearchResult> temp = [];

    final settings = ref.read(settingsProvider);
    final lang = settings.language;

    await Future.delayed(Duration.zero);

    // 1. HADITH
    for (final h in _hadiths) {
      if (h.arabic.toLowerCase().contains(q) ||
          h.translationKu.toLowerCase().contains(q) ||
          h.translationEn.toLowerCase().contains(q) ||
          h.narratorKu.toLowerCase().contains(q)) {
        temp.add(SearchResult(
          id: 'hadith-${h.id}',
          type: SearchResultType.hadith,
          title: lang == 'en'
              ? h.translationEn
              : lang == 'ar'
                  ? h.arabic
                  : h.translationKu,
          subtitle: '${h.collection.toUpperCase()} - #${h.number}',
          icon: Icons.history_edu_rounded,
          originalData: h,
        ));
      }
    }

    // 2. ADHKAR
    _adhkarData.forEach((catId, items) {
      final category = _adhkarCategories.firstWhere(
        (c) => c.id == catId,
        orElse: () => AdhkarCategory(id: catId, ku: '', ar: '', en: '', icon: '', color: '#1B6B3A'),
      );
      final categoryName = lang == 'ar' ? category.ar : lang == 'en' ? category.en : category.ku;

      for (final item in items) {
        if (item.arabic.toLowerCase().contains(q) ||
            item.translationKu.toLowerCase().contains(q) ||
            item.translationEn.toLowerCase().contains(q)) {
          temp.add(SearchResult(
            id: 'adhkar-${item.id}',
            type: SearchResultType.adhkar,
            title: lang == 'en'
                ? (item.translationEn.isNotEmpty ? item.translationEn : item.arabic)
                : lang == 'ar'
                    ? item.arabic
                    : (item.translationKu.isNotEmpty ? item.translationKu : item.arabic),
            subtitle: categoryName,
            icon: Icons.fingerprint_rounded,
            originalData: {
              'categoryId': catId,
              'categoryName': categoryName,
            },
          ));
        }
      }
    });

    // 3. Q&A
    for (final qa in _qa) {
      final qKu = (qa['question_ku'] ?? qa['q_ku'] ?? '').toString();
      final aKu = (qa['answer_ku'] ?? qa['a_ku'] ?? '').toString();
      final qAr = (qa['question_ar'] ?? qa['q_ar'] ?? '').toString();
      final aAr = (qa['answer_ar'] ?? qa['a_ar'] ?? '').toString();
      final qEn = (qa['question_en'] ?? qa['q_en'] ?? '').toString();
      final aEn = (qa['answer_en'] ?? qa['a_en'] ?? '').toString();

      if (qKu.toLowerCase().contains(q) ||
          aKu.toLowerCase().contains(q) ||
          qAr.toLowerCase().contains(q) ||
          aAr.toLowerCase().contains(q) ||
          qEn.toLowerCase().contains(q) ||
          aEn.toLowerCase().contains(q)) {
        final title = lang == 'ar'
            ? (qAr.isNotEmpty ? qAr : qKu)
            : lang == 'en'
                ? (qEn.isNotEmpty ? qEn : qKu)
                : qKu;
        final rawSub = lang == 'ar'
            ? (aAr.isNotEmpty ? aAr : aKu)
            : lang == 'en'
                ? (aEn.isNotEmpty ? aEn : aKu)
                : aKu;
        final sub = rawSub.length > 80 ? '${rawSub.substring(0, 80)}...' : rawSub;
        temp.add(SearchResult(
          id: 'qa-${qa['id'] ?? ''}',
          type: SearchResultType.qa,
          title: title.isNotEmpty ? title : qKu,
          subtitle: sub,
          icon: Icons.help_outline_rounded,
          originalData: qa,
        ));
      }
    }

    // 4. QURAN
    for (final s in _surahs) {
      final id = s['id']?.toString() ?? '';
      final nameAr = s['name_ar']?.toString() ?? '';
      final nameKu = s['name_ku']?.toString() ?? '';
      final nameEn = s['name_en']?.toString() ?? '';

      if (nameAr.toLowerCase().contains(q) ||
          nameKu.toLowerCase().contains(q) ||
          nameEn.toLowerCase().contains(q)) {
        temp.add(SearchResult(
          id: 'quran-$id',
          type: SearchResultType.quran,
          title: lang == 'ar' ? nameAr : lang == 'en' ? nameEn : nameKu,
          subtitle: lang == 'ku'
              ? 'پەڕەی قورئانی پیرۆز - سورەتی $nameKu'
              : lang == 'ar'
                  ? 'القرآن الكريم - سورة $nameAr'
                  : 'Holy Quran Reader - Surah $nameEn',
          icon: Icons.menu_book_rounded,
          originalData: s,
        ));
      }
    }

    // 5. KIDS STORIES
    for (final s in _kidsStories) {
      final tKu = s['title_ku']?.toString() ?? '';
      final tAr = s['title_ar']?.toString() ?? '';
      final tEn = s['title_en']?.toString() ?? '';
      final cKu = s['content_ku']?.toString() ?? '';
      final cAr = s['content_ar']?.toString() ?? '';
      final cEn = s['content_en']?.toString() ?? '';

      if (tKu.toLowerCase().contains(q) ||
          tAr.toLowerCase().contains(q) ||
          tEn.toLowerCase().contains(q) ||
          cKu.toLowerCase().contains(q) ||
          cAr.toLowerCase().contains(q) ||
          cEn.toLowerCase().contains(q)) {
        temp.add(SearchResult(
          id: 'kids-${s['id']}',
          type: SearchResultType.kids,
          title: lang == 'en' ? tEn : lang == 'ar' ? (tAr.isNotEmpty ? tAr : tKu) : tKu,
          subtitle: lang == 'ku'
              ? 'چیرۆک بۆ منداڵان'
              : lang == 'ar'
                  ? 'قصص أطفال'
                  : 'Kids World Story',
          icon: Icons.child_care_rounded,
          originalData: s,
        ));
      }
    }

    if (!mounted) return;
    setState(() {
      _results = temp;
      _isSearching = false;
    });
  }

  void _handleSelectResult(SearchResult result) {
    switch (result.type) {
      case SearchResultType.quran:
        final s = result.originalData;
        final int surahId = int.tryParse(s['id']?.toString() ?? '1') ?? 1;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SurahViewScreen(
              surahId: surahId,
              surahNameKu: (s['name_ku'] ?? '').toString(),
              surahNameAr: (s['name_ar'] ?? '').toString(),
              surahNameEn: (s['name_en'] ?? '').toString(),
            ),
          ),
        );
        break;
        
      case SearchResultType.adhkar:
        final map = result.originalData as Map<String, dynamic>;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdhkarDetailsScreen(
              categoryId: (map['categoryId'] ?? '').toString(),
              categoryName: (map['categoryName'] ?? '').toString(),
            ),
          ),
        );
        break;

      case SearchResultType.kids:
        final story = result.originalData;
        Color themeColor = const Color(0xFFEC4899);
        try {
          final hex = (story['color'] ?? '').toString().replaceAll('#', '');
          if (hex.length == 6) {
            themeColor = Color(int.parse('FF$hex', radix: 16));
          }
        } catch (_) {}
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => KidsStoryViewerScreen(story: story, themeColor: themeColor),
          ),
        );
        break;

      case SearchResultType.qa:
        final qa = result.originalData as Map<String, dynamic>;
        final settings = ref.read(settingsProvider);
        final String q = (settings.language == 'ar'
            ? (qa['question_ar'] ?? qa['question_ku'] ?? qa['q_ku'])
            : settings.language == 'en'
                ? (qa['question_en'] ?? qa['question_ku'] ?? qa['q_ku'])
                : (qa['question_ku'] ?? qa['q_ku']))?.toString() ?? '';
        final String a = (settings.language == 'ar'
            ? (qa['answer_ar'] ?? qa['answer_ku'] ?? qa['a_ku'])
            : settings.language == 'en'
                ? (qa['answer_en'] ?? qa['answer_ku'] ?? qa['a_ku'])
                : (qa['answer_ku'] ?? qa['a_ku']))?.toString() ?? '';
        
        showModalBottomSheet(
          context: context,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    q,
                    style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  SizedBox(height: 10),
                  Text(
                    a,
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15, height: 1.6, fontFamily: 'Rabar'),
                    textAlign: settings.language == 'en' ? TextAlign.left : TextAlign.right,
                  ),
                ],
              ),
            ),
          ),
        );
        break;

      case SearchResultType.hadith:
        final Hadith h = result.originalData as Hadith;
        showModalBottomSheet(
          context: context,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    '${h.collection.toUpperCase()} - #${h.number}',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    h.narratorKu.isNotEmpty ? h.narratorKu : h.narratorAr,
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, fontStyle: FontStyle.italic, fontFamily: 'Rabar'),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  SizedBox(height: 10),
                  Text(
                    h.arabic,
                    style: TextStyle(color: Colors.white, fontSize: 18, height: 1.6, fontFamily: 'Traditional Arabic', fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  if (ref.read(settingsProvider).language != 'ar') ...[
                    SizedBox(height: 14),
                    Text(
                      ref.read(settingsProvider).language == 'en' ? h.translationEn : h.translationKu,
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15, height: 1.5, fontFamily: 'Rabar'),
                      textAlign: ref.read(settingsProvider).language == 'en' ? TextAlign.left : TextAlign.right,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.palette;
    final isRTL = settings.language == 'ku' || settings.language == 'ar';

    final placeholder = settings.language == 'ku'
        ? 'چی دەگەڕێیت؟'
        : settings.language == 'ar'
        ? 'عن ماذا تبحث؟'
        : 'What are you looking for?';

    final noResults = settings.language == 'ku'
        ? 'هیچ ئەنجامێک نەدۆزرایەوە'
        : settings.language == 'ar'
            ? 'لم يتم العثور على نتائج'
            : 'No results found';
    final suggestionTitle = settings.language == 'ku'
        ? 'بگەڕێ بۆ فەرموودە، زیکر، یان سورەتەکان'
        : settings.language == 'ar'
            ? 'ابحث عن حديث أو أذكار أو سور'
            : 'Search for Hadith, Adhkar, or Surahs';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Row Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  IconButton(
                    icon: Icon(isRTL ? Icons.arrow_forward : Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                        children: [
                          Icon(Icons.search, color: Colors.white30, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                              style: TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'Rabar'),
                              decoration: InputDecoration(
                                hintText: placeholder,
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontFamily: 'Rabar'),
                                border: InputBorder.none,
                              ),
                              onChanged: _performSearch,
                            ),
                          ),
                          if (_searchController.text.isNotEmpty || _query.isNotEmpty)
                            IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(Icons.close, color: Colors.white30, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _performSearch('');
                              },
                            )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Results
            Expanded(
              child: _isSearching
                  ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
                  : _searchController.text.trim().length < 2
                      ? _buildSuggestions(suggestionTitle, isRTL)
                      : _results.isEmpty
                          ? _buildNoResults(noResults)
                          : _buildResultsList(isRTL),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions(String title, bool isRTL) {
    final tags = ['نوێژ', 'نەخۆشی', 'دایک', 'تەوبە', 'بەقەرە'];
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, size: 64, color: Theme.of(context).colorScheme.primary.withOpacity(0.15)),
          SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 15, fontFamily: 'Rabar', height: 1.5),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: tags.map((tag) {
              return InkWell(
                onTap: () {
                  _searchController.text = tag;
                  _performSearch(tag);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                  ),
                  child: Text(
                    '#$tag',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.white.withOpacity(0.1)),
          SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16, fontFamily: 'Rabar'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(bool isRTL) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final res = _results[index];
        Color typeColor = Theme.of(context).colorScheme.primary;
        String typeLabel = 'GENERAL';

        final lang = ref.read(settingsProvider).language;
        switch (res.type) {
          case SearchResultType.quran:
            typeColor = const Color(0xFF10B981);
            typeLabel = lang == 'ku' ? 'خوێندنەوە' : lang == 'ar' ? 'قراءة' : 'READ';
            break;
          case SearchResultType.hadith:
            typeColor = const Color(0xFFF59E0B);
            typeLabel = lang == 'ku' ? 'فەرموودە' : lang == 'ar' ? 'حديث' : 'HADITH';
            break;
          case SearchResultType.adhkar:
            typeColor = const Color(0xFF1B6B3A);
            typeLabel = lang == 'ku' ? 'زیکر' : lang == 'ar' ? 'أذكار' : 'ADHKAR';
            break;
          case SearchResultType.qa:
            typeColor = const Color(0xFF8B5CF6);
            typeLabel = lang == 'ku' ? 'پرسیار و وەڵام' : lang == 'ar' ? 'سؤال وجواب' : 'Q&A';
            break;
          case SearchResultType.kids:
            typeColor = const Color(0xFFEC4899);
            typeLabel = lang == 'ku' ? 'منداڵان' : lang == 'ar' ? 'أطفال' : 'KIDS';
            break;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: ListTile(
            onTap: () => _handleSelectResult(res),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(res.icon, color: typeColor, size: 22),
              ),
            ),
            title: Text(
              res.title,
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: isRTL ? TextAlign.right : TextAlign.left,
            ),
            subtitle: Column(
              crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text(
                  res.subtitle,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontFamily: 'Rabar'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: isRTL ? TextAlign.right : TextAlign.left,
                ),
                SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(color: typeColor, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                  ),
                ),
              ],
            ),
            trailing: Icon(
              isRTL ? Icons.chevron_left : Icons.chevron_right,
              size: 16,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        );
      },
    );
  }
}

enum SearchResultType { quran, hadith, adhkar, qa, kids }

class SearchResult {
  final String id;
  final SearchResultType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final dynamic originalData;

  SearchResult({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.originalData,
  });
}
