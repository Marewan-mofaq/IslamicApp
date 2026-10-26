import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

class SituationsScreen extends ConsumerStatefulWidget {
  const SituationsScreen({super.key});

  @override
  ConsumerState<SituationsScreen> createState() => _SituationsScreenState();
}

class _SituationsScreenState extends ConsumerState<SituationsScreen> {
  Map<String, dynamic>? _selectedSituation;
  Future<List<dynamic>>? _situationsFuture;

  @override
  void initState() {
    super.initState();
    _situationsFuture = _loadSituations();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.palette;
    final isRTL = settings.language == 'ku' || settings.language == 'ar';

    final title = settings.language == 'ku' ? 'چۆن هەست دەکەیت؟' : settings.language == 'ar' ? 'بماذا تشعر؟' : 'How do you feel?';

    return PopScope(
      canPop: _selectedSituation == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _selectedSituation = null);
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
          future: _situationsFuture,
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
                GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.05,
                  ),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];
                    final name = (settings.language == 'ar'
                        ? (item['title_ar'] ?? item['title_ku'])
                        : settings.language == 'en'
                        ? (item['title_en'] ?? item['title_ku'])
                        : item['title_ku'])?.toString() ?? '';
                    final icon = (item['icon'] ?? '🤲').toString();
                    
                    Color color = const Color(0xFF3B82F6);
                    try {
                      final hex = (item['color'] ?? '').toString().replaceAll('#', '');
                      color = Color(int.parse('FF$hex', radix: 16));
                    } catch (_) {}

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedSituation = item;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withOpacity(0.2)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(icon, style: TextStyle(fontSize: 36)),
                            SizedBox(height: 8),
                            Text(
                              name,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Modal dialog overlay
                if (_selectedSituation != null)
                  _buildDuaOverlay(_selectedSituation!, settings.language, isRTL),
              ],
            );
          },
        ),
      ),
    ),
    );
  }

  Future<List<dynamic>> _loadSituations() async {
    final raw = await DefaultAssetBundle.of(context).loadString('assets/data/situations.json');
    return jsonDecode(raw) as List<dynamic>;
  }

  Widget _buildDuaOverlay(Map<String, dynamic> situation, String lang, bool isRTL) {
    final title = (lang == 'ar'
        ? (situation['title_ar'] ?? situation['title_ku'])
        : lang == 'en'
        ? (situation['title_en'] ?? situation['title_ku'])
        : situation['title_ku'])?.toString() ?? '';

    Color color = const Color(0xFF3B82F6);
    try {
      final hex = (situation['color'] ?? '').toString().replaceAll('#', '');
      color = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {}

    final List<dynamic> duas = situation['duas'] ?? [];

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
                color: color.withOpacity(0.12),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${situation['icon'] ?? '🤲'}  $title',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 28),
                    onPressed: () {
                      setState(() {
                        _selectedSituation = null;
                      });
                    },
                  )
                ],
              ),
            ),

            // Duas List
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                itemCount: duas.length,
                itemBuilder: (context, idx) {
                  final dua = duas[idx];
                  final arabic = (dua['arabic'] ?? '').toString();
                  final trans = lang == 'en' ? (dua['en'] ?? '').toString() : lang == 'ar' ? (dua['ar'] ?? dua['arabic'] ?? '').toString() : (dua['ku'] ?? '').toString();
                  final refText = (dua['ref'] ?? '').toString();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          arabic,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            height: 1.6,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                        ),
                        if (trans.isNotEmpty) ...[
                          SizedBox(height: 12),
                          Text(
                            trans,
                            style: TextStyle(fontSize: 14, height: 1.4, color: Colors.white.withOpacity(0.65)),
                            textAlign: isRTL ? TextAlign.right : TextAlign.left,
                          ),
                        ],
                        if (refText.isNotEmpty) ...[
                          SizedBox(height: 12),
                          Align(
                            alignment: isRTL ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                refText,
                                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                              ),
                            ),
                          )
                        ]
                      ],
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
