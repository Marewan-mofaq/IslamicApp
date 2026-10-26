import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../providers/qaza_provider.dart';

class QazaTrackerScreen extends ConsumerWidget {
  const QazaTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.palette;
    final qaza = ref.watch(qazaProvider);
    final isRTL = settings.language == 'ku' || settings.language == 'ar';

    final title = settings.language == 'ku' ? 'تەواوکردنی قەزا' : settings.language == 'ar' ? 'قضاء الصلوات' : 'Qaza Tracker';
    final infoText = settings.language == 'ku'
        ? 'ئەم بەشە یارمەتیدەرت دەبێت بۆ تۆمارکردن و جێبەجێکردنی نوێژە قەزاکانت.'
        : 'Keep track of your missed daily prayers and work towards completing them.';

    final prayers = [
      { 'id': 'fajr', 'ku': 'بەیانی', 'ar': 'الفجر', 'en': 'Fajr', 'icon': Icons.wb_twilight_rounded },
      { 'id': 'dhuhr', 'ku': 'نیوەڕۆ', 'ar': 'الظهر', 'en': 'Dhuhr', 'icon': Icons.light_mode_rounded },
      { 'id': 'asr', 'ku': 'عەسر', 'ar': 'العصر', 'en': 'Asr', 'icon': Icons.cloud_queue_rounded },
      { 'id': 'maghrib', 'ku': 'مەغریب', 'ar': 'المغرب', 'en': 'Maghrib', 'icon': Icons.nightlight_round },
      { 'id': 'isha', 'ku': 'عیشا', 'ar': 'العشاء', 'en': 'Isha', 'icon': Icons.bedtime_rounded },
      { 'id': 'witr', 'ku': 'وێتر', 'ar': 'الوتر', 'en': 'Witr', 'icon': Icons.auto_awesome_rounded },
    ];

    final String langKey = settings.language == 'ar' ? 'ar' : settings.language == 'en' ? 'en' : 'ku';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.calculate_outlined, color: Colors.white),
            onPressed: () => _showCalculatorDialog(context, ref, settings.language),
          )
        ],
      ),
      body: Directionality(
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: Column(
          children: [
            // Instructions banner
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      infoText,
                      style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7), height: 1.4),
                    ),
                  )
                ],
              ),
            ),

            // Prayers list
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: prayers.length,
                itemBuilder: (context, idx) {
                  final prayer = prayers[idx];
                  final String prayerId = (prayer['id'] ?? '').toString();
                  final String prayerName = (prayer[langKey] ?? prayer['ku'] ?? '').toString();
                  final IconData icon = prayer['icon'] as IconData? ?? Icons.mosque_rounded;
                  
                  // Get prayer count
                  int count = 0;
                  if (prayerId == 'fajr') count = qaza.fajr;
                  else if (prayerId == 'dhuhr') count = qaza.dhuhr;
                  else if (prayerId == 'asr') count = qaza.asr;
                  else if (prayerId == 'maghrib') count = qaza.maghrib;
                  else if (prayerId == 'isha') count = qaza.isha;
                  else if (prayerId == 'witr') count = qaza.witr;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
                              ),
                            ),
                            SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prayerName,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  settings.language == 'ku'
                                      ? '$count ماوە'
                                      : settings.language == 'ar'
                                          ? '$count متبقي'
                                          : '$count left',
                                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove_circle, color: Colors.redAccent, size: 28),
                              onPressed: () {
                                ref.read(qazaProvider.notifier).updateQaza(prayerId, -1);
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.add_circle, color: Theme.of(context).colorScheme.primary, size: 28),
                              onPressed: () {
                                ref.read(qazaProvider.notifier).updateQaza(prayerId, 1);
                              },
                            ),
                          ],
                        )
                      ],
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

  void _showCalculatorDialog(BuildContext context, WidgetRef ref, String language) {
    final yearsController = TextEditingController();
    final monthsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            language == 'ku'
                ? 'حیسابکەری کاتەکان'
                : language == 'ar'
                    ? 'حاسبة الصلوات الفائتة'
                    : 'Missed Duration Calculator',
            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: yearsController,
                decoration: InputDecoration(
                  labelText: language == 'ku'
                      ? 'چەند ساڵ قەزا بووە'
                      : language == 'ar'
                          ? 'عدد السنوات الفائتة'
                          : 'Years missed',
                ),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              TextField(
                controller: monthsController,
                decoration: InputDecoration(
                  labelText: language == 'ku'
                      ? 'چەند مانگ قەزا بووە'
                      : language == 'ar'
                          ? 'عدد الأشهر الفائتة'
                          : 'Months missed',
                ),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                language == 'ku' ? 'پاشگەزبوونەوە' : language == 'ar' ? 'إلغاء' : 'Cancel',
                style: TextStyle(color: Colors.white54, fontFamily: 'Rabar'),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final years = int.tryParse(yearsController.text) ?? 0;
                final months = int.tryParse(monthsController.text) ?? 0;
                final totalDays = (years * 365) + (months * 30);
                
                if (totalDays > 0) {
                  ref.read(qazaProvider.notifier).setQazaData(QazaState(
                    fajr: totalDays,
                    dhuhr: totalDays,
                    asr: totalDays,
                    maghrib: totalDays,
                    isha: totalDays,
                    witr: totalDays,
                  ));
                }
                Navigator.pop(context);
              },
              child: Text(
                language == 'ku' ? 'هەژمارکردن' : language == 'ar' ? 'احسب' : 'Calculate',
                style: TextStyle(fontFamily: 'Rabar', fontWeight: FontWeight.bold),
              ),
            )
          ],
        );
      },
    ).whenComplete(() {
      yearsController.dispose();
      monthsController.dispose();
    });
  }
}
