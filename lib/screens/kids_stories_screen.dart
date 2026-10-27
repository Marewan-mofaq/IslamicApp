import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../services/data_service.dart';

class KidsStoriesScreen extends ConsumerStatefulWidget {
  const KidsStoriesScreen({super.key});

  @override
  ConsumerState<KidsStoriesScreen> createState() => _KidsStoriesScreenState();
}

class _KidsStoriesScreenState extends ConsumerState<KidsStoriesScreen> {
  late Future<List<dynamic>> _storiesFuture;

  @override
  void initState() {
    super.initState();
    _storiesFuture = DataService.loadKidsStories();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.palette;
    final isRTL = settings.language == 'ku' || settings.language == 'ar';
    
    final title = settings.language == 'ku' ? 'بەشی منداڵان' : settings.language == 'ar' ? 'عالم الأطفال' : "Kids' World";
    final subtitle = settings.language == 'ku'
        ? 'چیرۆکە خۆشەکان و وانە فێرکارییەکان'
        : settings.language == 'ar'
            ? 'قصص ممتعة وعِبر تعليمية'
            : 'Fun stories and moral lessons';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Colorful Kids Header
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                  fontFamily: isRTL ? 'Rabar' : null,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF9A9E), Color(0xFFFAD0C4), Theme.of(context).scaffoldBackgroundColor],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 80.0),
                  child: Center(
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                        fontFamily: isRTL ? 'Rabar' : null,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Stories List
          SliverToBoxAdapter(
            child: FutureBuilder<List<dynamic>>(
              future: _storiesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: EdgeInsets.only(top: 60.0),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFFEC4899))),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  final emptyMsg = settings.language == 'ku'
                      ? 'هیچ چیرۆکێک نەدۆزرایەوە.'
                      : settings.language == 'ar'
                          ? 'لم يتم العثور على قصص.'
                          : 'No stories found.';
                  return Padding(
                    padding: EdgeInsets.only(top: 60.0),
                    child: Center(child: Text(emptyMsg, style: TextStyle(color: Colors.white, fontFamily: isRTL ? 'Rabar' : null))),
                  );
                }

                final stories = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  itemCount: stories.length,
                  itemBuilder: (context, index) {
                    final item = stories[index];
                    final storyTitle = (settings.language == 'en'
                        ? (item['title_en'] ?? item['title_ar'] ?? item['title_ku'])
                        : settings.language == 'ar'
                            ? (item['title_ar'] ?? item['title_ku'] ?? item['title_en'])
                            : (item['title_ku'] ?? item['title_ar'] ?? item['title_en']))?.toString() ?? '';
                    final lesson = (settings.language == 'en'
                        ? (item['lesson_en'] ?? item['lesson_ar'] ?? item['lesson_ku'])
                        : settings.language == 'ar'
                            ? (item['lesson_ar'] ?? item['lesson_ku'] ?? item['lesson_en'])
                            : (item['lesson_ku'] ?? item['lesson_ar'] ?? item['lesson_en']))?.toString() ?? '';
                    
                    // Parse custom card color
                    Color itemColor = const Color(0xFFEC4899);
                    try {
                      final hex = (item['color'] ?? '').toString().replaceAll('#', '');
                      if (hex.length == 6) {
                        itemColor = Color(int.parse('FF$hex', radix: 16));
                      }
                    } catch (_) {}

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: itemColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: itemColor.withOpacity(0.2), width: 1.5),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => KidsStoryViewerScreen(story: item, themeColor: itemColor),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                            children: [
                              // Emoji container
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: itemColor,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.child_care_rounded,
                                    size: 28,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      storyTitle,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontFamily: 'Rabar',
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.auto_awesome_rounded, size: 13, color: Colors.amberAccent),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            lesson,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white.withOpacity(0.7),
                                              fontFamily: 'Rabar',
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                isRTL ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
                                size: 16,
                                color: itemColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class KidsStoryViewerScreen extends ConsumerWidget {
  final dynamic story;
  final Color themeColor;

  const KidsStoryViewerScreen({
    super.key,
    required this.story,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.palette;
    final isRTL = settings.language == 'ku' || settings.language == 'ar';

    final title = (settings.language == 'en'
        ? (story['title_en'] ?? story['title_ar'] ?? story['title_ku'])
        : settings.language == 'ar'
            ? (story['title_ar'] ?? story['title_ku'] ?? story['title_en'])
            : (story['title_ku'] ?? story['title_ar'] ?? story['title_en']))?.toString() ?? '';
    final content = (settings.language == 'en'
        ? (story['content_en'] ?? story['content_ar'] ?? story['content_ku'])
        : settings.language == 'ar'
            ? (story['content_ar'] ?? story['content_ku'] ?? story['content_en'])
            : (story['content_ku'] ?? story['content_ar'] ?? story['content_en']))?.toString() ?? '';
    final lesson = (settings.language == 'en'
        ? (story['lesson_en'] ?? story['lesson_ar'] ?? story['lesson_ku'])
        : settings.language == 'ar'
            ? (story['lesson_ar'] ?? story['lesson_ku'] ?? story['lesson_en'])
            : (story['lesson_ku'] ?? story['lesson_ar'] ?? story['lesson_en']))?.toString() ?? '';
    
    final moralTitle = settings.language == 'ku' ? 'ئەنجامی چیرۆک' : settings.language == 'ar' ? 'العبرة' : 'Moral Lesson';
    final finishText = settings.language == 'ku' ? 'تەواو' : settings.language == 'ar' ? 'إنهاء' : 'Finish';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Dynamic gradient header based on story color
          SliverAppBar(
            expandedHeight: 220.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: themeColor,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                    fontFamily: isRTL ? 'Rabar' : null,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [themeColor, themeColor.withOpacity(0.6), Theme.of(context).scaffoldBackgroundColor],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.child_care_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Story Details
          SliverPadding(
            padding: const EdgeInsets.all(24.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Story Content Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: Text(
                    content,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.8,
                      color: Colors.white.withOpacity(0.9),
                      fontFamily: isRTL ? 'Rabar' : null,
                    ),
                    textAlign: isRTL ? TextAlign.right : TextAlign.left,
                  ),
                ),
                SizedBox(height: 24),
                
                // Moral Lesson Box
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.01),
                    borderRadius: BorderRadius.circular(20),
                    border: BorderDirectional(
                      start: BorderSide(color: themeColor, width: 5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: isRTL ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          Icon(Icons.star, color: themeColor, size: 20),
                          SizedBox(width: 8),
                          Text(
                            moralTitle,
                            style: TextStyle(
                              color: themeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              fontFamily: isRTL ? 'Rabar' : null,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        lesson,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                          height: 1.5,
                          fontFamily: isRTL ? 'Rabar' : null,
                        ),
                        textAlign: isRTL ? TextAlign.right : TextAlign.left,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),
                
                // Finish button
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    finishText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: isRTL ? 'Rabar' : null,
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
