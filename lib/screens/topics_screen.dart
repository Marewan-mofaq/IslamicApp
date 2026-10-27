import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import 'surah_view_screen.dart';

class TopicsScreen extends ConsumerStatefulWidget {
  const TopicsScreen({super.key});

  @override
  ConsumerState<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends ConsumerState<TopicsScreen> {
  Map<String, dynamic>? _selectedTopic;
  Future<List<dynamic>>? _topicsFuture;

  @override
  void initState() {
    super.initState();
    _topicsFuture = _loadTopics();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.palette;
    final isRTL = settings.language == 'ku' || settings.language == 'ar';

    final title = settings.language == 'ku' ? 'بابەتەکانی قورئان' : settings.language == 'ar' ? 'مواضيع القرآن' : 'Quran Topics';

    return PopScope(
      canPop: _selectedTopic == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _selectedTopic = null);
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Directionality(
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: FutureBuilder<List<dynamic>>(
          future: _topicsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
            }

            if (!snapshot.hasData || snapshot.data == null) {
              return Center(child: Text('No data found.'));
            }

            final data = snapshot.data!;

            return Stack(
              children: [
                ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];
                    final name = (settings.language == 'ar'
                        ? (item['ar'] ?? item['ku'])
                        : settings.language == 'en'
                        ? (item['en'] ?? item['ku'])
                        : item['ku'])?.toString() ?? '';
                    final verses = item['verses'] as List<dynamic>? ?? [];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: ListTile(
                        onTap: () {
                          setState(() {
                            _selectedTopic = item;
                          });
                        },
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          child: Icon(Icons.bookmark_border_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${verses.length} ' + (settings.language == 'ku' ? 'ئایەت' : settings.language == 'ar' ? 'آيات' : 'verses'),
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4)),
                        ),
                        trailing: Icon(Icons.chevron_right, size: 18, color: Colors.white.withOpacity(0.3)),
                      ),
                    );
                  },
                ),

                // Verses Overlay
                if (_selectedTopic != null)
                  _buildVersesOverlay(_selectedTopic!, settings.language, isRTL),
              ],
            );
          },
        ),
      ),
    ),
    );
  }

  Future<List<dynamic>> _loadTopics() async {
    final raw = await DefaultAssetBundle.of(context).loadString('assets/data/topics.json');
    return jsonDecode(raw) as List<dynamic>;
  }

  Widget _buildVersesOverlay(Map<String, dynamic> topic, String lang, bool isRTL) {
    final title = (lang == 'ar'
        ? (topic['ar'] ?? topic['ku'])
        : lang == 'en'
        ? (topic['en'] ?? topic['ku'])
        : topic['ku'])?.toString() ?? '';

    final List<dynamic> verses = topic['verses'] ?? [];

    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Container(
        margin: const EdgeInsets.only(top: 80),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            // Header bar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bookmark_border_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        title,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: isRTL ? 'Rabar' : null),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 28),
                    onPressed: () {
                      setState(() {
                        _selectedTopic = null;
                      });
                    },
                  )
                ],
              ),
            ),

            // Verses List
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                itemCount: verses.length,
                itemBuilder: (context, idx) {
                  final verse = verses[idx];
                  final surahNum = verse['surah'] as int;
                  final verseNum = verse['verse'] as int;
                  final verseTitle = (lang == 'en')
                      ? (verse['title_en'] as String? ?? 'Surah $surahNum : $verseNum')
                      : (lang == 'ar')
                          ? (verse['title_ar'] as String? ?? 'سورة $surahNum : $verseNum')
                          : (verse['title'] as String? ?? 'سورەتی $surahNum : $verseNum');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                    ),
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SurahViewScreen(
                              surahId: surahNum,
                              surahNameKu: 'Surah $surahNum',
                              surahNameAr: 'سورة $surahNum',
                              surahNameEn: 'Surah $surahNum',
                            ),
                          ),
                        );
                      },
                      title: Text(
                        verseTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: isRTL ? 'Rabar' : null,
                        ),
                      ),
                      subtitle: Text(
                        '${lang == 'ku' ? "سورەتی" : lang == "ar" ? "سورة" : "Surah"} $surahNum : $verseNum',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.4),
                          fontFamily: isRTL ? 'Rabar' : null,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
