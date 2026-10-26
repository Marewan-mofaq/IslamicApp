import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../services/data_service.dart';

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

    final title = settings.language == 'ku' ? '🙏 چۆنیەتی نوێژکردن' : settings.language == 'ar' ? '🙏 كيفية الصلاة' : '🙏 How to Pray';
    final subtitle = settings.language == 'ku' ? 'فێرکاری هەنگاو بە هەنگاو' : settings.language == 'ar' ? 'دليل خطوة بخطوة' : 'Step-by-step prayer guide';
    
    final sectionTypes = settings.language == 'ku' ? '🕌 جۆرەکانی نوێژ' : settings.language == 'ar' ? 'أنواع الصلاة' : 'Types of Prayer';
    final sectionSteps = settings.language == 'ku' ? '📝 هەنگاوەکانی نوێژ' : settings.language == 'ar' ? 'خطوات الصلاة' : 'Prayer Steps';
    final rakaatLabel = settings.language == 'ku' ? 'رکعەت' : settings.language == 'ar' ? 'ركعة' : 'Rak\'at';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Rabar')),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
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
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, fontFamily: 'Rabar'),
                      textAlign: isRTL ? TextAlign.right : TextAlign.left,
                    ),
                  ),
                  SizedBox(height: 16),

                  // Section: Prayer Types (Horizontal list)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      sectionTypes,
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                      textAlign: isRTL ? TextAlign.right : TextAlign.left,
                    ),
                  ),
                  SizedBox(height: 12),
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
                        final typeName = (settings.language == 'ku' ? (type['name_ku'] ?? type['name_ar']) : settings.language == 'ar' ? (type['name_ar'] ?? type['name_ku']) : (type['name_en'] ?? type['name_ku']))?.toString() ?? '';

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
                                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    typeName,
                                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    rakaatLabel,
                                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontFamily: 'Rabar'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 32),

                  // Info card for selected prayer type
                  if (_selectedTypeId != null) ...[
                    Builder(
                      builder: (context) {
                        final selectedType = _types.firstWhere((t) => t['id'] == _selectedTypeId);
                        final typeName = (settings.language == 'ku' ? (selectedType['name_ku'] ?? selectedType['name_ar']) : settings.language == 'ar' ? (selectedType['name_ar'] ?? selectedType['name_ku']) : (selectedType['name_en'] ?? selectedType['name_ku']))?.toString() ?? '';
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
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '$typeName: ${selectedType['rakaat']} $rakaatLabel',
                                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
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
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                      textAlign: isRTL ? TextAlign.right : TextAlign.left,
                    ),
                  ),
                  SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _steps.length,
                    itemBuilder: (context, index) {
                      final step = _steps[index];
                      final isExpanded = _expandedStepId == step['id'];
                      
                      final stepTitle = (settings.language == 'ar'
                          ? (step['title_ar'] ?? step['title_ku'])
                          : settings.language == 'en'
                          ? (step['title_en'] ?? step['title_ku'])
                          : (step['title_ku'] ?? step['title_ar']))?.toString() ?? '';
                      
                      final stepDesc = (settings.language == 'ar'
                          ? (step['desc_ar'] ?? step['desc_ku'])
                          : settings.language == 'en'
                          ? (step['desc_en'] ?? step['desc_ku'])
                          : (step['desc_ku'] ?? step['desc_ar']))?.toString() ?? '';

                      final substepsKey = settings.language == 'en' ? 'substeps_en' : settings.language == 'ar' ? 'substeps_ar' : 'substeps_ku';
                      final fallbackKey = 'substeps_ku';
                      final substeps = step[substepsKey] ?? step[fallbackKey];

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
                                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                                ),
                              ),
                            ),
                            title: Row(
                              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                              children: [
                                Text(
                                  step['icon'] ?? '🤲',
                                  style: TextStyle(fontSize: 20),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    stepTitle,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Rabar',
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
                                    SizedBox(height: 8),
                                    Text(
                                      stepDesc,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 14,
                                        height: 1.6,
                                        fontFamily: 'Rabar',
                                      ),
                                      textAlign: isRTL ? TextAlign.right : TextAlign.left,
                                    ),
                                    
                                    // Arabic Supplication block if available
                                    if (step['arabic'] != null && step['arabic'].toString().isNotEmpty) ...[
                                      SizedBox(height: 14),
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
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                height: 1.6,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Traditional Arabic',
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            if (step['repeat'] != null && step['repeat'] > 1) ...[
                                              SizedBox(height: 8),
                                              Text(
                                                '×${step['repeat']}',
                                                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                    
                                    // Substeps lists (like Wudu sub-actions)
                                    if (substeps != null) ...[
                                      SizedBox(height: 12),
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
                                                  sub,
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(0.6),
                                                    fontSize: 13,
                                                    fontFamily: 'Rabar',
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
                  SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
