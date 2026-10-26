import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../providers/khatam_provider.dart';
import '../providers/activity_provider.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.palette;
    final khatam = ref.watch(khatamProvider);
    final activity = ref.watch(activityProvider);
    final isRTL = settings.language == 'ku' || settings.language == 'ar';

    final title = settings.language == 'ku' ? 'ئامار و دەستکەوتەکان' : settings.language == 'ar' ? 'الإحصائيات والإنجازات' : 'Insights & Stats';
    
    final labelCompletion = settings.language == 'ku'
        ? 'پێشکەوتنی خەتم'
        : settings.language == 'ar'
            ? 'ختم القرآن'
            : 'Quran Completion';
    final labelPages = settings.language == 'ku'
        ? 'لە ٦٠٤ لاپەڕە'
        : settings.language == 'ar'
            ? 'من ٦٠٤ صفحة'
            : '/ 604 pages';
    
    final statStreak = settings.language == 'ku'
        ? 'بەردەوامی'
        : settings.language == 'ar'
            ? 'المواظبة'
            : 'Streak';
    final statVerses = settings.language == 'ku'
        ? 'ئایەتەکان'
        : settings.language == 'ar'
            ? 'الآيات'
            : 'Verses';
    final statActive = settings.language == 'ku'
        ? 'ڕۆژی چالاک'
        : settings.language == 'ar'
            ? 'الأيام النشطة'
            : 'Active Days';
    final statBadges = settings.language == 'ku'
        ? 'نیشانەکان'
        : settings.language == 'ar'
            ? 'الأوسمة'
            : 'Badges';

    final labelWeekly = settings.language == 'ku'
        ? 'چالاکی هەفتانە'
        : settings.language == 'ar'
            ? 'النشاط الأسبوعي'
            : 'Weekly Activity';
    final labelAchievements = settings.language == 'ku'
        ? 'نیشانە و دەستکەوتەکان'
        : settings.language == 'ar'
            ? 'الإنجازات والأوسمة'
            : 'Achievements';
    final emptyBadgeText = settings.language == 'ku'
        ? 'هیچ نیشانەیەکت بەدەست نەهێناوە'
        : settings.language == 'ar'
            ? 'لم تحصل على أوسمة بعد'
            : 'No badges earned yet';

    final double completionPercent = khatam.targetPages > 0 ? (khatam.pagesRead / khatam.targetPages).clamp(0.0, 1.0) : 0.0;

    // Summary calculations
    final int totalVersesRead = activity.activityLog.values.isEmpty 
        ? 0 
        : activity.activityLog.values.reduce((a, b) => a + b);
    final int activeDaysCount = activity.activityLog.values.where((v) => v > 0).length;

    // Last 7 days chart data
    final List<Map<String, dynamic>> chartData = [];
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateString = date.toIso8601String().split('T')[0];
      final count = activity.activityLog[dateString] ?? 0;
      
      final dayNamesKu = ['ی', 'د', 'س', 'چ', 'پ', 'هـ', 'ش'];
      final dayNamesAr = ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س'];
      final dayNamesEn = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
      
      final dayLabel = settings.language == 'ku' 
          ? dayNamesKu[date.weekday % 7]
          : settings.language == 'ar'
              ? dayNamesAr[date.weekday % 7]
              : dayNamesEn[date.weekday % 7];

      chartData.add({
        'label': dayLabel,
        'count': count,
        'isToday': i == 0,
      });
    }

    final int maxCount = chartData.map((e) => e['count'] as int).reduce((a, b) => a > b ? a : b);
    final double maxVal = maxCount > 5 ? maxCount.toDouble() : 5.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Directionality(
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Quran completion circular widget card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 90,
                          height: 90,
                          child: CircularProgressIndicator(
                            value: completionPercent,
                            strokeWidth: 8,
                            backgroundColor: Colors.white.withOpacity(0.05),
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        Text(
                          '${(completionPercent * 100).toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            labelCompletion,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${khatam.pagesRead} $labelPages',
                            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Summary Grid (Flame, Book, Ribbon, Star)
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _buildStatCard(Icons.local_fire_department, Colors.orange, activity.streak.toString(), statStreak),
                  _buildStatCard(Icons.book, Theme.of(context).colorScheme.primary, totalVersesRead.toString(), statVerses),
                  _buildStatCard(Icons.calendar_today, Colors.green, activeDaysCount.toString(), statActive),
                  _buildStatCard(Icons.workspace_premium, Colors.purpleAccent, activity.badges.length.toString(), statBadges),
                ],
              ),
              SizedBox(height: 24),

              // Weekly Activity Trend Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      labelWeekly,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 24),
                    // Weekly bar chart row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: chartData.map((d) {
                        final count = d['count'] as int;
                        final isToday = d['isToday'] as bool;
                        final barHeight = (count / maxVal) * 90;

                        return Column(
                          children: [
                            Container(
                              width: 12,
                              height: 90,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: 12,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              d['label'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                color: isToday ? Theme.of(context).colorScheme.primary : Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Achievements Section
              Text(
                labelAchievements,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              if (activity.badges.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.01),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.military_tech_outlined, size: 40, color: Colors.white.withOpacity(0.2)),
                      SizedBox(height: 8),
                      Text(
                        emptyBadgeText,
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 130,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: activity.badges.length,
                    itemBuilder: (context, idx) {
                      final badge = activity.badges[idx];
                      final name = settings.language == 'ar' 
                          ? badge.nameAr 
                          : settings.language == 'en' 
                          ? badge.nameEn 
                          : badge.nameKu;

                      return Container(
                        width: 100,
                        margin: const EdgeInsetsDirectional.only(end: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_getBadgeIcon(badge.nameEn), size: 28, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(height: 6),
                            Text(
                              name,
                              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getBadgeIcon(String nameEn) {
    switch (nameEn) {
      case 'Worship Devotee':
        return Icons.verified_user_rounded;
      case '3-Day Worship Streak':
        return Icons.local_fire_department_rounded;
      case '7-Day Worship Streak':
        return Icons.bolt_rounded;
      case '30-Day Master':
        return Icons.military_tech_rounded;
      case 'Dhikr Novice':
        return Icons.fingerprint_rounded;
      case 'Quran Reader':
        return Icons.menu_book_rounded;
      default:
        return Icons.emoji_events_rounded;
    }
  }

  Widget _buildStatCard(IconData icon, Color color, String val, String label) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                val,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.4)),
              ),
            ],
          )
        ],
      ),
    );
  }
}
