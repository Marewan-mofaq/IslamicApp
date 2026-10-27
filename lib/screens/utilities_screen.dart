import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/settings_provider.dart';
import '../services/data_service.dart';
import 'bookmarks_screen.dart';
import 'tasbih_screen.dart';
import 'khatam_tracker_screen.dart';
import 'zakat_screen.dart';
import 'situations_screen.dart';
import 'topics_screen.dart';
import 'qibla_screen.dart';
import 'kids_stories_screen.dart';
import 'how_to_pray_screen.dart';
import 'world_prayer_times_screen.dart';

class UtilitiesScreen extends ConsumerStatefulWidget {
  const UtilitiesScreen({super.key});

  @override
  ConsumerState<UtilitiesScreen> createState() => _UtilitiesScreenState();
}

class _UtilitiesScreenState extends ConsumerState<UtilitiesScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'all'; // all, worship, learning, tools
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isRTL = settings.language == 'ku' || settings.language == 'ar';
    final lang = settings.language;

    final title = lang == 'ku' ? 'بەشەکانی تر' : lang == 'ar' ? 'أقسام أخرى' : 'Explore Sections';
    final searchHint = lang == 'ku' ? 'گەڕان لە بەشەکاندا...' : lang == 'ar' ? 'البحث في الأقسام...' : 'Search sections...';

    final List<Map<String, dynamic>> allItems = [
      {
        'id': 'world_prayer_times',
        'category': 'worship',
        'title': lang == 'ku' ? 'کاتەکانی بانگی جیهان' : lang == 'ar' ? 'مواقيت الصلاة العالمية' : 'World Prayer Times',
        'desc': lang == 'ku' ? 'کاتەکانی بانگی هەموو شار و وڵاتانی جیهان' : lang == 'ar' ? 'أوقات الأذان لجميع دول ومدن العالم' : 'Prayer times for all countries & cities worldwide',
        'icon': Icons.public_rounded,
        'color': const Color(0xFF0EA5E9),
        'screen': const WorldPrayerTimesScreen(),
      },
      {
        'id': 'tasbih',
        'category': 'worship',
        'title': lang == 'ku' ? 'تەسبێحی زیرەک' : lang == 'ar' ? 'المسبحة الإلكترونية' : 'Digital Tasbih',
        'desc': lang == 'ku' ? 'تەسبێحی ئەلیکترۆنی لەگەڵ ئاماری ژمارەکان' : lang == 'ar' ? 'مسبحة إلكترونية مع العداد' : 'Digital Tasbih with target count',
        'icon': Icons.fingerprint_rounded,
        'color': Theme.of(context).colorScheme.primary,
        'screen': const TasbihScreen(),
      },
      {
        'id': 'khatam',
        'category': 'worship',
        'title': lang == 'ku' ? 'خەتمی قورئان' : lang == 'ar' ? 'ختم القرآن' : 'Khatam Tracker',
        'desc': lang == 'ku' ? 'پلاندانان بۆ خەتمکردنی قورئانی پیرۆز' : lang == 'ar' ? 'خطة تتبع ختم القرآن الكريم' : 'Plan and track your Quran recitation',
        'icon': Icons.menu_book_rounded,
        'color': const Color(0xFF10B981),
        'screen': const KhatamTrackerScreen(),
      },
      {
        'id': 'qibla',
        'category': 'worship',
        'title': lang == 'ku' ? 'ئاراستەی قیبلە' : lang == 'ar' ? 'اتجاه القبلة' : 'Qibla Finder',
        'desc': lang == 'ku' ? 'دیاریکردنی ئاراستەی قیبلە بۆ نوێژ' : lang == 'ar' ? 'بوصلة دقيقة لتحديد القبلة' : 'Accurate compass for Qibla direction',
        'icon': Icons.explore_rounded,
        'color': Theme.of(context).colorScheme.primary,
        'screen': const QiblaScreen(),
      },
      {
        'id': 'how_to_pray',
        'category': 'worship',
        'title': lang == 'ku' ? 'چۆنیەتی نوێژ' : lang == 'ar' ? 'كيفية الصلاة' : 'How to Pray',
        'desc': lang == 'ku' ? 'فێربوونی هەنگاو بە هەنگاوی نوێژکردن' : lang == 'ar' ? 'تعلم كيفية الصلاة خطوة بخطوة' : 'Step-by-step guide to Islamic prayer',
        'icon': Icons.accessibility_new_rounded,
        'color': const Color(0xFF6366F1),
        'screen': const HowToPrayScreen(),
      },
      {
        'id': 'sunnah',
        'category': 'worship',
        'title': lang == 'ku' ? 'سوننەتەکانی ڕۆژانە' : lang == 'ar' ? 'سنن اليوم' : 'Daily Sunnahs',
        'desc': lang == 'ku' ? 'کردەوە و سوننەتە بەسوودەکانی پێغەمبەر' : lang == 'ar' ? 'السنن اليومية للنبي صلى الله عليه وسلم' : 'Daily Sunnah habits of Prophet Muhammad',
        'icon': Icons.wb_sunny_rounded,
        'color': const Color(0xFF10B981),
        'screen': const SunnahScreen(),
      },
      {
        'id': 'names',
        'category': 'learning',
        'title': lang == 'ku' ? 'ناوە جوانەکانی خودا' : lang == 'ar' ? 'أسماء الله الحسنى' : '99 Names of Allah',
        'desc': lang == 'ku' ? 'ناوە پیرۆزەکانی الله لەگەڵ ماناکانیان' : lang == 'ar' ? 'أسماء الله الحسنى ومعانيها' : '99 Beautiful Names of Allah and meanings',
        'icon': Icons.auto_awesome_rounded,
        'color': const Color(0xFFF59E0B),
        'screen': const NamesScreen(),
      },
      {
        'id': 'qa',
        'category': 'learning',
        'title': lang == 'ku' ? 'پرسیار و وەڵام' : lang == 'ar' ? 'أسئلة وأجوبة' : 'Islamic Q&A',
        'desc': lang == 'ku' ? 'وەڵامی پرسیارە ئایینی و شەرعییەکان' : lang == 'ar' ? 'إجابات على الأسئلة الدينية' : 'Answers to common Islamic questions',
        'icon': Icons.help_outline_rounded,
        'color': const Color(0xFF8B5CF6),
        'screen': const QAScreen(),
      },
      {
        'id': 'stories',
        'category': 'learning',
        'title': lang == 'ku' ? 'چیرۆکی منداڵان' : lang == 'ar' ? 'قصص الأطفال' : 'Kids Stories',
        'desc': lang == 'ku' ? 'چیرۆکی ئامۆژگاری و پەروەردەیی منداڵان' : lang == 'ar' ? 'قصص إسلامية تعليمية للأطفال' : 'Educational Islamic stories for children',
        'icon': Icons.child_care_rounded,
        'color': const Color(0xFFEC4899),
        'screen': const KidsStoriesScreen(),
      },
      {
        'id': 'hajj',
        'category': 'learning',
        'title': lang == 'ku' ? 'ڕێبەری حەج و عومرە' : lang == 'ar' ? 'دليل الحج والعمرة' : 'Hajj & Umrah Guide',
        'desc': lang == 'ku' ? 'ڕێنمایی و کارەکانی حەج و عومرە' : lang == 'ar' ? 'دليل شامل لخطوات الحج والعمرة' : 'Complete step-by-step Hajj & Umrah guide',
        'icon': Icons.mosque_rounded,
        'color': const Color(0xFF64748B),
        'screen': const HajjScreen(),
      },
      {
        'id': 'topics',
        'category': 'learning',
        'title': lang == 'ku' ? 'بابەتەکانی قورئان' : lang == 'ar' ? 'مواضيع القرآن' : 'Quran Topics',
        'desc': lang == 'ku' ? 'دۆزینەوەی ئایەتەکان بەپێی بابەت' : lang == 'ar' ? 'استكشاف الآيات حسب الموضوع' : 'Explore Quranic verses categorized by topic',
        'icon': Icons.category_rounded,
        'color': Colors.cyan,
        'screen': const TopicsScreen(),
      },
      {
        'id': 'situations',
        'category': 'tools',
        'title': lang == 'ku' ? 'چۆن هەست دەکەیت؟' : lang == 'ar' ? 'بماذا تشعر؟' : 'How do you feel?',
        'desc': lang == 'ku' ? 'دوعا و ئایەت بەپێی باری دەروونیت' : lang == 'ar' ? 'أدعية وآيات للمشاعر المختلفة' : 'Quranic verses and duas for your current emotion',
        'icon': Icons.sentiment_satisfied_alt_rounded,
        'color': Colors.blueAccent,
        'screen': const SituationsScreen(),
      },
      {
        'id': 'zakat',
        'category': 'tools',
        'title': lang == 'ku' ? 'ژمێرەری زەکات' : lang == 'ar' ? 'حاسبة الزكاة' : 'Zakat Calculator',
        'desc': lang == 'ku' ? 'حیسابکردنی زەکاتی دارایی، زێڕ و زیو' : lang == 'ar' ? 'حساب زكاة المال والذهب' : 'Calculate Zakat on wealth and gold',
        'icon': Icons.account_balance_wallet_rounded,
        'color': Colors.amber,
        'screen': const ZakatScreen(),
      },
      {
        'id': 'bookmarks',
        'category': 'tools',
        'title': lang == 'ku' ? 'دڵخوازەکان' : lang == 'ar' ? 'المفضلة' : 'Bookmarks',
        'desc': lang == 'ku' ? 'ئایەت و فەرموودە پاشەکەوتکراوەکانت' : lang == 'ar' ? 'المحفوظات الخاصة بك' : 'Your saved verses, hadiths, and adhkar',
        'icon': Icons.bookmark_rounded,
        'color': Colors.orangeAccent,
        'screen': const BookmarksScreen(),
      },
    ];

    final filteredItems = allItems.where((item) {
      final matchesCat = _selectedCategory == 'all' || item['category'] == _selectedCategory;
      if (!matchesCat) return false;

      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final titleStr = (item['title'] ?? '').toString().toLowerCase();
      final descStr = (item['desc'] ?? '').toString().toLowerCase();
      return titleStr.contains(q) || descStr.contains(q);
    }).toList();

    final theme = settings.palette;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar')),
        centerTitle: true,
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
      ),
      body: Directionality(
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
                style: TextStyle(color: Colors.white, fontFamily: 'Rabar'),
                decoration: InputDecoration(
                  hintText: searchHint,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontFamily: 'Rabar', fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 18, color: Colors.white),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.04))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                ),
              ),
            ),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  _buildCategoryPill('all', lang == 'ku' ? 'هەمووی' : lang == 'ar' ? 'الكل' : 'All', Icons.grid_view_rounded),
                  _buildCategoryPill('worship', lang == 'ku' ? 'عیبادەت' : lang == 'ar' ? 'عبادة' : 'Worship', Icons.mosque_rounded),
                  _buildCategoryPill('learning', lang == 'ku' ? 'فێربوون' : lang == 'ar' ? 'تعليم' : 'Learning', Icons.school_rounded),
                  _buildCategoryPill('tools', lang == 'ku' ? 'ئامرازەکان' : lang == 'ar' ? 'أدوات' : 'Tools', Icons.build_circle_rounded),
                ],
              ),
            ),

            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: Text(
                        lang == 'ku' ? 'هیچ بەشێک نەدۆزرایەوە' : lang == 'ar' ? 'لم يتم العثور على أي قسم' : 'No sections found',
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontFamily: 'Rabar', fontSize: 14),
                      ),
                    )
                  : GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final Color color = item['color'] as Color;

                        return Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
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
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => item['screen'] as Widget),
                                );
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                color.withOpacity(0.28),
                                                color.withOpacity(0.08),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: color.withOpacity(0.45), width: 1.2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: color.withOpacity(0.2),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Icon(
                                              item['icon'] as IconData? ?? Icons.grid_view_rounded,
                                              size: 22,
                                              color: color,
                                            ),
                                          ),
                                        ),
                                        Icon(Icons.arrow_forward_ios, color: Theme.of(context).colorScheme.primary, size: 14),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (item['title'] ?? '').toString(),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontFamily: 'Rabar',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 3),
                                        Text(
                                          (item['desc'] ?? '').toString(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white.withOpacity(0.5),
                                            fontFamily: 'Rabar',
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
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

  Widget _buildCategoryPill(String id, String label, IconData icon) {
    final isSelected = _selectedCategory == id;
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: ChoiceChip(
        avatar: Icon(
          icon,
          size: 16,
          color: isSelected ? Colors.black : Theme.of(context).colorScheme.primary,
        ),
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            fontFamily: 'Rabar',
          ),
        ),
        selected: isSelected,
        selectedColor: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white.withOpacity(0.05)),
        ),
        onSelected: (val) {
          setState(() {
            _selectedCategory = id;
          });
        },
      ),
    );
  }
}

// ━━━━ 1. FULL NAMES OF ALLAH SCREEN ━━━━
class NamesScreen extends ConsumerStatefulWidget {
  const NamesScreen({super.key});

  @override
  ConsumerState<NamesScreen> createState() => _NamesScreenState();
}

class _NamesScreenState extends ConsumerState<NamesScreen> {
  String _query = '';
  Future<List<dynamic>>? _namesFuture;

  @override
  void initState() {
    super.initState();
    _namesFuture = DataService.loadNames();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final lang = settings.language;

    final screenTitle = lang == 'ku' ? 'ناوە جوانەکانی خودا (٩٩)' : lang == 'ar' ? 'أسماء الله الحسنى (٩٩)' : '99 Names of Allah';
    final searchHint = lang == 'ku' ? 'گەڕان بەدوای نێودا...' : lang == 'ar' ? 'البحث عن اسم...' : 'Search by name...';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(screenTitle, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        backgroundColor: Theme.of(context).cardColor,
        centerTitle: true,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _namesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));

          final names = snapshot.data!.where((n) {
            if (_query.isEmpty) return true;
            final q = _query.toLowerCase();
            final ar = (n['arabic'] ?? n['name_ar'] ?? '').toString().toLowerCase();
            final ku = (n['ku'] ?? n['name_ku'] ?? '').toString().toLowerCase();
            final en = (n['en'] ?? n['name_en'] ?? '').toString().toLowerCase();
            final meaningKu = (n['benefit_ku'] ?? '').toString().toLowerCase();
            final meaningAr = (n['benefit_ar'] ?? '').toString().toLowerCase();
            final meaningEn = (n['benefit_en'] ?? '').toString().toLowerCase();
            return ar.contains(q) || ku.contains(q) || en.contains(q) || meaningKu.contains(q) || meaningAr.contains(q) || meaningEn.contains(q);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v.trim()),
                  style: TextStyle(color: Colors.white, fontFamily: 'Rabar'),
                  decoration: InputDecoration(
                    hintText: searchHint,
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontFamily: 'Rabar'),
                    prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: names.length,
                  itemBuilder: (context, idx) {
                    final item = names[idx];
                    final num = item['id'] ?? (idx + 1);
                    final ar = item['arabic'] ?? item['name_ar'] ?? item['name'] ?? '';
                    final subTitle = lang == 'en'
                        ? (item['en'] ?? item['name_en'] ?? '')
                        : lang == 'ar'
                            ? ar
                            : (item['ku'] ?? item['name_ku'] ?? '');
                    final meaning = lang == 'en'
                        ? (item['benefit_en'] ?? item['en'] ?? '')
                        : lang == 'ar'
                            ? (item['benefit_ar'] ?? ar)
                            : (item['benefit_ku'] ?? item['ku'] ?? '');

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Align(
                            alignment: Alignment.topLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                              child: Text('#$num', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                            ),
                          ),
                          Text(
                            ar,
                            style: GoogleFonts.amiri(fontSize: 22, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                          ),
                          Column(
                            children: [
                              Text(subTitle, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Rabar')),
                              SizedBox(height: 2),
                              Text(
                                meaning,
                                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontFamily: 'Rabar'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ━━━━ 2. DAILY SUNNAHS SCREEN ━━━━
class SunnahScreen extends ConsumerStatefulWidget {
  const SunnahScreen({super.key});

  @override
  ConsumerState<SunnahScreen> createState() => _SunnahScreenState();
}

class _SunnahScreenState extends ConsumerState<SunnahScreen> {
  Future<List<dynamic>>? _sunnahsFuture;

  @override
  void initState() {
    super.initState();
    _sunnahsFuture = DataService.loadSunnahs();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final lang = settings.language;

    final screenTitle = lang == 'ku' ? 'سوننەتەکانی ڕۆژانە' : lang == 'ar' ? 'السنن اليومية' : 'Daily Sunnahs';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(screenTitle, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        backgroundColor: Theme.of(context).cardColor,
        centerTitle: true,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _sunnahsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
          final list = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(18),
            physics: const BouncingScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (context, idx) {
              final item = list[idx];
              final title = lang == 'en' ? (item['en'] ?? '') : lang == 'ar' ? (item['ar'] ?? '') : (item['ku'] ?? '');
              final desc = lang == 'en' ? (item['source_en'] ?? '') : lang == 'ar' ? (item['source_ar'] ?? item['source_ku'] ?? '') : (item['source_ku'] ?? 'سەنەد');

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                              child: Text(desc.isNotEmpty ? desc : 'Sunnah', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Rabar')),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.share, color: Colors.white38, size: 18),
                          onPressed: () => Share.share('$title\n\n[$desc]'),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, height: 1.6, fontFamily: 'Rabar')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ━━━━ 3. ISLAMIC Q&A SCREEN ━━━━
class QAScreen extends ConsumerStatefulWidget {
  const QAScreen({super.key});

  @override
  ConsumerState<QAScreen> createState() => _QAScreenState();
}

class _QAScreenState extends ConsumerState<QAScreen> {
  int? _expandedIndex;
  Future<List<dynamic>>? _qaFuture;

  @override
  void initState() {
    super.initState();
    _qaFuture = DataService.loadQA();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final lang = settings.language;

    final screenTitle = lang == 'ku' ? 'پرسیار و وەڵامی ئایینی' : lang == 'ar' ? 'أسئلة وأجوبة إسلامية' : 'Islamic Q&A';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(screenTitle, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        backgroundColor: Theme.of(context).cardColor,
        centerTitle: true,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _qaFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
          final list = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(18),
            physics: const BouncingScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (context, idx) {
              final item = list[idx];
              final q = lang == 'en' ? (item['question_en'] ?? '') : lang == 'ar' ? (item['question_ar'] ?? '') : (item['question_ku'] ?? '');
              final a = lang == 'en' ? (item['answer_en'] ?? '') : lang == 'ar' ? (item['answer_ar'] ?? '') : (item['answer_ku'] ?? '');
              final isExpanded = _expandedIndex == idx;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    ListTile(
                      onTap: () => setState(() => _expandedIndex = isExpanded ? null : idx),
                      title: Text(q, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Rabar')),
                      trailing: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Theme.of(context).colorScheme.primary),
                    ),
                    if (isExpanded) ...[
                      const Divider(color: Colors.white10, height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          a,
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14, height: 1.7, fontFamily: 'Rabar'),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ━━━━ 4. HAJJ & UMRAH GUIDE SCREEN ━━━━
class HajjScreen extends ConsumerStatefulWidget {
  const HajjScreen({super.key});

  @override
  ConsumerState<HajjScreen> createState() => _HajjScreenState();
}

class _HajjScreenState extends ConsumerState<HajjScreen> {
  Future<List<dynamic>>? _hajjFuture;

  @override
  void initState() {
    super.initState();
    _hajjFuture = DataService.loadHajjGuide();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final lang = settings.language;

    final screenTitle = lang == 'ku' ? 'ڕێبەری حەج و عومرە' : lang == 'ar' ? 'دليل الحج والعمرة' : 'Hajj & Umrah Guide';
    final tabUmrah = lang == 'ku' ? 'کارەکانی عومرە' : lang == 'ar' ? 'العمرة' : 'Umrah Steps';
    final tabHajj = lang == 'ku' ? 'هەنگاوەکانی حەج' : lang == 'ar' ? 'الحج' : 'Hajj Steps';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(screenTitle, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          backgroundColor: Theme.of(context).cardColor,
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.white54,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
            tabs: [
              Tab(text: tabUmrah),
              Tab(text: tabHajj),
            ],
          ),
        ),
        body: FutureBuilder<List<dynamic>>(
          future: _hajjFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
            final data = snapshot.data!;

            final umrahSteps = data.where((e) => (e['type'] ?? 'umrah') == 'umrah').toList();
            final hajjSteps = data.where((e) => (e['type'] ?? '') == 'hajj').toList();

            return TabBarView(
              children: [
                _buildGuideList(umrahSteps.isEmpty ? data : umrahSteps, lang),
                _buildGuideList(hajjSteps.isEmpty ? data : hajjSteps, lang),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGuideList(List<dynamic> steps, String lang) {
    return ListView.builder(
      padding: const EdgeInsets.all(18),
      physics: const BouncingScrollPhysics(),
      itemCount: steps.length,
      itemBuilder: (context, idx) {
        final step = steps[idx];
        final num = idx + 1;
        final title = lang == 'en' ? (step['title_en'] ?? '') : lang == 'ar' ? (step['title_ar'] ?? '') : (step['title_ku'] ?? '');
        final desc = lang == 'en' ? (step['desc_en'] ?? '') : (step['desc_ku'] ?? '');
        final duas = step['duas'] as List?;
        final firstDua = duas != null && duas.isNotEmpty ? duas.first : null;
        final dhikrAr = firstDua != null ? (firstDua['ar'] ?? '') : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text('$num', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(title, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Rabar')),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13, height: 1.6, fontFamily: 'Rabar')),
              if (dhikrAr.toString().isNotEmpty) ...[
                SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(12)),
                  child: Text(dhikrAr.toString(), style: GoogleFonts.amiri(color: Theme.of(context).colorScheme.primary, fontSize: 16, height: 1.8), textAlign: TextAlign.right),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
