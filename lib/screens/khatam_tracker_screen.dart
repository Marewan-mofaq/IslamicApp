import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../providers/khatam_provider.dart';

class KhatamTrackerScreen extends ConsumerStatefulWidget {
  const KhatamTrackerScreen({super.key});

  @override
  ConsumerState<KhatamTrackerScreen> createState() => _KhatamTrackerScreenState();
}

class _KhatamTrackerScreenState extends ConsumerState<KhatamTrackerScreen> {
  final TextEditingController _pagesController = TextEditingController();

  @override
  void dispose() {
    _pagesController.dispose();
    super.dispose();
  }

  String _normalizeDigits(String input) {
    const eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String res = input.replaceAll(',', '').replaceAll('،', '').trim();
    for (int i = 0; i < 10; i++) {
      res = res.replaceAll(eastern[i], western[i]).replaceAll(persian[i], western[i]);
    }
    return res;
  }

  void _handleAdd(KhatamProgress progress) {
    final val = int.tryParse(_normalizeDigits(_pagesController.text));
    if (val != null && val > 0) {
      final newRead = (progress.pagesRead + val).clamp(0, progress.targetPages);
      ref.read(khatamProvider.notifier).updateProgress(pagesRead: newRead);
      _pagesController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.palette;
    final khatam = ref.watch(khatamProvider);
    final isRTL = settings.language == 'ku' || settings.language == 'ar';

    final title = settings.language == 'ku' ? 'خەتمی قورئان' : settings.language == 'ar' ? 'ختم القرآن' : 'Khatam Tracker';
    final progressTitle = settings.language == 'ku' ? 'بەرەوپێشچوونی خەتم' : settings.language == 'ar' ? 'تقدم الختمة' : 'Khatam Progress';
    final pagesLabel = settings.language == 'ku' ? 'لاپەڕە' : settings.language == 'ar' ? 'صفحة' : 'Pages';
    final inputLabel = settings.language == 'ku' ? 'چەند لاپەڕەت خوێند؟' : settings.language == 'ar' ? 'كم صفحة قرأت؟' : 'How many pages did you read?';
    
    final labelAdd = settings.language == 'ku' ? 'زیادکردن' : settings.language == 'ar' ? 'إضافة' : 'Add';
    final labelReset = settings.language == 'ku' ? 'دەستپێکردنەوە لە سەرەتا' : settings.language == 'ar' ? 'البدء من جديد' : 'Reset Tracker';

    final double progressPercent = (khatam.pagesRead / khatam.targetPages).clamp(0.0, 1.0);

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
              // Visual progress card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
                    SizedBox(height: 16),
                    Text(
                      progressTitle,
                      style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.5)),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${khatam.pagesRead} / ${khatam.targetPages} $pagesLabel',
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                    ),
                    SizedBox(height: 20),
                    // Horizontal progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progressPercent,
                        minHeight: 12,
                        backgroundColor: Colors.white.withOpacity(0.05),
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${(progressPercent * 100).toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Inputs card
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
                      inputLabel,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pagesController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '0',
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.03),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 14),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          ),
                          onPressed: () => _handleAdd(khatam),
                          child: Text(labelAdd, style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32),

              // Reset button
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.redAccent.withOpacity(0.2)),
                    ),
                  ),
                  icon: Icon(Icons.refresh, size: 20),
                  label: Text(labelReset, style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    ref.read(khatamProvider.notifier).updateProgress(
                          pagesRead: 0,
                          startDate: DateTime.now().toIso8601String(),
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
}
