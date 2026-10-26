import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

class ZakatScreen extends ConsumerStatefulWidget {
  const ZakatScreen({super.key});

  @override
  ConsumerState<ZakatScreen> createState() => _ZakatScreenState();
}

class _ZakatScreenState extends ConsumerState<ZakatScreen> {
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _goldController = TextEditingController();
  final TextEditingController _goldPriceController = TextEditingController(text: '85000');

  String _currency = 'IQD'; // 'IQD' or 'USD'
  double? _totalWealth;
  double? _zakatMandatory;
  double? _calculatedNisab;
  bool _isEligible = false;

  static const double goldNisabGrams = 85.0;
  static const double zakatRate = 0.025; // 2.5%

  @override
  void dispose() {
    _cashController.dispose();
    _goldController.dispose();
    _goldPriceController.dispose();
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

  String _formatAmount(double val) {
    final isInt = (val - val.truncateToDouble()).abs() < 0.001;
    final fixed = isInt ? val.toStringAsFixed(0) : val.toStringAsFixed(2);
    final parts = fixed.split('.');
    final withCommas = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return parts.length > 1 ? '$withCommas.${parts[1]}' : withCommas;
  }

  void _switchCurrency(String newCurr) {
    if (_currency == newCurr) return;
    setState(() {
      _currency = newCurr;
      final currentPrice = double.tryParse(_normalizeDigits(_goldPriceController.text)) ?? 0;
      if (newCurr == 'USD' && (currentPrice >= 10000 || currentPrice == 0)) {
        _goldPriceController.text = '75';
      } else if (newCurr == 'IQD' && (currentPrice < 1000 || currentPrice == 0)) {
        _goldPriceController.text = '85000';
      }
      if (_totalWealth != null) {
        _calculate();
      }
    });
  }

  void _calculate() {
    final cashVal = double.tryParse(_normalizeDigits(_cashController.text)) ?? 0.0;
    final goldVal = double.tryParse(_normalizeDigits(_goldController.text)) ?? 0.0;
    final goldPrice = double.tryParse(_normalizeDigits(_goldPriceController.text)) ??
        (_currency == 'USD' ? 75.0 : 85000.0);

    final total = cashVal + (goldVal * goldPrice);
    final nisab = goldNisabGrams * goldPrice;

    setState(() {
      _totalWealth = total;
      _calculatedNisab = nisab;
      if (total >= nisab) {
        _isEligible = true;
        _zakatMandatory = total * zakatRate;
      } else {
        _isEligible = false;
        _zakatMandatory = 0.0;
      }
    });
    FocusScope.of(context).unfocus();
  }

  void _reset() {
    _cashController.clear();
    _goldController.clear();
    setState(() {
      _goldPriceController.text = _currency == 'USD' ? '75' : '85000';
      _totalWealth = null;
      _zakatMandatory = null;
      _calculatedNisab = null;
      _isEligible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isRTL = settings.language == 'ku' || settings.language == 'ar';
    final lang = settings.language;

    final title = lang == 'ku' ? 'ژمێرەری زەکات' : lang == 'ar' ? 'حاسبة الزكاة' : 'Zakat Calculator';
    final labelCurrency = lang == 'ku' ? 'دراو:' : lang == 'ar' ? 'العملة:' : 'Currency:';
    final cardGoldPriceTitle = lang == 'ku'
        ? 'نرخی ١ گرام زێڕ ($_currency)'
        : lang == 'ar'
            ? 'سعر غرام الذهب ($_currency)'
            : 'Gold Price per Gram ($_currency)';
    final cardCashTitle = lang == 'ku'
        ? 'دارایی و پارەی نەختینە ($_currency)'
        : lang == 'ar'
            ? 'المال والنقد ($_currency)'
            : 'Cash & Wealth ($_currency)';
    final cardGoldTitle = lang == 'ku'
        ? 'زێڕی هەبوو (بە گرام)'
        : lang == 'ar'
            ? 'الذهب المملوك (بالغرام)'
            : 'Owned Gold (Grams)';

    final labelCalculate = lang == 'ku' ? 'هەژمارکردن' : lang == 'ar' ? 'حساب الزكاة' : 'Calculate';
    final labelClear = lang == 'ku' ? 'پاککردنەوە' : lang == 'ar' ? 'مسح' : 'Clear';

    final statusMandatory = lang == 'ku'
        ? 'زەکاتت لەسەر فەرزە'
        : lang == 'ar'
            ? 'الزكاة واجبة عليك'
            : 'Zakat is Mandatory';
    final statusBelow = lang == 'ku'
        ? 'نەگەیشتووەتە ڕێژەی نیساب'
        : lang == 'ar'
            ? 'لم يبلغ النصاب'
            : 'Below Nisab Threshold';

    final resultTotalWealth = lang == 'ku' ? 'کۆی گشتی سەرمایە:' : lang == 'ar' ? 'إجمالي الثروة:' : 'Total Wealth:';
    final resultNisabVal = lang == 'ku' ? 'نیسابی شەرعی (٨٥ گرام):' : lang == 'ar' ? 'نصاب الزكاة (٨٥ غرام):' : 'Nisab Threshold (85g):';
    final resultZakatAmount = lang == 'ku' ? 'بڕی زەکاتی شەرعی (٢.٥٪):' : lang == 'ar' ? 'مقدار الزكاة (٢.٥٪):' : 'Zakat Due (2.5%):';
    final resultNisabText = lang == 'ku'
        ? 'بڕی سەرمایەکەت نەگەیشتووەتە نیساب کە بریتییە لە نرخی ٨٥ گرام زێڕ.'
        : lang == 'ar'
            ? 'أموالك لم تبلغ النصاب الشرعي (قيمة ٨٥ غراماً من الذهب).'
            : 'Your wealth has not reached the Nisab threshold (value of 85g gold).';

    final fatwaTitle = lang == 'ku' ? 'تێبینی شەرعی' : lang == 'ar' ? 'ملاحظة شرعية' : 'Fatwa Note';
    final fatwaText = lang == 'ku'
        ? 'زەکات کاتێک فەرز دەبێت کە ماڵ و سەرمایەت بگاتە نیساب (نرخی ٨٥ گرام زێڕ) و ساڵێکی تەواوی کۆچی بەسەردا تێپەڕ بووبێت.'
        : lang == 'ar'
            ? 'تجب الزكاة إذا بلغ المال النصاب (قيمة ٨٥ غراماً من الذهب) وحال عليه الحول الهجري كاملاً وكان فائضاً عن الحاجات الأصلية.'
            : 'Zakat becomes obligatory when total wealth reaches or exceeds the Nisab (85g pure gold) and remains in possession for one full lunar year.';

    final placeholderCash = lang == 'ku' ? 'بڕی پارەکەت بنووسە...' : lang == 'ar' ? 'أدخل المبلغ النقدي...' : 'Enter cash amount...';
    final placeholderGold = lang == 'ku' ? 'بڕی زێڕ بە گرام بنووسە...' : lang == 'ar' ? 'أدخل وزن الذهب بالغرام...' : 'Enter gold in grams...';
    final placeholderGoldPrice = lang == 'ku' ? 'نرخی ١ گرام زێڕ بنووسە...' : lang == 'ar' ? 'أدخل سعر غرام الذهب...' : 'Enter gold price per gram...';

    final currentGoldPrice = double.tryParse(_normalizeDigits(_goldPriceController.text)) ?? 0;
    final liveNisab = currentGoldPrice * goldNisabGrams;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
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
              // CURRENCY SELECTOR
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  children: [
                    Text(
                      labelCurrency,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _switchCurrency('IQD'),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _currency == 'IQD' ? primaryColor : Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    lang == 'ku' ? 'دینار (IQD)' : lang == 'ar' ? 'دينار عراقي' : 'IQD (Dinar)',
                                    style: TextStyle(
                                      color: _currency == 'IQD' ? Colors.white : Colors.white70,
                                      fontWeight: _currency == 'IQD' ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => _switchCurrency('USD'),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _currency == 'USD' ? primaryColor : Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    lang == 'ku' ? 'دۆلار (USD \$)' : lang == 'ar' ? 'دولار (\$ USD)' : 'USD (\$)',
                                    style: TextStyle(
                                      color: _currency == 'USD' ? Colors.white : Colors.white70,
                                      fontWeight: _currency == 'USD' ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // INPUT CARD
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
                    // GOLD PRICE PER GRAM
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          cardGoldPriceTitle,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        if (liveNisab > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${lang == 'ku' ? "نیساب" : lang == 'ar' ? "النصاب" : "Nisab"}: ${_formatAmount(liveNisab)} $_currency',
                              style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _goldPriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) {
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: placeholderGoldPrice,
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.03),
                        prefixIcon: Icon(Icons.price_change_outlined, color: primaryColor),
                        suffixText: _currency,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // CASH AMOUNT
                    Text(
                      cardCashTitle,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _cashController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: placeholderCash,
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.03),
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: primaryColor),
                        suffixText: _currency,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // GOLD WEIGHT
                    Text(
                      cardGoldTitle,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _goldController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: placeholderGold,
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.03),
                        prefixIcon: Icon(Icons.scale_outlined, color: primaryColor),
                        suffixText: lang == 'ku' ? 'گرام' : lang == 'ar' ? 'غرام' : 'g',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // CALCULATE BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _calculate,
                        child: Text(labelCalculate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: _reset,
                        child: Text(labelClear, style: TextStyle(color: Colors.white.withOpacity(0.4))),
                      ),
                    ),
                  ],
                ),
              ),

              // RESULT DISPLAY
              if (_totalWealth != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _isEligible
                        ? const Color(0xFF10B981).withOpacity(0.08)
                        : Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _isEligible
                          ? const Color(0xFF10B981).withOpacity(0.3)
                          : Colors.orange.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _isEligible ? Icons.check_circle : Icons.info_outline,
                        color: _isEligible ? const Color(0xFF10B981) : Colors.orange,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isEligible ? statusMandatory : statusBelow,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isEligible ? const Color(0xFF10B981) : Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(resultTotalWealth, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.6))),
                                Text(
                                  '${_formatAmount(_totalWealth!)} $_currency',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            if (_calculatedNisab != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(resultNisabVal, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.6))),
                                  Text(
                                    '${_formatAmount(_calculatedNisab!)} $_currency',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _isEligible
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(resultZakatAmount, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_formatAmount(_zakatMandatory!)} $_currency',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF10B981),
                                    ),
                                  )
                                ],
                              ),
                            )
                          : Text(
                              resultNisabText,
                              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7), height: 1.4),
                              textAlign: TextAlign.center,
                            ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // FATWA INFO CARD
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: primaryColor.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 $fatwaTitle',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      fatwaText,
                      style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.75), height: 1.5),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
