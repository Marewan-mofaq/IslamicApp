import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../providers/tasbih_provider.dart';
import '../providers/activity_provider.dart';

class TasbihScreen extends ConsumerStatefulWidget {
  const TasbihScreen({super.key});

  @override
  ConsumerState<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends ConsumerState<TasbihScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  bool _showCompletion = false;

  final List<Map<String, dynamic>> _presets = [
    { 'text': 'سُبْحَانَ اللَّهِ', 'ku': 'سوبحان الله', 'ar': 'سبحان الله', 'en': 'SubhanAllah', 'target': 33 },
    { 'text': 'الْحَمْدُ لِلَّهِ', 'ku': 'الحمد لله', 'ar': 'الحمد لله', 'en': 'Alhamdulillah', 'target': 33 },
    { 'text': 'اللَّهُ أَكْبَرُ', 'ku': 'الله اكبر', 'ar': 'الله أكبر', 'en': 'Allahu Akbar', 'target': 34 },
    { 'text': 'لَا إِلَهَ إِلَّا اللَّهُ', 'ku': 'لا اله الا الله', 'ar': 'لا إله إلا الله', 'en': 'La ilaha illallah', 'target': 100 },
    { 'text': 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّد', 'ku': 'صلاة على النبي', 'ar': 'الصلاة على النبي', 'en': 'Salawat upon the Prophet', 'target': 100 },
    { 'text': 'أَسْتَغْفِرُ اللَّهَ', 'ku': 'استغفار', 'ar': 'أستغفر الله', 'en': 'Astaghfirullah', 'target': 100 },
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handlePress() {
    // Vibration feedback
    HapticFeedback.lightImpact();

    _animController.forward().then((_) {
      if (mounted) _animController.reverse();
    });

    final state = ref.read(tasbihProvider);
    ref.read(tasbihProvider.notifier).increment();
    ref.read(activityProvider.notifier).logActivity(1);

    // Goal reached feedback
    if ((state.count + 1) % state.target == 0) {
      HapticFeedback.vibrate();
      setState(() {
        _showCompletion = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.palette;
    final tasbih = ref.watch(tasbihProvider);
    final isRTL = settings.language == 'ku' || settings.language == 'ar';

    final title = settings.language == 'ku' ? 'تەسبیه' : settings.language == 'ar' ? 'التسبيح' : 'Tasbih';
    final tapHint = settings.language == 'ku' ? 'تاپ بکە بۆ ئەژمارکردن' : settings.language == 'ar' ? 'اضغط للعد' : 'Tap to count';
    
    final labelReset = settings.language == 'ku' ? 'سفر' : settings.language == 'ar' ? 'إعادة' : 'Reset';
    final labelPresets = settings.language == 'ku' ? 'ویردەکان' : settings.language == 'ar' ? 'الأذكار' : 'Presets';
    final labelCustom = settings.language == 'ku' ? 'دیاریکردن' : settings.language == 'ar' ? 'تخصيص' : 'Custom';
    
    final statNow = settings.language == 'ku' ? 'ئێستا' : settings.language == 'ar' ? 'الآن' : 'Now';
    final statRounds = settings.language == 'ku' ? 'خوول' : settings.language == 'ar' ? 'الأدوار' : 'Rounds';
    final statTarget = settings.language == 'ku' ? 'ئامانج' : settings.language == 'ar' ? 'الهدف' : 'Target';
    final statTotal = settings.language == 'ku' ? 'کۆی گشتی' : settings.language == 'ar' ? 'الإجمالي' : 'All-time';

    final int safeTarget = tasbih.target > 0 ? tasbih.target : 1;
    final double progress = (tasbih.count / safeTarget).clamp(0.0, 1.0);
    final int rounds = tasbih.count ~/ safeTarget;
    final int currentInRound = tasbih.count % safeTarget;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Directionality(
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Dhikr phrase
                Padding(
                  padding: const EdgeInsets.only(top: 24.0, left: 20, right: 20),
                  child: Text(
                    tasbih.text,
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Animated count circular indicator
                GestureDetector(
                  onTap: _handlePress,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Circular outer ring track
                        Container(
                          width: 210,
                          height: 210,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                              width: 8,
                            ),
                          ),
                        ),
                        // Circular active ring progress
                        SizedBox(
                          width: 210,
                          height: 210,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 8,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        // Circular background inside
                        Container(
                          width: 194,
                          height: 194,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                Theme.of(context).colorScheme.primary.withOpacity(0.05),
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (rounds > 0)
                                Text(
                                  '×$rounds',
                                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                                ),
                              Text(
                                '$currentInRound',
                                style: TextStyle(fontSize: 54, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Text(
                                '/ ${tasbih.target}',
                                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.4)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app_rounded, size: 16, color: Colors.white.withOpacity(0.4)),
                        const SizedBox(width: 6),
                        Text(
                          tapHint,
                          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.4), fontFamily: 'Rabar'),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildActionBtn(
                          icon: Icons.replay_rounded,
                          label: labelReset,
                          color: Colors.redAccent,
                          onTap: () {
                            ref.read(tasbihProvider.notifier).reset();
                          },
                        ),
                        SizedBox(width: 16),
                        _buildActionBtn(
                          icon: Icons.auto_stories_rounded,
                          label: labelPresets,
                          color: Theme.of(context).colorScheme.primary,
                          onTap: () => _showPresetsSheet(context),
                        ),
                        SizedBox(width: 16),
                        _buildActionBtn(
                          icon: Icons.tune_rounded,
                          label: labelCustom,
                          color: Theme.of(context).colorScheme.primary,
                          onTap: () => _showCustomDhikrDialog(context, tasbih),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 32),

                    // Summary statistics
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.04)),
                      ),
                      child: Row(
                        children: [
                          _buildStatItem(currentInRound.toString(), statNow),
                          _buildStatDivider(),
                          _buildStatItem(rounds.toString(), statRounds),
                          _buildStatDivider(),
                          _buildStatItem(tasbih.target.toString(), statTarget),
                          _buildStatDivider(),
                          _buildStatItem(tasbih.totalAllTime.toString(), statTotal, highlighted: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

            // Completion Overlay Dialog
            if (_showCompletion)
              Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary.withOpacity(0.35),
                                Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary, size: 42),
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          settings.language == 'ku'
                              ? 'ماشاءاللە! تەواو بوو'
                              : settings.language == 'ar'
                                  ? 'ما شاء الله! اكتمل'
                                  : 'Ma Sha Allah! Done',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 10),
                        Text(
                          settings.language == 'ku'
                              ? 'تۆ توانیت ${tasbih.target} جار خوێندنی ${tasbih.text} تەواو بکەیت.'
                              : settings.language == 'ar'
                                  ? 'أتممت ${tasbih.target} مرة من تكرار ${tasbih.text}.'
                                  : 'You completed ${tasbih.target} repetitions of ${tasbih.text}.',
                          style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.6)),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              setState(() {
                                _showCompletion = false;
                              });
                            },
                            child: Text(
                              settings.language == 'ku'
                                  ? 'بەردەوام بە'
                                  : settings.language == 'ar'
                                      ? 'استمرار'
                                      : 'Continue',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.25), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.25),
                    color.withOpacity(0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.4), width: 1.2),
              ),
              child: Center(
                child: Icon(icon, color: color, size: 22),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Rabar',
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String val, String label, {bool highlighted = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            val,
            style: TextStyle(
              fontSize: highlighted ? 20 : 18,
              fontWeight: FontWeight.bold,
              color: highlighted ? Theme.of(context).colorScheme.primary : Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4))),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white.withOpacity(0.05),
    );
  }

  void _showPresetsSheet(BuildContext context) {
    final lang = ref.read(settingsProvider).language;
    final isRTL = lang == 'ku' || lang == 'ar';
    final sheetTitle = lang == 'ku'
        ? 'ویردە دیاریکراوەکان'
        : lang == 'ar'
            ? 'الأذكار المحددة'
            : 'Dhikr Presets';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Directionality(
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sheetTitle,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: isRTL ? 'Rabar' : null),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _presets.length,
                    itemBuilder: (context, idx) {
                      final preset = _presets[idx];
                      final subtitle = lang == 'en' ? (preset['en'] ?? '') : lang == 'ar' ? (preset['ar'] ?? '') : (preset['ku'] ?? '');
                      return ListTile(
                        title: Text(preset['text'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        subtitle: subtitle.isNotEmpty ? Text(subtitle, style: TextStyle(color: Colors.white60, fontSize: 13, fontFamily: isRTL ? 'Rabar' : null)) : null,
                        trailing: Text('×${preset['target']}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: isRTL ? 'Rabar' : null)),
                        onTap: () {
                          ref.read(tasbihProvider.notifier).setText(preset['text'] as String);
                          ref.read(tasbihProvider.notifier).setTarget(preset['target'] as int);
                          ref.read(tasbihProvider.notifier).reset();
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCustomDhikrDialog(BuildContext context, TasbihState state) {
    final lang = ref.read(settingsProvider).language;
    final textController = TextEditingController(text: state.text);
    final targetController = TextEditingController(text: state.target.toString());

    final dialogTitle = lang == 'ku'
        ? 'زیکری تایبەت'
        : lang == 'ar'
            ? 'ذكر مخصص'
            : 'Custom Dhikr';
    final phraseLabel = lang == 'ku'
        ? 'دەقی زیکر'
        : lang == 'ar'
            ? 'نص الذكر'
            : 'Dhikr Phrase';
    final targetLabel = lang == 'ku'
        ? 'ژمارەی ئامانج'
        : lang == 'ar'
            ? 'العدد المستهدف'
            : 'Target Count';
    final cancelLabel = lang == 'ku'
        ? 'پاشگەزبوونەوە'
        : lang == 'ar'
            ? 'إلغاء'
            : 'Cancel';
    final saveLabel = lang == 'ku'
        ? 'پاشەکەوتکردن'
        : lang == 'ar'
            ? 'حفظ'
            : 'Save';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(dialogTitle, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Rabar')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: textController,
                decoration: InputDecoration(labelText: phraseLabel),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              TextField(
                controller: targetController,
                decoration: InputDecoration(labelText: targetLabel),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(cancelLabel, style: TextStyle(color: Colors.white54, fontFamily: 'Rabar')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.black),
              onPressed: () {
                final txt = textController.text.trim();
                final trg = (int.tryParse(targetController.text) ?? 33).clamp(1, 999999);
                if (txt.isNotEmpty) {
                  ref.read(tasbihProvider.notifier).setText(txt);
                  ref.read(tasbihProvider.notifier).setTarget(trg);
                  ref.read(tasbihProvider.notifier).reset();
                }
                Navigator.pop(context);
              },
              child: Text(saveLabel, style: TextStyle(fontFamily: 'Rabar', fontWeight: FontWeight.bold)),
            )
          ],
        );
      },
    ).whenComplete(() {
      textController.dispose();
      targetController.dispose();
    });
  }
}
