import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../services/data_service.dart';

const Map<int, List<String>> _fallbackSubstepsEn = {
  1: [
    "Make the sincere intention in the heart for Wudu to please Allah",
    "Say Bismillah (In the name of Allah) at the beginning",
    "Wash both hands up to the wrists three times",
    "Rinse the mouth thoroughly with water three times",
    "Inhale water into nostrils and blow it out three times",
    "Wash the entire face from hairline to chin three times",
    "Wash right arm including the elbow three times",
    "Wash left arm including the elbow three times",
    "Wipe wet hands over the head once",
    "Wipe the inside and outside of both ears once",
    "Wash right foot up to the ankle three times",
    "Wash left foot up to the ankle three times"
  ],
};

const Map<int, List<String>> _fallbackSubstepsAr = {
  1: [
    "النية بالقلب للوضوء تقرباً إلى الله تعالى",
    "التسمية بقول: بسم الله في البداية",
    "غسل الكفين إلى الرسغين ثلاث مرات",
    "المضمضة بالماء ثلاث مرات",
    "الاستنشاق والاستنثار ثلاث مرات",
    "غسل الوجه كاملاً من منابت الشعر إلى الذقن ثلاث مرات",
    "غسل اليد اليمنى مع المرفق ثلاث مرات",
    "غسل اليد اليسرى مع المرفق ثلاث مرات",
    "مسح الرأس مرة واحدة باليدين المبللتين",
    "مسح الأذنين ظاهراً وباطناً مرة واحدة",
    "غسل الرجل اليمنى مع الكعبين ثلاث مرات",
    "غسل الرجل اليسرى مع الكعبين ثلاث مرات"
  ],
};

class HowToPrayScreen extends ConsumerStatefulWidget {
  const HowToPrayScreen({super.key});

  @override
  ConsumerState<HowToPrayScreen> createState() => _HowToPrayScreenState();
}

class _HowToPrayScreenState extends ConsumerState<HowToPrayScreen> {
  bool _isLoading = true;
  List<dynamic> _steps = [];
  List<dynamic> _types = [];
  int? _expandedStepId;
  String? _selectedTypeId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final steps = await DataService.loadPraySteps();
      final types = await DataService.loadPrayTypes();
      if (mounted) {
        setState(() {
          _steps = steps;
          _types = types;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading how to pray data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.palette;
    final isRTL = settings.language == 'ku' || settings.language == 'ar';
    final String? appFont = isRTL ? 'Rabar' : null;

    final title = settings.language == 'ku' ? 'چۆنیەتی نوێژکردن' : settings.language == 'ar' ? 'كيفية الصلاة' : 'How to Pray';
    final subtitle = settings.language == 'ku' ? 'فێرکاری هەنگاو بە هەنگاو' : settings.language == 'ar' ? 'دليل خطوة بخطوة' : 'Step-by-step prayer guide';
    
    final sectionTypes = settings.language == 'ku' ? 'جۆرەکانی نوێژ' : settings.language == 'ar' ? 'أنواع الصلاة' : 'Types of Prayer';
    final sectionSteps = settings.language == 'ku' ? 'هەنگاوەکانی نوێژ' : settings.language == 'ar' ? 'خطوات الصلاة' : 'Prayer Steps';
    final rakaatLabel = settings.language == 'ku' ? 'رکعەت' : settings.language == 'ar' ? 'ركعة' : 'Rak\'at';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.accessibility_new_rounded, color: theme.primaryColor, size: 22),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: appFont)),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Directionality(
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header description
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Text(
                        subtitle,
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, fontFamily: appFont),
                        textAlign: isRTL ? TextAlign.right : TextAlign.left,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section: Prayer Types (Horizontal list)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        sectionTypes,
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: appFont),
                        textAlign: isRTL ? TextAlign.right : TextAlign.left,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _types.length,
                        itemBuilder: (context, index) {
                          final type = _types[index];
                          final isSelected = _selectedTypeId == type['id'];
                          final typeName = (settings.language == 'en'
                              ? (type['name_en'] ?? type['name_ar'] ?? type['name_ku'])
                              : settings.language == 'ar'
                                  ? (type['name_ar'] ?? type['name_ku'] ?? type['name_en'])
                                  : (type['name_ku'] ?? type['name_ar'] ?? type['name_en']))?.toString() ?? '';

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedTypeId = isSelected ? null : type['id'];
                                });
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 110,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.white.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.4) : Colors.white.withOpacity(0.05),
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${type['rakaat']}',
                                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: appFont),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      typeName,
                                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold, fontFamily: appFont),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      rakaatLabel,
                                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontFamily: appFont),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Info card for selected prayer type
                    if (_selectedTypeId != null) ...[
                      Builder(
                        builder: (context) {
                          final selectedType = _types.firstWhere((t) => t['id'] == _selectedTypeId);
                          final typeName = (settings.language == 'en'
                              ? (selectedType['name_en'] ?? selectedType['name_ar'] ?? selectedType['name_ku'])
                              : settings.language == 'ar'
                                  ? (selectedType['name_ar'] ?? selectedType['name_ku'] ?? selectedType['name_en'])
                                  : (selectedType['name_ku'] ?? selectedType['name_ar'] ?? selectedType['name_en']))?.toString() ?? '';
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                                children: [
                                  Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary, size: 20),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '$typeName: ${selectedType['rakaat']} $rakaatLabel',
                                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: appFont),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      ),
                    ],

                    // Section: Steps
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        sectionSteps,
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: appFont),
                        textAlign: isRTL ? TextAlign.right : TextAlign.left,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _steps.length,
                      itemBuilder: (context, index) {
                        final step = _steps[index];
                        final isExpanded = _expandedStepId == step['id'];
                        
                        final stepTitle = (settings.language == 'en'
                            ? (step['title_en'] ?? step['title_ar'] ?? step['title_ku'])
                            : settings.language == 'ar'
                                ? (step['title_ar'] ?? step['title_ku'] ?? step['title_en'])
                                : (step['title_ku'] ?? step['title_ar'] ?? step['title_en']))?.toString() ?? '';
                        
                        final stepDesc = (settings.language == 'en'
                            ? (step['desc_en'] ?? step['desc_ar'] ?? step['desc_ku'])
                            : settings.language == 'ar'
                                ? (step['desc_ar'] ?? step['desc_ku'] ?? step['desc_en'])
                                : (step['desc_ku'] ?? step['desc_ar'] ?? step['desc_en']))?.toString() ?? '';

                        final stepId = (step['id'] is int) ? (step['id'] as int) : (int.tryParse(step['id']?.toString() ?? '1') ?? 1);
                        final substeps = (settings.language == 'en'
                            ? (step['substeps_en'] ?? _fallbackSubstepsEn[stepId] ?? step['substeps_ku'])
                            : settings.language == 'ar'
                                ? (step['substeps_ar'] ?? _fallbackSubstepsAr[stepId] ?? step['substeps_ku'])
                                : (step['substeps_ku'] ?? step['substeps_ar'] ?? step['substeps_en']));

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.04)),
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              key: PageStorageKey<int>(step['id']),
                              initiallyExpanded: isExpanded,
                              onExpansionChanged: (expanded) {
                                setState(() {
                                  _expandedStepId = expanded ? step['id'] : null;
                                });
                              },
                              leading: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                                ),
                                child: Center(
                                  child: Text(
                                    '${step['step']}',
                                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: appFont),
                                  ),
                                ),
                              ),
                              title: Row(
                                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                                children: [
                                  Icon(
                                    Icons.accessibility_new_rounded,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      stepTitle,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: appFont,
                                      ),
                                      textAlign: isRTL ? TextAlign.right : TextAlign.left,
                                    ),
                                  ),
                                ],
                              ),
                              iconColor: Theme.of(context).colorScheme.primary,
                              collapsedIconColor: Colors.white.withOpacity(0.3),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Column(
                                    crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      const Divider(color: Colors.white10),
                                      const SizedBox(height: 8),
                                      Text(
                                        stepDesc,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 14,
                                          height: 1.6,
                                          fontFamily: appFont,
                                        ),
                                        textAlign: isRTL ? TextAlign.right : TextAlign.left,
                                      ),
                                      
                                      // Arabic Supplication block if available
                                      if (step['arabic'] != null && step['arabic'].toString().isNotEmpty) ...[
                                        const SizedBox(height: 14),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).cardColor,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.15)),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                step['arabic'],
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  height: 1.6,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'Traditional Arabic',
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              if (step['repeat'] != null && step['repeat'] > 1) ...[
                                                const SizedBox(height: 8),
                                                Text(
                                                  '×${step['repeat']}',
                                                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: appFont),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                      
                                      // Substeps lists (like Wudu sub-actions)
                                      if (substeps != null) ...[
                                        const SizedBox(height: 12),
                                        ...(substeps as List<dynamic>).map((sub) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  margin: EdgeInsets.only(top: 8, left: isRTL ? 8 : 0, right: isRTL ? 0 : 8),
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context).colorScheme.primary,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    sub.toString(),
                                                    style: TextStyle(
                                                      color: Colors.white.withOpacity(0.6),
                                                      fontSize: 13,
                                                      fontFamily: appFont,
                                                      height: 1.4,
                                                    ),
                                                    textAlign: isRTL ? TextAlign.right : TextAlign.left,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }
}
