import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/notification_service.dart';

class AdhanPlayingDialog extends StatefulWidget {
  final String prayerName;
  final String? voiceId;
  final String language;
  final bool autoPlayAudio;

  const AdhanPlayingDialog({
    super.key,
    required this.prayerName,
    this.voiceId,
    this.language = 'ku',
    this.autoPlayAudio = true,
  });

  static Future<void> show(
    BuildContext context, {
    required String prayerName,
    String? voiceId,
    String language = 'ku',
    bool autoPlayAudio = true,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AdhanPlayingDialog(
        prayerName: prayerName,
        voiceId: voiceId,
        language: language,
        autoPlayAudio: autoPlayAudio,
      ),
    );
  }

  @override
  State<AdhanPlayingDialog> createState() => _AdhanPlayingDialogState();
}

class _AdhanPlayingDialogState extends State<AdhanPlayingDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  AudioPlayer? _audioPlayer;
  bool _isStopped = false;
  StreamSubscription? _playerCompleteSubscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.autoPlayAudio) {
      _startAudio();
    }
  }

  Future<void> _startAudio() async {
    try {
      final voice = widget.voiceId ?? (widget.prayerName == 'Fajr' ? 'mishary_fajr' : 'nasser');
      _audioPlayer = AudioPlayer();
      NotificationService.setActiveInAppAdhanPlayer(_audioPlayer);
      await _audioPlayer!.setReleaseMode(ReleaseMode.stop);
      _playerCompleteSubscription = _audioPlayer!.onPlayerComplete.listen((_) {
        NotificationService.setActiveInAppAdhanPlayer(null);
        if (mounted) {
          setState(() {
            _isStopped = true;
          });
        }
      });
      final assetPath = voice == 'mishary_fajr'
          ? 'audio/adhan/mishary_fajr.mp3'
          : 'audio/adhan/$voice.mp3';
      try {
        if (!mounted || _isStopped || _audioPlayer == null) return;
        await _audioPlayer!.play(AssetSource(assetPath));
      } catch (e) {
        debugPrint('Error playing main adhan asset: $e');
        if (!mounted || _isStopped || _audioPlayer == null) return;
        // Use Fajr-specific fallback for Fajr, regular for other prayers
        final fallback = widget.prayerName == 'Fajr'
            ? 'audio/adhan/mishary_fajr.mp3'
            : 'audio/adhan/mishary.mp3';
        await _audioPlayer!.play(AssetSource(fallback));
      }
    } catch (e) {
      debugPrint('Error starting adhan audio: $e');
    }
  }

  Future<void> _stopAdhan() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isStopped = true;
    });

    NotificationService.setActiveInAppAdhanPlayer(null);

    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        await _audioPlayer!.dispose();
        _audioPlayer = null;
      }
    } catch (e) {
      debugPrint('Error stopping adhan: $e');
    }

    await NotificationService.stopAdhan();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.greenAccent),
              const SizedBox(width: 8),
              Text(
                widget.language == 'ku'
                    ? 'دەنگی بانگ بە سەرکەوتوویی ڕاگیرا'
                    : widget.language == 'ar'
                        ? 'تم إيقاف صوت الأذان بنجاح'
                        : 'Adhan sound stopped successfully',
                style: const TextStyle(fontFamily: 'Rabar'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    NotificationService.setActiveInAppAdhanPlayer(null);
    _playerCompleteSubscription?.cancel();
    NotificationService.stopAdhan();
    _pulseController.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRTL = widget.language == 'ku' || widget.language == 'ar';
    final primaryColor = Theme.of(context).colorScheme.primary;

    final prayerTitles = {
      'Fajr': {'ku': 'نوێژی بەیانی', 'ar': 'صلاة الفجر', 'en': 'Fajr Prayer', 'icon': Icons.wb_twilight_rounded},
      'Dhuhr': {'ku': 'نوێژی نیوەڕۆ', 'ar': 'صلاة الظهر', 'en': 'Dhuhr Prayer', 'icon': Icons.light_mode_rounded},
      'Asr': {'ku': 'نوێژی عەسڕ', 'ar': 'صلاة العصر', 'en': 'Asr Prayer', 'icon': Icons.cloud_queue_rounded},
      'Maghrib': {'ku': 'نوێژی مەغریب', 'ar': 'صلاة المغرب', 'en': 'Maghrib Prayer', 'icon': Icons.nightlight_round},
      'Isha': {'ku': 'نوێژی عیشا', 'ar': 'صلاة العشاء', 'en': 'Isha Prayer', 'icon': Icons.bedtime_rounded},
    };

    final prayerInfo = prayerTitles[widget.prayerName] ??
        {'ku': 'کاتی بانگ', 'ar': 'وقت الأذان', 'en': 'Adhan Time', 'icon': Icons.mosque_rounded};

    final prayerDisplayName = (prayerInfo[widget.language] as String?) ?? widget.prayerName;
    final prayerIcon = (prayerInfo['icon'] as IconData?) ?? Icons.mosque_rounded;

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF022C22), Color(0xFF0F172A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: primaryColor.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.25),
                blurRadius: 30,
                spreadRadius: 2,
              ),
              const BoxShadow(
                color: Colors.black87,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Islamic Calligraphy Banner
                  Text(
                    'اللَّهُ أَكْبَرُ • اللَّهُ أَكْبَرُ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Rabar',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Animated Glowing Mosque / Sound Icon
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 105,
                          height: 105,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor.withOpacity(0.12),
                            border: Border.all(
                              color: primaryColor.withOpacity(0.4),
                              width: 2,
                            ),
                          ),
                        ),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                primaryColor.withOpacity(0.3),
                                primaryColor.withOpacity(0.05),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              prayerIcon,
                              size: 40,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Prayer Name & Subtitle
                  Text(
                    prayerDisplayName,
                    style: const TextStyle(
                      fontFamily: 'Rabar',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.language == 'ku'
                        ? 'کاتی نوێژ هات، بانگی پیرۆز لێدەدات'
                        : widget.language == 'ar'
                            ? 'حان الآن وقت الصلاة، يُرفع الأذان'
                            : "It is now prayer time, Adhan is calling",
                    style: TextStyle(
                      fontFamily: 'Rabar',
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // PROMINENT STOP ADHAN BUTTON (دوگمەی ڕاگرتنی دەنگی بانگ)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isStopped
                            ? [Colors.grey.shade700, Colors.grey.shade800]
                            : [
                                const Color(0xFFDC2626), // Vibrant Red
                                const Color(0xFFB91C1C),
                                const Color(0xFF991B1B),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: _isStopped
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.45),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isStopped ? null : _stopAdhan,
                        borderRadius: BorderRadius.circular(20),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isStopped ? Icons.check_circle : Icons.stop_circle_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _isStopped
                                    ? (widget.language == 'ku'
                                        ? 'بانگەکە ڕاگیرا'
                                        : widget.language == 'ar'
                                            ? 'تم الإيقاف'
                                            : 'Adhan Stopped')
                                    : (widget.language == 'ku'
                                        ? 'ڕاگرتنی دەنگی بانگ'
                                        : widget.language == 'ar'
                                            ? 'إيقاف صوت الأذان'
                                            : 'Stop Adhan Audio'),
                                style: const TextStyle(
                                  fontFamily: 'Rabar',
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Dua After Adhan Card (دوعای دوای بانگ)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.07),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome, size: 15, color: primaryColor),
                            const SizedBox(width: 6),
                            Text(
                              widget.language == 'ku'
                                  ? 'دوعای دوای بانگ'
                                  : widget.language == 'ar'
                                      ? 'دعاء ما بعد الأذان'
                                      : 'Dua After Adhan',
                              style: TextStyle(
                                fontFamily: 'Rabar',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '«اللَّهُمَّ رَبَّ هَذِهِ الدَّعْوَةِ التَّامَّةِ، وَالصَّلَاةِ الْقَائِمَةِ، آتِ مُحَمَّدًا الْوَسِيلَةَ وَالْفَضِيلَةَ، وَابْعَثْهُ مَقَامًا مَحْمُودًا الَّذِي وَعَدْتَهُ»',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Rabar',
                            fontSize: 13.5,
                            color: Colors.white,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Close Button (داخستن)
                  TextButton(
                    onPressed: () {
                      _stopAdhan();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white60,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    ),
                    child: Text(
                      widget.language == 'ku'
                          ? 'داخستن'
                          : widget.language == 'ar'
                              ? 'إغلاق'
                              : 'Close',
                      style: const TextStyle(
                        fontFamily: 'Rabar',
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
