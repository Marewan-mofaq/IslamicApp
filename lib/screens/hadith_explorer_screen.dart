import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../providers/bookmarks_provider.dart';
import '../services/hadith_book_service.dart';

class HadithExplorer extends ConsumerStatefulWidget {
  const HadithExplorer({super.key});

  @override
  ConsumerState<HadithExplorer> createState() => _HadithExplorerState();
}

class _HadithExplorerState extends ConsumerState<HadithExplorer> {
  // Navigation mode: 'feed' (Hadith-by-Hadith by Category) | 'books' | 'chapters' | 'book_hadiths'
  String _currentMode = 'feed';

  // Selected Category ID
  String _selectedCategoryId = 'all';

  // Selected Book & Chapter data
  String? _selectedBookKey;
  Map<String, dynamic>? _selectedBookInfo;
  dynamic _selectedChapter;
  List<dynamic> _chapters = [];
  List<dynamic> _bookHadiths = [];

  // Feed Hadiths (Curated Hadith-by-Hadith list)
  List<dynamic> _feedHadiths = [];
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Categories list
  static const List<Map<String, String>> _categories = [
    {'id': 'all', 'name_ku': 'هەموو فەرموودەکان', 'name_ar': 'جميع الأحاديث', 'name_en': 'All Hadiths', 'icon': '📜'},
    {'id': 'faith', 'name_ku': 'ئیمان و باوەڕ', 'name_ar': 'الإيمان والتوحيد', 'name_en': 'Faith & Belief', 'icon': '💖'},
    {'id': 'prayer', 'name_ku': 'نوێژ و پەرستش', 'name_ar': 'الصلاة والعبادات', 'name_en': 'Prayer & Worship', 'icon': '🕌'},
    {'id': 'ethics', 'name_ku': 'ڕەوشت و مامەڵە', 'name_ar': 'الأخلاق والآداب', 'name_en': 'Ethics & Manners', 'icon': '🤝'},
    {'id': 'family', 'name_ku': 'خێزان و پەروەردە', 'name_ar': 'الأسرة والتربية', 'name_en': 'Family & Marriage', 'icon': '👨‍👩‍👧‍👦'},
    {'id': 'fasting', 'name_ku': 'ڕۆژوو و ڕەمەزان', 'name_ar': 'الصيام ورمضان', 'name_en': 'Fasting & Ramadan', 'icon': '🌙'},
    {'id': 'zakat', 'name_ku': 'زەکات و سەدەقە', 'name_ar': 'الزكاة والصدقات', 'name_en': 'Zakat & Charity', 'icon': '💰'},
    {'id': 'dua', 'name_ku': 'دوعا و زیکرەکان', 'name_ar': 'الدعاء والأذكار', 'name_en': 'Dua & Adhkar', 'icon': '🛡️'},
    {'id': 'books', 'name_ku': '📁 بەپێی کتێبەکان', 'name_ar': 'حسب الكتب', 'name_en': 'By Books', 'icon': '📚'},
  ];

  @override
  void initState() {
    super.initState();
    _loadFeedHadiths();
  }

  Future<void> _loadFeedHadiths() async {
    setState(() => _isLoading = true);
    try {
      final kurdishBook = await HadithBookService.loadBook('kurdish');
      if (mounted) {
        setState(() {
          _feedHadiths = (kurdishBook?['hadiths'] as List<dynamic>?) ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _feedHadiths = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> _getFilteredFeedHadiths() {
    if (_feedHadiths.isEmpty) return [];
    return _feedHadiths.where((h) {
      if (h == null) return false;
      final arabic = (h['arabic'] ?? '').toString().toLowerCase();
      final kurdish = (h['kurdish']?['text'] ?? '').toString().toLowerCase();
      final narrator = (h['kurdish']?['narrator'] ?? h['narrator_ar'] ?? '').toString().toLowerCase();
      final idNum = (h['idInBook'] ?? h['id'] ?? '').toString();

      // Filter by category
      bool matchCategory = true;
      if (_selectedCategoryId != 'all' && _selectedCategoryId != 'books') {
        if (_selectedCategoryId == 'faith') matchCategory = arabic.contains('إيمان') || arabic.contains('إله') || arabic.contains('توحيد') || kurdish.contains('ئیمان') || kurdish.contains('باوەڕ') || kurdish.contains('خودا');
        if (_selectedCategoryId == 'prayer') matchCategory = arabic.contains('صلاة') || arabic.contains('صلوا') || arabic.contains('وضوء') || kurdish.contains('نوێژ') || kurdish.contains('دەستنوێژ');
        if (_selectedCategoryId == 'ethics') matchCategory = arabic.contains('خلق') || arabic.contains('أخلاق') || arabic.contains('أمانة') || kurdish.contains('ڕەوشت') || kurdish.contains('ڕاستگۆ') || kurdish.contains('ئەخلاق');
        if (_selectedCategoryId == 'family') matchCategory = arabic.contains('امرأة') || arabic.contains('زوج') || arabic.contains('أهل') || kurdish.contains('خێزان') || kurdish.contains('ژن') || kurdish.contains('هاوسەر');
        if (_selectedCategoryId == 'fasting') matchCategory = arabic.contains('صوم') || arabic.contains('صام') || arabic.contains('صائم') || arabic.contains('رمضان') || arabic.contains('سحور') || kurdish.contains('ڕۆژوو') || kurdish.contains('روژوو') || kurdish.contains('ڕەمەزان') || kurdish.contains('بەربانگ') || kurdish.contains('پاراشیو');
        if (_selectedCategoryId == 'zakat') matchCategory = arabic.contains('صدقة') || arabic.contains('زكاة') || arabic.contains('مال') || kurdish.contains('زەکات') || kurdish.contains('بەخشین') || kurdish.contains('سەدەقە');
        if (_selectedCategoryId == 'dua') matchCategory = arabic.contains('دعاء') || arabic.contains('ذكر') || arabic.contains('استغفار') || kurdish.contains('دوعا') || kurdish.contains('زیکر') || kurdish.contains('پاڕانەوە');
      }

      // Filter by search query
      bool matchQuery = true;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        matchQuery = arabic.contains(q) || kurdish.contains(q) || narrator.contains(q) || idNum == q;
      }

      return matchCategory && matchQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.palette;
    final isRTL = settings.language == 'ku' || settings.language == 'ar';

    return PopScope(
      canPop: _currentMode == 'feed',
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentMode == 'book_hadiths') {
          setState(() => _currentMode = 'chapters');
        } else if (_currentMode == 'chapters') {
          setState(() {
            _currentMode = 'books';
            _selectedBookKey = null;
            _selectedBookInfo = null;
          });
        } else if (_currentMode == 'books') {
          setState(() {
            _currentMode = 'feed';
            _selectedCategoryId = 'all';
          });
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Directionality(
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          child: Column(
            children: [
              // Header Title
              _buildHeaderTitle(isRTL, settings.language),

              // Categories Horizontal Scroll Filter Bar
              _buildCategoriesFilterBar(settings.language),

              // Main Body Content
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
                    : _buildMainContent(isRTL, settings.language),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderTitle(bool isRTL, String lang) {
    String title = lang == 'ku'
        ? '📖 گەنجینەی فەرموودە پێغەمبەرییەکان'
        : lang == 'ar'
            ? '📖 موسوعة الأحاديث النبوية'
            : '📖 Holy Hadith Encyclopedia';
    if (_currentMode == 'chapters' && _selectedBookInfo != null) {
      title = lang == 'ku'
          ? (_selectedBookInfo!['name_ku'] ?? '')
          : lang == 'ar'
              ? (_selectedBookInfo!['name_ar'] ?? '')
              : (_selectedBookInfo!['name_en'] ?? _selectedBookInfo!['name_ar'] ?? '');
    } else if (_currentMode == 'book_hadiths' && _selectedChapter != null) {
      title = _selectedChapter['arabic'] ?? _selectedChapter['english'] ?? '';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          if (_currentMode != 'feed')
            IconButton(
              icon: Icon(isRTL ? Icons.arrow_forward : Icons.arrow_back, color: Theme.of(context).colorScheme.primary),
              onPressed: () {
                if (_currentMode == 'book_hadiths') {
                  setState(() => _currentMode = 'chapters');
                } else if (_currentMode == 'chapters') {
                  setState(() {
                    _currentMode = 'books';
                    _selectedBookKey = null;
                    _selectedBookInfo = null;
                  });
                } else if (_currentMode == 'books') {
                  setState(() {
                    _currentMode = 'feed';
                    _selectedCategoryId = 'all';
                  });
                }
              },
            ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: isRTL ? TextAlign.right : TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesFilterBar(String lang) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final id = cat['id'] ?? 'all';
          final name = (lang == 'en' ? cat['name_en'] : lang == 'ar' ? cat['name_ar'] : cat['name_ku']) ?? cat['name_ku'] ?? '';
          final icon = cat['icon'] ?? '📜';
          final isSelected = (_currentMode == 'feed' && _selectedCategoryId == id) || (_currentMode == 'books' && id == 'books');

          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8.0),
            child: ChoiceChip(
              avatar: Text(icon, style: TextStyle(fontSize: 14)),
              label: Text(
                name,
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
                if (id == 'books') {
                  setState(() {
                    _currentMode = 'books';
                    _selectedCategoryId = 'books';
                  });
                } else {
                  setState(() {
                    _currentMode = 'feed';
                    _selectedCategoryId = id;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent(bool isRTL, String lang) {
    if (_currentMode == 'books') {
      return _buildBooksGrid(isRTL, lang);
    } else if (_currentMode == 'chapters') {
      return _buildChaptersList(isRTL, lang);
    } else if (_currentMode == 'book_hadiths') {
      return _buildBookHadithsList(isRTL, lang);
    }

    // Default 'feed' Hadith-by-Hadith View
    return _buildHadithFeed(isRTL, lang);
  }

  Widget _buildHadithFeed(bool isRTL, String lang) {
    final filtered = _getFilteredFeedHadiths();

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            style: const TextStyle(color: Colors.white, fontFamily: 'Rabar'),
            decoration: InputDecoration(
              hintText: lang == 'ar'
                  ? 'البحث في الأحاديث حسب النص أو الموضوع...'
                  : lang == 'en'
                      ? 'Search hadiths by text or topic...'
                      : 'گەڕان لەناو فەرموودەکان بەپێی دەق یان بەش...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontFamily: 'Rabar'),
              prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
              filled: true,
              fillColor: Colors.white.withOpacity(0.03),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    lang == 'ar'
                        ? 'لم يتم العثور على أي حديث في هذا القسم'
                        : lang == 'en'
                            ? 'No hadiths found in this category'
                            : 'هیچ فەرموودەیەک لەم کاتێگۆرییەدا نەدۆزرایەوە',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontFamily: 'Rabar'),
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final h = filtered[index];
                    final idInBook = h['idInBook']?.toString() ?? '${index + 1}';
                    final arabic = h['arabic']?.toString() ?? '';
                    final kurdish = h['kurdish']?['text']?.toString() ?? '';
                    final narrator = h['kurdish']?['narrator'] ?? h['narrator_ar'] ?? '';

                    return _buildHadithCard(
                      id: idInBook,
                      arabic: arabic,
                      kurdish: kurdish,
                      narrator: narrator.toString(),
                      isRTL: isRTL,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHadithCard({
    required String id,
    required String arabic,
    required String kurdish,
    required String narrator,
    required bool isRTL,
  }) {
    final lang = ref.read(settingsProvider).language;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hadith Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.4)),
                    ),
                    child: Text(
                      lang == 'ku' ? 'فەرموودەی #$id' : lang == 'ar' ? 'الحديث #$id' : 'Hadith #$id',
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Bookmark Button
                    IconButton(
                      icon: const Icon(Icons.bookmark_border, color: Color(0xFF10B981), size: 18),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      tooltip: lang == 'ku' ? 'پاشەکەوت' : lang == 'ar' ? 'حفظ' : 'Bookmark',
                      onPressed: () {
                        ref.read(bookmarksProvider.notifier).addBookmark(
                          BookmarkItem(
                            id: 'hadith-$id',
                            title: lang == 'ku' ? 'فەرموودەی #$id' : lang == 'ar' ? 'الحديث #$id' : 'Hadith #$id',
                            subtitle: arabic,
                            type: 'hadith',
                          ),
                        );
                        final msg = lang == 'ku' ? 'فەرموودەکە پاشەکەوت کرا' : lang == 'ar' ? 'تم حفظ الحديث' : 'Hadith bookmarked';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg)),
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
                      tooltip: lang == 'ku' ? 'کۆپی' : lang == 'ar' ? 'نسخ' : 'Copy',
                      onPressed: () {
                        final tag = lang == 'ku' ? '[فەرموودەی #$id]' : lang == 'ar' ? '[الحديث #$id]' : '[Hadith #$id]';
                        final fullText = lang == 'ar' ? '$arabic\n\n$tag' : '$arabic\n\n$kurdish\n\n$tag';
                        Clipboard.setData(ClipboardData(text: fullText));
                        final msg = lang == 'ku' ? 'فەرموودەکە کۆپی کرا' : lang == 'ar' ? 'تم نسخ الحديث' : 'Hadith copied';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg)),
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
                      tooltip: lang == 'ku' ? 'بەشداری پێکردن' : lang == 'ar' ? 'مشاركة' : 'Share',
                      onPressed: () {
                        final tag = lang == 'ku' ? '[فەرموودەی #$id]' : lang == 'ar' ? '[الحديث #$id]' : '[Hadith #$id]';
                        final fullText = lang == 'ar' ? '$arabic\n\n$tag' : '$arabic\n\n$kurdish\n\n$tag';
                        Share.share(fullText);
                      },
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),

            // Narrator Tag if available
            if (narrator.isNotEmpty) ...[
              Text(
                lang == 'ku' ? 'گێڕانەوەی: $narrator' : lang == 'ar' ? 'رواه: $narrator' : 'Narrated by: $narrator',
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                textAlign: isRTL ? TextAlign.right : TextAlign.left,
              ),
              SizedBox(height: 8),
            ],

            // Arabic text
            if (arabic.isNotEmpty)
              Text(
                arabic,
                style: GoogleFonts.amiri(
                  color: Colors.white,
                  fontSize: 18,
                  height: 2.0,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
              ),

            // Kurdish translation
            if (kurdish.isNotEmpty && lang != 'ar') ...[
              const Divider(color: Colors.white10, height: 24),
              Text(
                kurdish,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  height: 1.6,
                  fontFamily: 'Rabar',
                ),
                textAlign: isRTL ? TextAlign.right : TextAlign.left,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBooksGrid(bool isRTL, String lang) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: HadithBookService.books.length,
      itemBuilder: (context, index) {
        final b = HadithBookService.books[index];
        final name = lang == 'ku' ? b['name_ku'] : lang == 'ar' ? b['name_ar'] : b['name_en'];

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.15)),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () => _selectBook(b),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(b['icon'] ?? '📖', style: TextStyle(fontSize: 18)),
                          ),
                        ),
                        Icon(Icons.auto_stories, color: Theme.of(context).colorScheme.primary),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name ?? '',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          b['name_ar'] ?? '',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                          maxLines: 1,
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
    );
  }

  Future<void> _selectBook(Map<String, String> book) async {
    setState(() {
      _isLoading = true;
      _selectedBookKey = book['key'];
      _selectedBookInfo = book;
    });

    try {
      final chapters = await HadithBookService.getChapters(_selectedBookKey!);
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _currentMode = 'chapters';
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildChaptersList(bool isRTL, String lang) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: _chapters.length,
      itemBuilder: (context, index) {
        final ch = _chapters[index];
        final chNum = index + 1;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.15)),
          ),
          child: Material(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              onTap: () => _selectChapter(ch),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('$chNum', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar')),
                ),
              ),
              title: Text(
                ch['arabic'] ?? ch['english'] ?? '',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Traditional Arabic'),
              ),
              trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectChapter(dynamic chapter) async {
    setState(() {
      _isLoading = true;
      _selectedChapter = chapter;
    });

    try {
      final chId = chapter['id'] as int;
      final pageData = await HadithBookService.getHadithsByChapter(_selectedBookKey!, chId);
      if (!mounted) return;
      setState(() {
        _bookHadiths = pageData;
        _currentMode = 'book_hadiths';
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildBookHadithsList(bool isRTL, String lang) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: _bookHadiths.length,
      itemBuilder: (context, index) {
        final h = _bookHadiths[index];
        final idInBook = h['idInBook']?.toString() ?? '${index + 1}';
        final arabic = h['arabic']?.toString() ?? '';
        final kurdish = h['kurdish']?['text']?.toString() ?? '';
        final narrator = h['kurdish']?['narrator'] ?? h['narrator_ar'] ?? '';

        return _buildHadithCard(
          id: idInBook,
          arabic: arabic,
          kurdish: kurdish,
          narrator: narrator.toString(),
          isRTL: isRTL,
        );
      },
    );
  }
}
