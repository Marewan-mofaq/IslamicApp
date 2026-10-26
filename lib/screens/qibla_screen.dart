import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../services/data_service.dart';
import '../models/city.dart';

class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends ConsumerState<QiblaScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  double _qiblaAngle = 0;
  double _distance = 0;
  City? _activeCity;
  double _currentPhoneRotation = 0.0;
  bool _wasAlignedBefore = false;

  // Sensor state
  StreamSubscription<CompassEvent>? _compassSubscription;
  bool _hasCompassSensor = true;
  bool _manualMode = false;

  late AnimationController _animationController;
  late Animation<double> _animation;

  static const double makkahLat = 21.3891;
  static const double makkahLng = 39.8579;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _loadLocation();
    _initCompass();
  }

  void _initCompass() {
    try {
      final events = FlutterCompass.events;
      if (events == null) {
        setState(() {
          _hasCompassSensor = false;
          _manualMode = true;
        });
        return;
      }

      _compassSubscription = events.listen((event) {
        if (!mounted) return;
        final heading = event.heading;
        if (heading == null) {
          if (_hasCompassSensor) {
            setState(() => _hasCompassSensor = false);
          }
          return;
        }

        if (!_hasCompassSensor) {
          setState(() => _hasCompassSensor = true);
        }

        if (!_manualMode) {
          final normalized = (heading + 360) % 360;
          setState(() {
            _currentPhoneRotation = normalized;
          });
          _updateAnimation();
        }
      }, onError: (_) {
        if (mounted) {
          setState(() {
            _hasCompassSensor = false;
            _manualMode = true;
          });
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasCompassSensor = false;
          _manualMode = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    try {
      final cities = await DataService.loadCities();
      if (!mounted) return;
      final settings = ref.read(settingsProvider);

      final active = cities.firstWhere(
        (c) => c.id == settings.userCityId,
        orElse: () => cities.first,
      );

      final bearing = _calculateQibla(active.lat, active.lng);
      final dist = _getDistanceToMakkah(active.lat, active.lng);

      if (mounted) {
        setState(() {
          _activeCity = active;
          _qiblaAngle = bearing;
          _distance = dist;
          _isLoading = false;
        });
        _updateAnimation();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _toRad(double deg) => (deg * math.pi) / 180;
  double _toDeg(double rad) => (rad * 180) / math.pi;

  double _calculateQibla(double latitude, double longitude) {
    final lat1 = _toRad(latitude);
    final lat2 = _toRad(makkahLat);
    final dLng = _toRad(makkahLng - longitude);

    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLng);

    double bearing = math.atan2(y, x);
    bearing = _toDeg(bearing);
    bearing = (bearing + 360) % 360;

    return bearing;
  }

  double _getDistanceToMakkah(double lat, double lng) {
    const r = 6371.0;
    final dLat = _toRad(makkahLat - lat);
    final dLng = _toRad(makkahLng - lng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) + math.cos(_toRad(lat)) * math.cos(_toRad(makkahLat)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  void _updateAnimation() {
    double arrowRotation = _qiblaAngle - _currentPhoneRotation;
    arrowRotation = (arrowRotation + 360) % 360;

    double start = _animation.value;
    double end = _toRad(arrowRotation);

    // Shortest path rotation
    double diff = end - start;
    while (diff < -math.pi) diff += 2 * math.pi;
    while (diff > math.pi) diff -= 2 * math.pi;

    _animation = Tween<double>(begin: start, end: start + diff).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isRTL = settings.language == 'ku' || settings.language == 'ar';
    final lang = settings.language;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final title = lang == 'ku' ? 'ئاراستەی قیبلە' : lang == 'ar' ? 'اتجاه القبلة' : 'Qibla Compass';

    double relativeAngle = (_qiblaAngle - _currentPhoneRotation).abs() % 360;
    if (relativeAngle > 180) relativeAngle = 360 - relativeAngle;
    final isAligned = relativeAngle < 4.5;

    if (isAligned && !_wasAlignedBefore) {
      _wasAlignedBefore = true;
      HapticFeedback.heavyImpact();
    } else if (!isAligned) {
      _wasAlignedBefore = false;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_rounded, color: primaryColor, size: 22),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: primaryColor, fontFamily: 'Rabar', fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Directionality(
              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    // LOCATION & DISTANCE HEADER CARD
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: primaryColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.explore, color: primaryColor),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang == 'ku' ? 'شار' : lang == 'ar' ? 'المدينة' : 'City',
                                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontFamily: 'Rabar'),
                                  ),
                                  Text(
                                    _activeCity != null
                                        ? (lang == 'ku'
                                            ? _activeCity!.ku
                                            : lang == 'ar'
                                                ? _activeCity!.ar
                                                : _activeCity!.en)
                                        : '',
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(width: 1, height: 30, color: Colors.white10),
                          Row(
                            children: [
                              const Icon(Icons.navigation, color: Color(0xFF10B981), size: 20),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang == 'ku' ? 'پلەی قیبلە' : lang == 'ar' ? 'زاوية القبلة' : 'Qibla Angle',
                                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontFamily: 'Rabar'),
                                  ),
                                  Text(
                                    '${_qiblaAngle.toStringAsFixed(0)}°',
                                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(width: 1, height: 30, color: Colors.white10),
                          Row(
                            children: [
                              Icon(Icons.mosque_rounded, color: primaryColor, size: 20),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang == 'ku' ? 'دووری' : lang == 'ar' ? 'المسافة' : 'Distance',
                                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontFamily: 'Rabar'),
                                  ),
                                  Text(
                                    '${_distance.toStringAsFixed(0)} km',
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // SENSOR STATUS & MODE TOGGLE BAR
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _hasCompassSensor && !_manualMode
                                      ? const Color(0xFF10B981)
                                      : Colors.amber,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                !_hasCompassSensor
                                    ? (lang == 'ku' ? 'هەستەوەر بەردەست نییە' : lang == 'ar' ? 'المستشعر غير متوفر' : 'Sensor Unavailable')
                                    : _manualMode
                                        ? (lang == 'ku' ? 'دۆخی دەستی' : lang == 'ar' ? 'الوضع اليدوي' : 'Manual Mode')
                                        : (lang == 'ku' ? 'قیبلەپێوی ئۆتۆماتیک' : lang == 'ar' ? 'البوصلة التلقائية' : 'Live Compass Sensor'),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              if (!_manualMode && _hasCompassSensor) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '(${_currentPhoneRotation.toStringAsFixed(0)}°)',
                                  style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ],
                          ),
                          if (_hasCompassSensor)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _manualMode = !_manualMode;
                                });
                                if (!_manualMode) {
                                  _updateAnimation();
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _manualMode
                                      ? (lang == 'ku' ? 'گەڕانەوە بۆ ئۆتۆماتیک' : lang == 'ar' ? 'تفعيل التلقائي' : 'Enable Sensor')
                                      : (lang == 'ku' ? 'دەستکاری بە دەست' : lang == 'ar' ? 'تحكم يدوي' : 'Manual'),
                                  style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // LUXURIOUS ROTATING COMPASS DIAL
                    Center(
                      child: Container(
                        width: 290,
                        height: 290,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).cardColor,
                          border: Border.all(
                            color: isAligned ? const Color(0xFF10B981) : primaryColor,
                            width: isAligned ? 4 : 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isAligned
                                  ? const Color(0xFF10B981).withOpacity(0.4)
                                  : primaryColor.withOpacity(0.15),
                              blurRadius: 30,
                              spreadRadius: 8,
                            )
                          ],
                        ),
                        child: AnimatedBuilder(
                          animation: _animation,
                          builder: (context, child) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Top Forward Alignment Notch (indicates where phone faces)
                                Align(
                                  alignment: Alignment.topCenter,
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    width: 8,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: isAligned ? const Color(0xFF10B981) : primaryColor,
                                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                                    ),
                                  ),
                                ),

                                // ROTATING COMPASS DIAL (North aligns with physical Earth North)
                                Transform.rotate(
                                  angle: -_toRad(_currentPhoneRotation),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Outer Ring Ticks
                                      ...List.generate(12, (index) {
                                        final angle = (index * 30) * math.pi / 180;
                                        return Transform.rotate(
                                          angle: angle,
                                          child: Align(
                                            alignment: Alignment.topCenter,
                                            child: Container(
                                              margin: const EdgeInsets.only(top: 8),
                                              width: index % 3 == 0 ? 3 : 1.5,
                                              height: index % 3 == 0 ? 14 : 8,
                                              color: index % 3 == 0 ? primaryColor : Colors.white24,
                                            ),
                                          ),
                                        );
                                      }),

                                      // Cardinal Directions (rotate with Earth)
                                      Transform.translate(
                                        offset: const Offset(0, -118),
                                        child: const Text('N', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                                      ),
                                      Transform.translate(
                                        offset: const Offset(118, 0),
                                        child: const Text('E', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)),
                                      ),
                                      Transform.translate(
                                        offset: const Offset(0, 118),
                                        child: const Text('S', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)),
                                      ),
                                      Transform.translate(
                                        offset: const Offset(-118, 0),
                                        child: const Text('W', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)),
                                      ),
                                    ],
                                  ),
                                ),

                                // Center Kaaba Icon
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).scaffoldBackgroundColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isAligned ? const Color(0xFF10B981) : primaryColor.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.mosque_rounded,
                                      size: 26,
                                      color: isAligned ? const Color(0xFF10B981) : primaryColor,
                                    ),
                                  ),
                                ),

                                // Rotating Qibla Pointer Needle
                                Transform.rotate(
                                  angle: _animation.value,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Positioned(
                                        top: 25,
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              color: isAligned ? const Color(0xFF10B981) : primaryColor,
                                              size: 34,
                                            ),
                                            Container(
                                              width: 4,
                                              height: 75,
                                              decoration: BoxDecoration(
                                                color: isAligned ? const Color(0xFF10B981) : primaryColor,
                                                borderRadius: BorderRadius.circular(2),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: isAligned
                                                        ? const Color(0xFF10B981).withOpacity(0.6)
                                                        : primaryColor.withOpacity(0.4),
                                                    blurRadius: 10,
                                                  )
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ALIGNMENT STATUS BANNER
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: isAligned ? const Color(0xFF10B981).withOpacity(0.15) : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isAligned ? const Color(0xFF10B981) : primaryColor.withOpacity(0.2),
                          width: isAligned ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isAligned ? Icons.check_circle_rounded : Icons.explore_rounded,
                            color: isAligned ? const Color(0xFF10B981) : primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isAligned
                                ? (lang == 'ku'
                                    ? 'تۆ بە تەواوی لەسەر ئاراستەی قیبلەیت!'
                                    : lang == 'ar'
                                        ? 'أنت باتجاه القبلة تماماً!'
                                        : 'You are facing Qibla directly!')
                                : (lang == 'ku'
                                    ? 'ئاراستەی قیبلە: ${_qiblaAngle.toStringAsFixed(0)}°'
                                    : lang == 'ar'
                                        ? 'زاوية القبلة: ${_qiblaAngle.toStringAsFixed(0)}°'
                                        : 'Qibla Angle: ${_qiblaAngle.toStringAsFixed(0)}°'),
                            style: TextStyle(
                              color: isAligned ? const Color(0xFF10B981) : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Rabar',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // SENSOR GUIDANCE OR MANUAL SLIDER
                    if (_manualMode) ...[
                      Text(
                        lang == 'ku'
                            ? 'دەتوانیت سلایدەرەکە بجووڵێنیت بۆ تاقیکردنەوەی ئاراستەکە'
                            : lang == 'ar'
                                ? 'يمكنك تحريك المؤشر لاختبار الاتجاه'
                                : 'Move slider to rotate compass manually',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontFamily: 'Rabar'),
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: primaryColor,
                          inactiveTrackColor: Colors.white.withOpacity(0.08),
                          thumbColor: primaryColor,
                          trackHeight: 4.0,
                        ),
                        child: Slider(
                          min: 0.0,
                          max: 360.0,
                          value: _currentPhoneRotation,
                          onChanged: (val) {
                            setState(() {
                              _currentPhoneRotation = val;
                            });
                            _updateAnimation();
                          },
                        ),
                      ),
                    ] else ...[
                      // SENSOR GUIDANCE CARD
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              lang == 'ku'
                                  ? 'مۆبایلەکەت لەسەر دەستت بە ئاسۆیی (تەخت) بگرە و بیخولێنەوە تا نیشاندەرەکە بچێتە سەر کێشەی کەعبە.'
                                  : lang == 'ar'
                                      ? 'أمسك الهاتف أفقياً وقم بتدويره حتى يتطابق المؤشر مع القبلة.'
                                      : 'Hold phone flat and rotate until needle points directly to Kaaba.',
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, height: 1.4),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lightbulb_outline_rounded, size: 14, color: primaryColor.withOpacity(0.8)),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    lang == 'ku'
                                        ? 'بۆ کالیبرەکردنەوەی وردبینی قیبلەپێو، مۆبایلەکەت بە شێوەی ژمارە (8) بجووڵێنە.'
                                        : lang == 'ar'
                                            ? 'لمعايرة البوصلة، حرك الهاتف في الهواء على شكل رقم (8).'
                                            : 'To calibrate compass accuracy, wave phone in a figure-8 motion.',
                                    style: TextStyle(color: primaryColor.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w500),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
