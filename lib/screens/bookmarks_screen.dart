import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../providers/bookmarks_provider.dart';
import 'surah_view_screen.dart';
import 'hadith_adhkar_screen.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  void _showAddPersonalDuaModal(BuildContext context, WidgetRef ref, String lang) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    final hintTitle = lang == 'ku'
        ? 'ناوی دوعاکە (ناوی دایک و باوک، سەرکەوتن...)'
        : lang == 'ar'
            ? 'اسم الدعاء (لوالديّ، للتوفيق...)'
            : 'Dua title (For parents, success...)';
    final hintBody = lang == 'ku'
        ? 'دەقی دوعاکە یان زیکرەکە...'
        : lang == 'ar'
            ? 'نص الدعاء أو الذكر...'
            : 'Text of dua or adhkar...';
    final saveText = lang == 'ku'
        ? 'پاشەکەوتکردن'
        : lang == 'ar'
            ? 'حفظ'
            : 'Save';
    final snackbarSuccess = lang == 'ku'
        ? 'دوعاکە بە سەرکەوتوویی پاشەکەوت کرا'
        : lang == 'ar'
            ? 'تم حفظ الدعاء بنجاح'
            : 'Dua saved successfully';

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('بِسمِ اللَّهِ الرَّحمٰنِ الرَّحيمِ', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              TextField(
                controller: titleController,
                style: TextStyle(color: Colors.white, fontFamily: 'Rabar'),
                decoration: InputDecoration(
                  hintText: hintTitle,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontFamily: 'Rabar'),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.03),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: bodyController,
                maxLines: 3,
                style: TextStyle(color: Colors.white, fontFamily: 'Rabar'),
                decoration: InputDecoration(
                  hintText: hintBody,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontFamily: 'Rabar'),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.03),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  final title = titleController.text.trim();
                  final body = bodyController.text.trim();
                  if (title.isNotEmpty && body.isNotEmpty) {
                    ref.read(bookmarksProvider.notifier).addBookmark(
                      BookmarkItem(
                        id: 'personal-${DateTime.now().millisecondsSinceEpoch}',
                        title: title,
                        subtitle: body,
                        type: 'personal_dua',
                      ),
                    );
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    messenger.showSnackBar(
                      SnackBar(content: Text(snackbarSuccess)),
                    );
                  }
                },
                child: Text(saveText, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Rabar')),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      titleController.dispose();
      bodyController.dispose();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final bookmarks = ref.watch(bookmarksProvider);
    final isRTL = settings.language == 'ku' || settings.language == 'ar';

    final title = settings.language == 'ku'
        ? 'دڵخوازەکان و دوعای کەسی'
        : settings.language == 'ar'
            ? 'المحفوظات والأدعية الخاصة'
            : 'Bookmarks & Personal Duas';
    final emptyText = settings.language == 'ku'
        ? 'هیچ دڵخوازێکت یان دوعایەکی کەسیت دیاری نەکردووە'
        : settings.language == 'ar'
            ? 'لا توجد محفوظات أو أدعية خاصة حتى الآن'
            : 'No saved bookmarks or personal duas';
    final fabLabel = settings.language == 'ku'
        ? 'دوعای کەسی نوێ'
        : settings.language == 'ar'
            ? 'دعاء خاص جديد'
            : 'New Personal Dua';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Rabar')),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: Icon(Icons.add, color: Colors.black),
        label: Text(fabLabel, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Rabar')),
        onPressed: () => _showAddPersonalDuaModal(context, ref, settings.language),
      ),
      body: Directionality(
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: bookmarks.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bookmark_outline, size: 64, color: Colors.white.withOpacity(0.3)),
                    SizedBox(height: 16),
                    Text(
                      emptyText,
                      style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5), fontFamily: 'Rabar'),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                itemCount: bookmarks.length,
                itemBuilder: (context, index) {
                  final item = bookmarks[index];
                  final isPersonal = item.type == 'personal_dua';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isPersonal ? Theme.of(context).colorScheme.primary.withOpacity(0.3) : Colors.white.withOpacity(0.04),
                      ),
                    ),
                    child: Material(
                      color: isPersonal ? Theme.of(context).colorScheme.primary.withOpacity(0.08) : Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        onTap: () {
                        if (item.type == 'quran' && item.surahId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SurahViewScreen(
                                surahId: item.surahId!,
                                surahNameKu: item.surahName ?? item.title,
                                surahNameAr: item.surahName ?? item.title,
                                surahNameEn: item.surahName ?? item.title,
                              ),
                            ),
                          );
                        } else if (item.type == 'hadith' || item.type == 'adhkar') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HadithAdhkarScreen(),
                            ),
                          );
                        }
                      },
                      leading: Icon(
                        isPersonal ? Icons.favorite : Icons.bookmark,
                        color: isPersonal ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Rabar'),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          item.subtitle,
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6), fontFamily: 'Rabar'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        onPressed: () {
                          ref.read(bookmarksProvider.notifier).removeBookmark(item.id);
                        },
                      ),
                    ),
                  ),
                );
              },
              ),
      ),
    );
  }
}
