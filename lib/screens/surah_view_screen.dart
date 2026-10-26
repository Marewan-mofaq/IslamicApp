import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../providers/bookmarks_provider.dart';
import '../services/data_service.dart';
import '../services/audio_downloader_service.dart';
import '../services/notification_service.dart';
import '../services/quran_audio_handler.dart';

class SurahViewScreen extends ConsumerStatefulWidget {
  final int surahId;
  final String surahNameKu;
  final String surahNameAr;
  final String surahNameEn;
  final int initialAyahId;

  const SurahViewScreen({
    super.key,
    required this.surahId,
    required this.surahNameKu,
    required this.surahNameAr,
    required this.surahNameEn,
    this.initialAyahId = 1,
  });

  @override
  ConsumerState<SurahViewScreen> createState() => _SurahViewScreenState();
}

class _SurahViewScreenState extends ConsumerState<SurahViewScreen> {
  late Future<Map<String, dynamic>> _versesFuture;

  // Reading mode: 'ayah' or 'mushaf'
  String _viewMode = 'ayah';
  
  // Reading color mode: 'dark', 'sepia', 'black'
  String _readingColorTheme = 'dark';

  // Font settings
  double _arabicFontSize = 26.0;
  double _translationFontSize = 14.0;
  bool _showTranslation = true;

  // Playback speed: 1.0, 1.25, 1.5, 2.0
  double _playbackSpeed = 1.0;

  // Auto-scroll mode
  bool _isAutoScrolling = false;
  double _autoScrollSpeed = 1.0;
  Timer? _autoScrollTimer;

  // Reciters state (loads ALL 38 reciters from assets/data/reciters.json)
  List<dynamic> _recitersList = [];
  dynamic _selectedReciter;
  String _reciterSearchQuery = '';

  // Audio state
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _playingAyahId;
  bool _isPlayingAudio = false;
  bool _isFullSurahMode = false;
  int _hifzRepeatCount = 1;
  int _currentRepeatIndex = 1;
  int _totalVersesInSurah = 0;
  bool _reciterChangedWhilePaused = false;
  int _lastActiveAyahId = 1;

  // Download & Offline caching state
  bool _isSurahDownloaded = false;
  bool _isDownloadingAudio = false;
  double _downloadProgress = 0.0;
  bool _hasScrolledInitialAyah = false;
  Set<int> _downloadedAyahs = {};
  int? _downloadingAyahNum;

  // Full Surah audio durations
  Duration _fullDuration = Duration.zero;
  Duration _fullPosition = Duration.zero;
  Duration _currentAyahDuration = Duration.zero;
  Duration _currentAyahPosition = Duration.zero;

  // Pages & Cached Verses
  int? _startSurahPage;
  int? _endSurahPage;
  int _currentVisiblePage = 1;
  int _currentVisibleJuz = 1;
  List<dynamic>? _cachedVerses;

  // Scroll controller & Ayah GlobalKeys for precise alignment
  final ScrollController _scrollController = ScrollController();
  Map<int, GlobalKey>? _ayahKeys;
  Map<int, GlobalKey> get _safeAyahKeys => _ayahKeys ??= {};

  // Audio player stream subscriptions
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _compSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    final initialPage = DataService.surahStartPages[widget.surahId] ?? 1;
    _startSurahPage = initialPage;
    _currentVisiblePage = initialPage;
    _currentVisibleJuz = DataService.getPageJuz(initialPage);

    _scrollController.addListener(_updateVisiblePageOnScroll);
    _versesFuture = DataService.loadSurahVerses(widget.surahId).then((data) {
      if (mounted && data != null && data['verses'] != null) {
        final List<dynamic> verses = data['verses'];
        _cachedVerses = verses;
        if (verses.isNotEmpty) {
          final firstP = (verses.first['page'] as int?) ?? initialPage;
          final firstJ = (verses.first['juz'] as int?) ?? _currentVisibleJuz;
          _startSurahPage = firstP;
          _endSurahPage = (verses.last['page'] as int?) ?? firstP;

          int targetP = firstP;
          int targetJ = firstJ;
          if (widget.initialAyahId > 1) {
            for (final v in verses) {
              if (v['id'] == widget.initialAyahId) {
                targetP = (v['page'] as int?) ?? firstP;
                targetJ = (v['juz'] as int?) ?? firstJ;
                break;
              }
            }
          }

          if (targetP != _currentVisiblePage || targetJ != _currentVisibleJuz) {
            setState(() {
              _currentVisiblePage = targetP;
              _currentVisibleJuz = targetJ;
            });
          }
        }
      }
      return data;
    });
    _loadRecitersData();
    _loadSavedSpeed();
    _saveLastRead(widget.surahId, widget.surahNameKu, widget.initialAyahId);

    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        _audioPlayer.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              isSpeakerphoneOn: false,
              stayAwake: true,
              contentType: AndroidContentType.music,
              usageType: AndroidUsageType.media,
              audioFocus: AndroidAudioFocus.gain,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
              options: const {},
            ),
          ),
        );
        _audioPlayer.setReleaseMode(ReleaseMode.stop);
      } catch (e) {
        debugPrint('[SurahView] Error setting audio context: $e');
      }
    }

    _stateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        if (state == PlayerState.playing && _playbackSpeed != 1.0) {
          _audioPlayer.setPlaybackRate(_playbackSpeed);
        }
        _updatePlaybackNotification();
      }
    });

    _posSub = _audioPlayer.onPositionChanged.listen((pos) {
      if (!mounted) return;
      if (_isFullSurahMode) {
        setState(() => _fullPosition = pos);

        if (_totalVersesInSurah > 0 && _fullDuration > Duration.zero) {
          final double progress = pos.inMilliseconds / _fullDuration.inMilliseconds;
          final int calculatedAyah = (progress * _totalVersesInSurah).floor() + 1;
          final int currentAyah = calculatedAyah.clamp(1, _totalVersesInSurah);

          if (_playingAyahId != currentAyah) {
            setState(() {
              _playingAyahId = currentAyah;
            });
            _scrollToAyah(currentAyah);
          }
        }
      } else {
        _currentAyahPosition = pos;
      }
    });

    _durSub = _audioPlayer.onDurationChanged.listen((dur) {
      if (!mounted) return;
      if (_isFullSurahMode) {
        setState(() => _fullDuration = dur);
      } else {
        _currentAyahDuration = dur;
      }
      if (_isPlayingAudio) {
        QuranAudioHandler.instance?.updatePlaybackStatus(
          isPlaying: true,
          position: _isFullSurahMode ? _fullPosition : _currentAyahPosition,
          duration: dur > Duration.zero ? dur : null,
          speed: _playbackSpeed,
        );
      }
    });

    _compSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        if (!_isFullSurahMode && _playingAyahId != null) {
          if (_currentRepeatIndex < _hifzRepeatCount) {
            _currentRepeatIndex++;
            _playAyahAudio(widget.surahId, _playingAyahId!, resetRepeatIndex: false);
          } else {
            final nextAyah = _playingAyahId! + 1;
            if (_totalVersesInSurah > 0 && nextAyah <= _totalVersesInSurah) {
              _playAyahAudio(widget.surahId, nextAyah);
            } else {
              setState(() {
                _isPlayingAudio = false;
                _playingAyahId = null;
                _currentRepeatIndex = 1;
              });
              _updatePlaybackNotification();
            }
          }
        } else {
          setState(() {
            _isPlayingAudio = false;
            _playingAyahId = null;
          });
          _updatePlaybackNotification();
        }
      }
    });

    final handler = QuranAudioHandler.instance;
    if (handler != null) {
      handler.onPlayCallback = () async {
        if (!mounted) return;
        if (_audioPlayer.state == PlayerState.paused) {
          await _audioPlayer.resume();
          setState(() => _isPlayingAudio = true);
          _updatePlaybackNotification();
        } else {
          final targetAyah = _playingAyahId ?? _lastActiveAyahId;
          _playAyahAudio(widget.surahId, targetAyah);
        }
      };

      handler.onPauseCallback = () async {
        if (!mounted) return;
        await _audioPlayer.pause();
        setState(() => _isPlayingAudio = false);
        _updatePlaybackNotification();
      };

      handler.onStopCallback = () async {
        if (!mounted) return;
        await _audioPlayer.stop();
        setState(() {
          _isPlayingAudio = false;
          _playingAyahId = null;
        });
        _updatePlaybackNotification(isDismissed: true);
      };

      handler.onSkipToNextCallback = () {
        if (!mounted) return;
        final current = _playingAyahId ?? _lastActiveAyahId;
        final next = current + 1;
        if (_totalVersesInSurah > 0 && next <= _totalVersesInSurah) {
          _playAyahAudio(widget.surahId, next);
        }
      };

      handler.onSkipToPreviousCallback = () {
        if (!mounted) return;
        final current = _playingAyahId ?? _lastActiveAyahId;
        final prev = current - 1;
        if (prev >= 1) {
          _playAyahAudio(widget.surahId, prev);
        }
      };

      handler.onSeekCallback = (pos) {
        if (!mounted) return;
        _audioPlayer.seek(pos);
      };
    }

    NotificationService.onQuranPlaybackAction = (action) async {
      if (!mounted) return;
      if (action == 'quran_play_pause') {
        if (_isPlayingAudio) {
          await _audioPlayer.pause();
          setState(() => _isPlayingAudio = false);
          _updatePlaybackNotification();
        } else {
          if (_audioPlayer.state == PlayerState.paused) {
            await _audioPlayer.resume();
            setState(() => _isPlayingAudio = true);
            _updatePlaybackNotification();
          } else {
            final targetAyah = _playingAyahId ?? _lastActiveAyahId;
            _playAyahAudio(widget.surahId, targetAyah);
          }
        }
      } else if (action == 'quran_next') {
        final current = _playingAyahId ?? _lastActiveAyahId;
        final next = current + 1;
        if (_totalVersesInSurah > 0 && next <= _totalVersesInSurah) {
          _playAyahAudio(widget.surahId, next);
        }
      } else if (action == 'quran_prev') {
        final current = _playingAyahId ?? _lastActiveAyahId;
        final prev = current - 1;
        if (prev >= 1) {
          _playAyahAudio(widget.surahId, prev);
        }
      } else if (action == 'quran_stop') {
        await _audioPlayer.stop();
        setState(() {
          _isPlayingAudio = false;
          _playingAyahId = null;
        });
        _updatePlaybackNotification(isDismissed: true);
      }
    };
  }

  @override
  void dispose() {
    _updatePlaybackNotification(isDismissed: true);
    final handler = QuranAudioHandler.instance;
    if (handler != null) {
      handler.onPlayCallback = null;
      handler.onPauseCallback = null;
      handler.onStopCallback = null;
      handler.onSkipToNextCallback = null;
      handler.onSkipToPreviousCallback = null;
      handler.onSeekCallback = null;
    }
    NotificationService.onQuranPlaybackAction = null;
    _autoScrollTimer?.cancel();
    _isAutoScrolling = false;
    _posSub?.cancel();
    _durSub?.cancel();
    _compSub?.cancel();
    _stateSub?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _scrollController.removeListener(_updateVisiblePageOnScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _syncPageAndJuzForAyah(int ayahNum) {
    if (_cachedVerses != null) {
      for (final v in _cachedVerses!) {
        if (v['id'] == ayahNum) {
          final p = (v['page'] as int?) ?? _currentVisiblePage;
          final j = (v['juz'] as int?) ?? _currentVisibleJuz;
          if (p != _currentVisiblePage || j != _currentVisibleJuz) {
            _currentVisiblePage = p;
            _currentVisibleJuz = j;
          }
          break;
        }
      }
    }
  }

  void _updateVisiblePageOnScroll() {
    if (!mounted || _cachedVerses == null || _cachedVerses!.isEmpty) return;

    // If near the top, reflect the starting page and juz of the surah
    if (_scrollController.hasClients && _scrollController.offset <= 80) {
      final firstP = (_cachedVerses!.first['page'] as int?) ?? 1;
      final firstJ = (_cachedVerses!.first['juz'] as int?) ?? 1;
      if (_currentVisiblePage != firstP || _currentVisibleJuz != firstJ) {
        setState(() {
          _currentVisiblePage = firstP;
          _currentVisibleJuz = firstJ;
        });
      }
      return;
    }

    if (_ayahKeys == null || _ayahKeys!.isEmpty) return;
    final double topThreshold = MediaQuery.of(context).padding.top + kToolbarHeight + 40;
    int? topVerseId;
    double minTopDelta = double.infinity;

    for (final entry in _ayahKeys!.entries) {
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      try {
        final pos = box.localToGlobal(Offset.zero);
        final top = pos.dy;
        final bottom = top + box.size.height;
        if (bottom >= topThreshold && top <= MediaQuery.of(context).size.height) {
          final delta = (top - topThreshold).abs();
          if (delta < minTopDelta) {
            minTopDelta = delta;
            topVerseId = entry.key;
          }
        }
      } catch (_) {}
    }

    if (topVerseId != null) {
      for (final v in _cachedVerses!) {
        if (v['id'] == topVerseId) {
          final p = (v['page'] as int?) ?? _currentVisiblePage;
          final j = (v['juz'] as int?) ?? _currentVisibleJuz;
          if (p != _currentVisiblePage || j != _currentVisibleJuz) {
            setState(() {
              _currentVisiblePage = p;
              _currentVisibleJuz = j;
            });
          }
          break;
        }
      }
    }
  }

  void _updatePlaybackNotification({bool isDismissed = false}) {
    if (isDismissed) {
      NotificationService.dismissQuranPlaybackNotification();
      QuranAudioHandler.instance?.updatePlaybackStatus(
        isPlaying: false,
        position: Duration.zero,
        isStopped: true,
      );
      return;
    }

    final settings = ref.read(settingsProvider);
    final lang = settings.language;
    final surahName = lang == 'en'
        ? widget.surahNameEn
        : (lang == 'ar' ? widget.surahNameAr : widget.surahNameKu);
    final reciterName = _selectedReciter != null
        ? (lang == 'en'
            ? (_selectedReciter['name_en'] ?? _selectedReciter['name_ku'] ?? '')
            : (lang == 'ar' ? (_selectedReciter['name_ar'] ?? _selectedReciter['name_ku'] ?? '') : (_selectedReciter['name_ku'] ?? _selectedReciter['name_ar'] ?? '')))
        : 'Alafasy';

    final activeAyah = _playingAyahId ?? _lastActiveAyahId;
    final ayahInfo = activeAyah > 0 ? 'ئایەتی $activeAyah' : null;

    NotificationService.showQuranPlaybackNotification(
      surahName: surahName,
      reciterName: reciterName.toString(),
      isPlaying: _isPlayingAudio,
      ayahInfo: ayahInfo,
    );

    final handler = QuranAudioHandler.instance;
    if (handler != null) {
      final title = ayahInfo != null ? '$surahName ($ayahInfo)' : surahName;
      final currentDur = _isFullSurahMode ? _fullDuration : _currentAyahDuration;
      final currentPos = _isFullSurahMode ? _fullPosition : _currentAyahPosition;
      handler.setQuranMediaItem(
        id: '${widget.surahId}_$activeAyah',
        title: title,
        artist: reciterName.toString(),
        duration: currentDur > Duration.zero ? currentDur : null,
      );
      handler.updatePlaybackStatus(
        isPlaying: _isPlayingAudio,
        position: currentPos,
        duration: currentDur > Duration.zero ? currentDur : null,
        speed: _playbackSpeed,
        isStopped: false,
      );
    }
  }

  Future<void> _loadSavedSpeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final speed = prefs.getDouble('quranPlaybackSpeed') ?? 1.0;
      if (mounted) {
        setState(() => _playbackSpeed = speed);
      }
    } catch (_) {}
  }

  String _normalizeDigits(String input) {
    const easternArabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const westernArabic = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String result = input;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(easternArabic[i], westernArabic[i]);
    }
    return result;
  }

  int? _findNearestRenderedAyah(int targetAyah) {
    int? nearest;
    int minDiff = 999999;
    _safeAyahKeys.forEach((ayahNum, key) {
      if (key.currentContext != null) {
        final diff = (ayahNum - targetAyah).abs();
        if (diff < minDiff) {
          minDiff = diff;
          nearest = ayahNum;
        }
      }
    });
    return nearest;
  }

  void _scrollToAyah(int ayahIndex) {
    if (ayahIndex < 1) return;
    _syncPageAndJuzForAyah(ayahIndex);
    if (mounted) setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1. Direct scroll if GlobalKey is already built and attached
      final key = _safeAyahKeys[ayahIndex];
      if (key?.currentContext != null) {
        try {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            alignment: 0.12,
          );
          return;
        } catch (_) {}
      }

      if (!_scrollController.hasClients) return;

      // 2. Dynamic multi-step scroll using nearest rendered Ayah feedback
      final double avgHeight = _arabicFontSize * 4.2 + (_showTranslation ? 110.0 : 50.0);
      double estimatedOffset = (ayahIndex <= 1) ? 0.0 : (140.0 + (ayahIndex - 1) * avgHeight);

      for (int attempt = 0; attempt < 6; attempt++) {
        if (!mounted || !_scrollController.hasClients) break;

        final checkKey = _safeAyahKeys[ayahIndex];
        if (checkKey?.currentContext != null) {
          try {
            await Scrollable.ensureVisible(
              checkKey!.currentContext!,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: 0.12,
            );
            return;
          } catch (_) {}
        }

        final maxExtent = _scrollController.position.maxScrollExtent;
        final double stepTarget = estimatedOffset.clamp(0.0, maxExtent);
        _scrollController.jumpTo(stepTarget);

        await Future.delayed(const Duration(milliseconds: 50));
        if (!mounted || !_scrollController.hasClients) return;

        final retryKey = _safeAyahKeys[ayahIndex];
        if (retryKey?.currentContext != null) {
          try {
            await Scrollable.ensureVisible(
              retryKey!.currentContext!,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: 0.12,
            );
            return;
          } catch (_) {}
        }

        final nearestAyah = _findNearestRenderedAyah(ayahIndex);
        if (nearestAyah != null) {
          final diff = ayahIndex - nearestAyah;
          estimatedOffset = _scrollController.offset + (diff * avgHeight);
        } else {
          estimatedOffset += 800.0;
        }
      }
    });
  }

  Future<void> _checkDownloadedState() async {
    if (kIsWeb) return;
    try {
      final reciterId = _selectedReciter != null ? _selectedReciter['id'].toString() : 'alafasy';
      final downloaded = await AudioDownloaderService.isDownloaded(reciterId, widget.surahId);

      String folder = 'Alafasy_128kbps';
      if (_selectedReciter != null && _selectedReciter['id_network'] != null) {
        final netId = _selectedReciter['id_network'].toString();
        final hasVerse = _selectedReciter['hasVerseAudio'] ?? true;
        if (hasVerse && !netId.startsWith('ar.')) {
          folder = netId.replaceAll('everyayah_', '');
        }
      }

      Set<int> ayahSet = {};
      if (_totalVersesInSurah > 0) {
        ayahSet = await AudioDownloaderService.getDownloadedAyahsForSurah(folder, widget.surahId, _totalVersesInSurah);
      }

      if (mounted) {
        setState(() {
          _isSurahDownloaded = downloaded || (_totalVersesInSurah > 0 && ayahSet.length >= _totalVersesInSurah);
          _downloadedAyahs = ayahSet;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRecitersData() async {
    try {
      final reciters = await DataService.loadReciters();
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('selectedReciterId') ?? 'alafasy';

      dynamic selected = reciters.firstWhere(
        (r) => r['id'] == savedId,
        orElse: () => reciters.first,
      );

      if (mounted) {
        setState(() {
          _recitersList = reciters;
          _selectedReciter = selected;
        });
        _checkDownloadedState();
      }
    } catch (_) {}
  }

  Future<void> _setReciter(dynamic reciter) async {
    final bool changed = _selectedReciter == null || _selectedReciter['id'] != reciter['id'];
    setState(() {
      _selectedReciter = reciter;
      if (changed && !_isPlayingAudio) {
        _reciterChangedWhilePaused = true;
      }
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedReciterId', reciter['id'].toString());
    } catch (_) {}
    _checkDownloadedState();
  }


  void _toggleAutoScroll() {
    setState(() {
      _isAutoScrolling = !_isAutoScrolling;
    });

    if (_isAutoScrolling) {
      _startAutoScroll();
    } else {
      _stopAutoScroll();
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    final intervalMs = (60 / _autoScrollSpeed).round();
    _autoScrollTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.offset;
        if (currentScroll < maxScroll) {
          _scrollController.jumpTo(currentScroll + 1.0);
        } else {
          _stopAutoScroll();
          if (mounted) setState(() {});
        }
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _isAutoScrolling = false;
  }

  Future<void> _saveLastRead(int surahId, String surahName, int ayahNum) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lastReadSurahId', surahId);
      await prefs.setString('lastReadSurahName', surahName);
      await prefs.setInt('lastReadAyahNum', ayahNum);
      await prefs.setString('lastReadDate', DateTime.now().toIso8601String());
    } catch (_) {}
  }

  Future<void> _playAyahAudio(int surahId, int ayahNum, {bool resetRepeatIndex = true}) async {
    final paddedSurah = surahId.toString().padLeft(3, '0');
    final paddedAyah = ayahNum.toString().padLeft(3, '0');

    String folder = 'Alafasy_128kbps';
    if (_selectedReciter != null && _selectedReciter['id_network'] != null) {
      final netId = _selectedReciter['id_network'].toString();
      final hasVerse = _selectedReciter['hasVerseAudio'] ?? true;
      if (hasVerse && !netId.startsWith('ar.')) {
        folder = netId.replaceAll('everyayah_', '');
      }
    }

    final audioUrl = 'https://everyayah.com/data/$folder/$paddedSurah$paddedAyah.mp3';
    final fallbackUrl = 'https://everyayah.com/data/Alafasy_128kbps/$paddedSurah$paddedAyah.mp3';

    try {
      if (_playingAyahId == ayahNum && _isPlayingAudio && !_isFullSurahMode && resetRepeatIndex) {
        await _audioPlayer.stop();
        if (!mounted) return;
        setState(() {
          _isPlayingAudio = false;
          _lastActiveAyahId = ayahNum;
          _playingAyahId = null;
          _currentRepeatIndex = 1;
        });
        return;
      }

      setState(() {
        _isFullSurahMode = false;
        _playingAyahId = ayahNum;
        _lastActiveAyahId = ayahNum;
        _isPlayingAudio = true;
        _currentAyahPosition = Duration.zero;
        _currentAyahDuration = Duration.zero;
        _reciterChangedWhilePaused = false;
        if (resetRepeatIndex) _currentRepeatIndex = 1;
      });

      _scrollToAyah(ayahNum);

      await _audioPlayer.stop();

      // 1. Check if the individual ayah audio is downloaded locally!
      bool playedOffline = false;
      if (!kIsWeb) {
        final isDownloaded = await AudioDownloaderService.isAyahDownloaded(folder, surahId, ayahNum);
        if (isDownloaded) {
          final localPath = await AudioDownloaderService.getLocalAyahPath(folder, surahId, ayahNum);
          try {
            await _audioPlayer.play(DeviceFileSource(localPath));
            playedOffline = true;
            if (mounted && !_downloadedAyahs.contains(ayahNum)) {
              setState(() => _downloadedAyahs.add(ayahNum));
            }
          } catch (err) {
            debugPrint('Offline ayah play failed: $err');
          }
        } else if (folder != 'Alafasy_128kbps') {
          // Check if default Alafasy reciter was downloaded for this ayah
          final isAlafasyDownloaded = await AudioDownloaderService.isAyahDownloaded('Alafasy_128kbps', surahId, ayahNum);
          if (isAlafasyDownloaded) {
            final localPath = await AudioDownloaderService.getLocalAyahPath('Alafasy_128kbps', surahId, ayahNum);
            try {
              await _audioPlayer.play(DeviceFileSource(localPath));
              playedOffline = true;
            } catch (err) {
              debugPrint('Offline alafasy ayah play failed: $err');
            }
          }
        }
      }

      // 2. If not downloaded offline, check connectivity or stream online
      if (!playedOffline) {
        if (!kIsWeb) {
          final hasNet = await AudioDownloaderService.hasInternetConnection();
          if (!hasNet) {
            final reciterId = _selectedReciter != null ? _selectedReciter['id'].toString() : 'alafasy';
            final isSurahDownloaded = await AudioDownloaderService.isDownloaded(reciterId, surahId);
            if (isSurahDownloaded) {
              final surahLocalPath = await AudioDownloaderService.getLocalPath(reciterId, surahId);
              if (!mounted) return;
              setState(() {
                _isFullSurahMode = true;
                _playingAyahId = ayahNum;
              });
              _scrollToAyah(ayahNum);
              await _audioPlayer.play(DeviceFileSource(surahLocalPath));
              final d = await _audioPlayer.getDuration();
              if (d != null && d > Duration.zero && mounted) {
                setState(() => _fullDuration = d);
                if (_totalVersesInSurah > 0 && ayahNum > 1) {
                  final seekFraction = (ayahNum - 1) / _totalVersesInSurah;
                  final seekMs = (d.inMilliseconds * seekFraction).round();
                  await _audioPlayer.seek(Duration(milliseconds: seekMs));
                }
              }
              if (mounted) {
                final lang = ref.read(settingsProvider).language;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 2),
                    content: Text(
                      lang == 'ar'
                          ? 'يتم تشغيل السورة الكاملة المحفوظة بدون إنترنت'
                          : (lang == 'en'
                              ? 'Playing downloaded full surah offline'
                              : 'دەنگی تەواوی سوورەتەکە بە ئۆفلاین لێدەدرێت'),
                      style: const TextStyle(fontFamily: 'Rabar'),
                    ),
                  ),
                );
              }
              return;
            }

            // Offline and neither ayah nor surah was downloaded
            if (mounted) {
              setState(() {
                _isPlayingAudio = false;
                _playingAyahId = null;
              });
              final lang = ref.read(settingsProvider).language;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFFEF4444),
                  content: Text(
                    lang == 'ar'
                        ? 'هذه الآية غير محملة للعمل بدون إنترنت. يرجى تفعيل الإنترنت أو تنزيلها أولاً.'
                        : (lang == 'en'
                            ? 'This ayah is not downloaded for offline listening. Please turn on internet or download it first.'
                            : 'ئەم ئایەتە داونلۆد نەکراوە بۆ کارکردنی ئۆفلاین. تکایە سەرەتا بە ئینتەرنێت داونلۆدی بکە.'),
                    style: const TextStyle(fontFamily: 'Rabar'),
                  ),
                ),
              );
            }
            return;
          }
        }

        try {
          await _audioPlayer.play(UrlSource(audioUrl));
        } catch (err) {
          debugPrint('Primary reciter audio failed ($audioUrl), trying fallback: $err');
          if (folder != 'Alafasy_128kbps') {
            await _audioPlayer.play(UrlSource(fallbackUrl));
          } else {
            // As a last resort before throwing error, check if full surah was downloaded offline
            if (!kIsWeb) {
              final reciterId = _selectedReciter != null ? _selectedReciter['id'].toString() : 'alafasy';
              final isSurahDownloaded = await AudioDownloaderService.isDownloaded(reciterId, surahId);
              if (isSurahDownloaded) {
                final surahLocalPath = await AudioDownloaderService.getLocalPath(reciterId, surahId);
                if (!mounted) return;
                setState(() => _isFullSurahMode = true);
                await _audioPlayer.play(DeviceFileSource(surahLocalPath));
                return;
              }
            }
            rethrow;
          }
        }
      }

      if (_playbackSpeed != 1.0) {
        try {
          await _audioPlayer.setPlaybackRate(_playbackSpeed);
        } catch (_) {}
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && _isPlayingAudio && _playbackSpeed != 1.0) {
            _audioPlayer.setPlaybackRate(_playbackSpeed);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
          _playingAyahId = null;
        });
        final lang = ref.read(settingsProvider).language;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang == 'ar'
                  ? 'تعذر تشغيل الصوت لهذه الآية. يرجى التحقق من اتصال الإنترنت.'
                  : (lang == 'en'
                      ? 'Could not play audio for this ayah. Please check your internet connection.'
                      : 'نەتوانرا فایلی دەنگی ئەم ئایەتە لێبدرێت. تکایە هێڵی ئینتەرنێت پشکنە'),
              style: const TextStyle(fontFamily: 'Rabar'),
            ),
          ),
        );
      }
    }
  }

  bool _isAudioLoading = false;

  Future<void> _playFullSurahAudio() async {
    // 1. Toggle pause/resume if currently playing
    if (_isPlayingAudio) {
      await _audioPlayer.pause();
      if (!mounted) return;
      setState(() => _isPlayingAudio = false);
      return;
    } else if (!_isPlayingAudio && _playingAyahId != null) {
      if (_audioPlayer.state == PlayerState.paused && !_reciterChangedWhilePaused) {
        await _audioPlayer.resume();
        if (!mounted) return;
        setState(() => _isPlayingAudio = true);
        _scrollToAyah(_playingAyahId!);
      } else {
        _reciterChangedWhilePaused = false;
        _playAyahAudio(widget.surahId, _playingAyahId!, resetRepeatIndex: false);
      }
      return;
    }

    // 2. Default to continuous Ayah-by-Ayah audio for reciters with verse audio
    // This supports offline downloaded ayahs, accurate per-ayah synchronization,
    // auto-scrolling with every ayah recited, repetition, and highlighting.
    final hasVerse = _selectedReciter != null ? (_selectedReciter['hasVerseAudio'] ?? true) : true;
    final netId = _selectedReciter != null ? (_selectedReciter['id_network'] ?? '').toString() : '';
    if (hasVerse && !netId.startsWith('ar.')) {
      final startAyah = _playingAyahId ?? _lastActiveAyahId;
      _playAyahAudio(widget.surahId, startAyah);
      return;
    }

    final reciterId = _selectedReciter != null ? _selectedReciter['id'].toString() : 'alafasy';

    // 3. Fallback for reciters without verse audio: Check OFFLINE local full surah file!
    if (!kIsWeb) {
      final isDownloaded = await AudioDownloaderService.isDownloaded(reciterId, widget.surahId);
      if (isDownloaded) {
        final localPath = await AudioDownloaderService.getLocalPath(reciterId, widget.surahId);
        if (!mounted) return;
        try {
          setState(() {
            _isFullSurahMode = true;
            _playingAyahId = 1;
            _isAudioLoading = false;
            _isPlayingAudio = true;
            _isSurahDownloaded = true;
          });
          _scrollToAyah(1);
          await _audioPlayer.stop();
          await _audioPlayer.play(DeviceFileSource(localPath));
          final d = await _audioPlayer.getDuration();
          if (d != null && d > Duration.zero && mounted) {
            setState(() => _fullDuration = d);
          }
          if (_playbackSpeed != 1.0) {
            try {
              await _audioPlayer.setPlaybackRate(_playbackSpeed);
            } catch (_) {}
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted && _isPlayingAudio && _playbackSpeed != 1.0) {
                _audioPlayer.setPlaybackRate(_playbackSpeed);
              }
            });
          }
          return;
        } catch (_) {}
      }
    }

    // 4. Fallback to Full Surah MP3 stream
    final paddedSurah = widget.surahId.toString().padLeft(3, '0');
    String server = _selectedReciter != null ? _selectedReciter['server_mp3'] ?? '' : '';
    if (server.endsWith('/')) {
      server = server.substring(0, server.length - 1);
    }
    if (server.isEmpty) {
      server = 'https://server8.mp3quran.net/afs';
    }

    setState(() {
      _isFullSurahMode = true;
      _playingAyahId = 1;
      _isAudioLoading = true;
      _isPlayingAudio = false;
    });

    // 2. Stream online if not downloaded locally
    String cleanServer = server;
    if (cleanServer.contains('/hazza')) {
      cleanServer = cleanServer.replaceAll('/hazza', '/hba');
    }

    final urlsToTry = [
      '$cleanServer/$paddedSurah.mp3',
      'https://server8.mp3quran.net/afs/$paddedSurah.mp3',
      'https://server11.mp3quran.net/sds/$paddedSurah.mp3',
    ];

    bool success = false;
    for (final url in urlsToTry) {
      try {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(url));
        if (_playbackSpeed != 1.0) {
          try {
            await _audioPlayer.setPlaybackRate(_playbackSpeed);
          } catch (_) {}
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted && _isPlayingAudio && _playbackSpeed != 1.0) {
              _audioPlayer.setPlaybackRate(_playbackSpeed);
            }
          });
        }
        if (mounted) {
          setState(() {
            _isPlayingAudio = true;
            _isAudioLoading = false;
          });
          _scrollToAyah(1);
        }
        success = true;
        break;
      } catch (e) {
        debugPrint('Audio mirror failed: $url - Error: $e');
      }
    }

    if (!success && mounted) {
      setState(() {
        _isPlayingAudio = false;
        _isAudioLoading = false;
      });
      final lang = ref.read(settingsProvider).language;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang == 'ar'
                ? 'الاتصال ضعيف أو تعذر تشغيل ملف الصوت. يرجى التحقق من اتصال الإنترنت.'
                : (lang == 'en'
                    ? 'Weak connection or failed to play audio. Please check your internet connection.'
                    : 'خەتەکە لاوازە یان نەتوانرا فایلی دەنگ لێبدرێت. تکایە هێڵی ئینتەرنێت پشکنە'),
            style: const TextStyle(fontFamily: 'Rabar'),
          ),
        ),
      );
    }
  }

  void _stepAudio(bool forward) {
    if (_playingAyahId != null) {
      final target = forward ? _playingAyahId! + 1 : _playingAyahId! - 1;
      if (target >= 1 && target <= _totalVersesInSurah) {
        _playAyahAudio(widget.surahId, target);
      }
    } else {
      _playAyahAudio(widget.surahId, forward ? 1 : _totalVersesInSurah);
    }
  }

  void _showJumpToAyahDialog() {
    final lang = ref.read(settingsProvider).language;
    final ctrl = TextEditingController();
    int jumpMode = 0; // 0 = Ayah, 1 = Page
    final startP = _startSurahPage ?? 1;
    final endP = _endSurahPage ?? startP;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isAyahMode = jumpMode == 0;
            final hintText = isAyahMode
                ? (lang == 'ar'
                    ? 'أدخل رقم الآية (١ - $_totalVersesInSurah)'
                    : (lang == 'en'
                        ? 'Enter Ayah number (1 - $_totalVersesInSurah)'
                        : 'ژمارەی ئایەت بنووسە (١ - $_totalVersesInSurah)'))
                : (lang == 'ar'
                    ? 'أدخل رقم الصفحة ($startP - $endP)'
                    : (lang == 'en'
                        ? 'Enter Page number ($startP - $endP)'
                        : 'ژمارەی لاپەڕە بنووسە ($startP - $endP)'));

            void executeJump() {
              final cleaned = _normalizeDigits(ctrl.text.trim());
              final val = int.tryParse(cleaned);
              if (isAyahMode) {
                if (val != null && val >= 1 && val <= _totalVersesInSurah) {
                  Navigator.pop(context);
                  _scrollToAyah(val);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        lang == 'ar'
                            ? 'يرجى إدخال رقم بين ١ و $_totalVersesInSurah'
                            : (lang == 'en'
                                ? 'Please enter a number between 1 and $_totalVersesInSurah'
                                : 'تکایە ژمارەیەک لە نێوان ١ تا $_totalVersesInSurah بنووسە'),
                        style: const TextStyle(fontFamily: 'Rabar'),
                      ),
                    ),
                  );
                }
              } else {
                // Page mode
                if (val != null && val >= startP && val <= endP && _cachedVerses != null) {
                  int? foundAyah;
                  for (final v in _cachedVerses!) {
                    if ((v['page'] as int?) == val) {
                      foundAyah = v['id'] as int?;
                      break;
                    }
                  }
                  if (foundAyah != null) {
                    Navigator.pop(context);
                    _scrollToAyah(foundAyah);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        lang == 'ar'
                            ? 'يرجى إدخال رقم صفحة بين $startP و $endP'
                            : (lang == 'en'
                                ? 'Please enter a page between $startP and $endP'
                                : 'تکایە لاپەڕەیەک لە نێوان $startP تا $endP بنووسە'),
                        style: const TextStyle(fontFamily: 'Rabar'),
                      ),
                    ),
                  );
                }
              }
            }

            return AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    lang == 'ar' ? 'الانتقال السريع' : (lang == 'en' ? 'Quick Navigation' : 'چوون بۆ دیاریکراو'),
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar', fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => jumpMode = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: isAyahMode ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  lang == 'ar' ? 'آية' : (lang == 'en' ? 'Ayah' : 'ئایەت'),
                                  style: TextStyle(
                                    color: isAyahMode ? Colors.black : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Rabar',
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => jumpMode = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: !isAyahMode ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  lang == 'ar' ? 'صفحة' : (lang == 'en' ? 'Page' : 'لاپەڕە'),
                                  style: TextStyle(
                                    color: !isAyahMode ? Colors.black : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Rabar',
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
              content: TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontFamily: 'Rabar'),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontFamily: 'Rabar', fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.04),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onSubmitted: (_) => executeJump(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    lang == 'ar' ? 'إلغاء' : (lang == 'en' ? 'Cancel' : 'پاشگەزبوونەوە'),
                    style: const TextStyle(color: Colors.white54, fontFamily: 'Rabar'),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                  onPressed: executeJump,
                  child: Text(
                    lang == 'ar' ? 'ذهاب' : (lang == 'en' ? 'Go' : 'بچۆ'),
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _downloadSurahAudio() async {
    final lang = ref.read(settingsProvider).language;
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang == 'ar'
                ? 'تنزيل الصوت بدون إنترنت متاح على الهاتف (Android / iOS)'
                : (lang == 'en'
                    ? 'Offline audio download is supported on mobile (Android / iOS).'
                    : 'داونلۆدکردنی فایلی ئۆفلاین لەسەر مۆبایل (Android / iOS) دەستەبەرە'),
            style: const TextStyle(fontFamily: 'Rabar'),
          ),
        ),
      );
      return;
    }

    if (!kIsWeb) {
      final hasNet = await AudioDownloaderService.hasInternetConnection();
      if (!hasNet) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFEF4444),
              content: Text(
                lang == 'ar'
                    ? 'لا يوجد اتصال بالإنترنت! يرجى تفعيل الإنترنت لتنزيل الصوت.'
                    : (lang == 'en'
                        ? 'No internet connection! Please turn on internet to download audio.'
                        : 'هێڵی ئینتەرنێت کوژاوەتەوە! بۆ داونلۆدکردنی دەنگ تکایە سەرەتا ئینتەرنێت دابگیرسێنە.'),
                style: const TextStyle(fontFamily: 'Rabar'),
              ),
            ),
          );
        }
        return;
      }
    }

    final reciterId = _selectedReciter != null ? _selectedReciter['id'].toString() : 'alafasy';
    final paddedSurah = widget.surahId.toString().padLeft(3, '0');
    String server = _selectedReciter != null ? _selectedReciter['server_mp3'] ?? '' : '';
    if (server.endsWith('/')) server = server.substring(0, server.length - 1);
    if (server.contains('/hazza')) server = server.replaceAll('/hazza', '/hba');
    if (server.isEmpty) server = 'https://server8.mp3quran.net/afs';

    final remoteUrl = '$server/$paddedSurah.mp3';

    setState(() {
      _isDownloadingAudio = true;
      _downloadProgress = 0.0;
    });

    String folder = 'Alafasy_128kbps';
    if (_selectedReciter != null && _selectedReciter['id_network'] != null) {
      final netId = _selectedReciter['id_network'].toString();
      final hasVerse = _selectedReciter['hasVerseAudio'] ?? true;
      if (hasVerse && !netId.startsWith('ar.')) {
        folder = netId.replaceAll('everyayah_', '');
      }
    }

    // 1. Download full surah MP3 (accounts for 50% of progress)
    final path = await AudioDownloaderService.downloadAudio(
      reciterId,
      widget.surahId,
      remoteUrl,
      (progress) {
        if (mounted) setState(() => _downloadProgress = progress * 0.5);
      },
    );

    // 2. Download all Ayah files of this surah (accounts for remaining 50%)
    if (_totalVersesInSurah > 0) {
      await AudioDownloaderService.downloadAllAyahsOfSurah(
        folder,
        widget.surahId,
        _totalVersesInSurah,
        (progress, currentDownloaded, total) {
          if (mounted) {
            setState(() {
              _downloadProgress = 0.5 + (progress * 0.5);
            });
          }
        },
        onAyahSuccess: (ayahNum) {
          if (mounted) {
            setState(() {
              _downloadedAyahs.add(ayahNum);
            });
          }
        },
      );
    }

    final actualDownloadedAyahs = await AudioDownloaderService.getDownloadedAyahsForSurah(
      folder,
      widget.surahId,
      _totalVersesInSurah,
    );
    final isFullSurahDownloaded = (path != null) || (actualDownloadedAyahs.length >= _totalVersesInSurah && _totalVersesInSurah > 0);

    if (mounted) {
      setState(() {
        _isDownloadingAudio = false;
        _isSurahDownloaded = isFullSurahDownloaded;
        _downloadedAyahs = actualDownloadedAyahs;
      });

      if (isFullSurahDownloaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              lang == 'ar'
                  ? 'تم تنزيل السورة وجميع الآيات بنجاح للاستماع بدون إنترنت!'
                  : (lang == 'en'
                      ? 'Surah and all Ayahs downloaded successfully for offline listening!'
                      : 'سوورەت و سەرجەم ئایەتەکان بە سەرکەوتوویی داونلۆد کران بۆ کارکردنی ئۆفلاین!'),
              style: const TextStyle(fontFamily: 'Rabar'),
            ),
          ),
        );
      } else if (actualDownloadedAyahs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFF59E0B),
            content: Text(
              lang == 'ar'
                  ? 'تم تنزيل ${actualDownloadedAyahs.length} من أصل $_totalVersesInSurah آية. انقطع الاتصال.'
                  : (lang == 'en'
                      ? 'Downloaded ${actualDownloadedAyahs.length} of $_totalVersesInSurah ayahs. Connection interrupted.'
                      : '${actualDownloadedAyahs.length} لە $_totalVersesInSurah ئایەت داونلۆد کران. هێڵی ئینتەرنێت پچڕا.'),
              style: const TextStyle(fontFamily: 'Rabar'),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text(
              lang == 'ar'
                  ? 'فشل التنزيل. يرجى التحقق من اتصال الإنترنت.'
                  : (lang == 'en'
                      ? 'Download failed. Please check your internet connection.'
                      : 'داونلۆدکردن سەرکەوتوو نەبوو لەبەر نەبوونی هێڵی ئینتەرنێت.'),
              style: const TextStyle(fontFamily: 'Rabar'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _downloadSingleAyah(int ayahNum) async {
    final lang = ref.read(settingsProvider).language;
    if (kIsWeb) return;

    if (!kIsWeb) {
      final hasNet = await AudioDownloaderService.hasInternetConnection();
      if (!hasNet) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFEF4444),
              content: Text(
                lang == 'ar'
                    ? 'لا يوجد اتصال بالإنترنت لتنزيل هذه الآية.'
                    : (lang == 'en'
                        ? 'No internet connection to download this Ayah.'
                        : 'هێڵی ئینتەرنێت کوژاوەتەوە بۆ داونلۆدکردنی ئەم ئایەتە.'),
                style: const TextStyle(fontFamily: 'Rabar'),
              ),
            ),
          );
        }
        return;
      }
    }

    String folder = 'Alafasy_128kbps';
    if (_selectedReciter != null && _selectedReciter['id_network'] != null) {
      final netId = _selectedReciter['id_network'].toString();
      final hasVerse = _selectedReciter['hasVerseAudio'] ?? true;
      if (hasVerse && !netId.startsWith('ar.')) {
        folder = netId.replaceAll('everyayah_', '');
      }
    }

    setState(() => _downloadingAyahNum = ayahNum);

    final path = await AudioDownloaderService.downloadAyahAudio(folder, widget.surahId, ayahNum);
    final actuallyDownloaded = path != null && await AudioDownloaderService.isAyahDownloaded(folder, widget.surahId, ayahNum);

    if (mounted) {
      setState(() {
        _downloadingAyahNum = null;
        if (actuallyDownloaded) {
          _downloadedAyahs.add(ayahNum);
        }
      });

      if (actuallyDownloaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(milliseconds: 1500),
            content: Text(
              lang == 'ar'
                  ? 'تم تنزيل الآية $ayahNum للاستماع بدون إنترنت!'
                  : (lang == 'en'
                      ? 'Ayah $ayahNum downloaded for offline listening!'
                      : 'ئایەتی $ayahNum داونلۆد کرا بۆ کارکردنی ئۆفلاین!'),
              style: const TextStyle(fontFamily: 'Rabar'),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text(
              lang == 'ar'
                  ? 'فشل تنزيل الآية. يرجى التحقق من اتصال الإنترنت.'
                  : (lang == 'en'
                      ? 'Failed to download Ayah. Please check internet connection.'
                      : 'داونلۆدکردنی ئایەتەکە سەرکەوتوو نەبوو. هێڵی ئینتەرنێت پشکنە.'),
              style: const TextStyle(fontFamily: 'Rabar'),
            ),
          ),
        );
      }
    }
  }

  void _showReciterPickerSheet() {
    _reciterSearchQuery = '';
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final lang = ref.read(settingsProvider).language;
            final filtered = _recitersList.where((r) {
              if (_reciterSearchQuery.isEmpty) return true;
              final q = _reciterSearchQuery.toLowerCase();
              final ku = (r['name_ku'] ?? '').toString().toLowerCase();
              final ar = (r['name_ar'] ?? '').toString().toLowerCase();
              final en = (r['name_en'] ?? '').toString().toLowerCase();
              return ku.contains(q) || ar.contains(q) || en.contains(q);
            }).toList();

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    lang == 'ar'
                        ? 'اختيار القارئ (${_recitersList.length} قارئ)'
                        : (lang == 'en'
                            ? 'Select Reciter (${_recitersList.length} Reciters)'
                            : 'هەڵبژاردنی قورئانخوێن (${_recitersList.length} قورئانخوێن)'),
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 14),

                  // Search Bar inside reciter sheet
                  TextField(
                    controller: searchCtrl,
                    onChanged: (val) {
                      setModalState(() => _reciterSearchQuery = val.trim());
                    },
                    style: TextStyle(color: Colors.white, fontFamily: 'Rabar'),
                    decoration: InputDecoration(
                      hintText: lang == 'ar'
                          ? 'البحث عن قارئ...'
                          : (lang == 'en'
                              ? 'Search reciter...'
                              : 'گەڕان بەدوای ناوی قورئانخوێن...'),
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontFamily: 'Rabar'),
                      prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  SizedBox(height: 14),

                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, idx) {
                        final r = filtered[idx];
                        final isSelected = _selectedReciter != null && _selectedReciter['id'] == r['id'];
                        final displayName = lang == 'en'
                            ? (r['name_en'] ?? r['name_ku'] ?? '')
                            : (lang == 'ar' ? (r['name_ar'] ?? r['name_ku'] ?? '') : (r['name_ku'] ?? ''));
                        final subTitleText = lang == 'ar' ? (r['name_en'] ?? '') : (r['name_ar'] ?? '');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white.withOpacity(0.04),
                            ),
                          ),
                          child: Material(
                            color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              leading: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: (isSelected ? Theme.of(context).colorScheme.primary : Colors.white).withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.record_voice_over_rounded,
                                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white70,
                                  size: 19,
                                ),
                              ),
                              title: Text(
                                displayName,
                                style: TextStyle(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                              ),
                              subtitle: subTitleText.isNotEmpty
                                  ? Text(
                                      subTitleText,
                                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontFamily: 'Traditional Arabic'),
                                    )
                                  : null,
                              trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
                              onTap: () async {
                                final oldReciterId = _selectedReciter != null ? _selectedReciter['id'] : null;
                                final isDifferent = oldReciterId != r['id'];
                                await _setReciter(r);
                                if (!mounted) return;
                                Navigator.pop(context);

                                if (isDifferent) {
                                  final lang = ref.read(settingsProvider).language;
                                  final rName = lang == 'ku'
                                      ? (r['name_ku'] ?? r['name_ar'] ?? '')
                                      : (lang == 'ar'
                                          ? (r['name_ar'] ?? r['name_ku'] ?? '')
                                          : (r['name_en'] ?? r['name_ar'] ?? ''));

                                  if (_isPlayingAudio) {
                                    if (_isFullSurahMode) {
                                      // If full surah was playing, switch to ayah mode from current ayah with new reciter
                                      final targetAyah = _playingAyahId ?? _lastActiveAyahId;
                                      _isFullSurahMode = false;
                                      await _audioPlayer.stop();
                                      _playAyahAudio(widget.surahId, targetAyah);
                                    } else {
                                      // Continuous recitation: keep current ayah playing to the end,
                                      // and onPlayerComplete will automatically play the next ayah with the new reciter!
                                      final nextAyahNum = (_playingAyahId ?? 0) + 1;
                                      final nextInfo = (nextAyahNum <= _totalVersesInSurah && nextAyahNum > 1)
                                          ? (lang == 'ku'
                                              ? 'لە ئایەتی داهاتووەوە ($nextAyahNum)'
                                              : (lang == 'ar' ? 'بدءاً من الآية التالية ($nextAyahNum)' : 'from next verse ($nextAyahNum)'))
                                          : '';
                                      final snackText = lang == 'ku'
                                          ? 'دەنگی $rName $nextInfo بەردەوام دەبێت'
                                          : (lang == 'ar'
                                              ? 'سيبدأ صوت $rName $nextInfo'
                                              : 'Recitation by $rName will continue $nextInfo');

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.record_voice_over, color: Colors.greenAccent, size: 20),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  snackText,
                                                  style: const TextStyle(fontFamily: 'Rabar'),
                                                ),
                                              ),
                                            ],
                                          ),
                                          duration: const Duration(seconds: 3),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } else {
                                    // Not currently playing: if paused, stop player so next Play starts clean with new reciter
                                    if (_audioPlayer.state == PlayerState.paused) {
                                      await _audioPlayer.stop();
                                    }
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDisplaySettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final lang = ref.read(settingsProvider).language;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      lang == 'ar'
                          ? 'إعدادات النص والخط ووضع القراءة'
                          : (lang == 'en'
                              ? 'Text, Font & Display Settings'
                              : 'ڕێکخستنی دەق و فۆنت و دۆخی خوێندنەوە'),
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                    ),
                    SizedBox(height: 14),

                    // Live Preview Card
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.35)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                            style: _getQuranTextStyle(context, ref.read(settingsProvider), false),
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                          ),
                          if (_showTranslation) ...[
                            const SizedBox(height: 8),
                            Text(
                              lang == 'en'
                                  ? 'In the name of Allah, the Entirely Merciful, the Especially Merciful.'
                                  : 'بەناوی خوای بەخشندەی میهرەبان',
                              style: TextStyle(
                                fontSize: ref.read(settingsProvider).quranTranslationFontSize,
                                color: Colors.white.withOpacity(0.7),
                                fontFamily: 'Rabar',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // Quran Font Style Selector
                    Text(
                      lang == 'ar' ? 'نوع الخط العربي' : (lang == 'en' ? 'Arabic Font Style' : 'جۆری خەتی عەرەبی'),
                      style: TextStyle(color: Colors.white70, fontFamily: 'Rabar', fontSize: 13),
                    ),
                    SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          {'id': 'Traditional Arabic', 'name': 'خەتی ئاسایی'},
                          {'id': 'Amiri', 'name': 'ئەمیری (Amiri)'},
                          {'id': 'Scheherazade New', 'name': 'شەهرەزاد'},
                          {'id': 'Lateef', 'name': 'لەتیف (Lateef)'},
                        ].map((font) {
                          final curFont = ref.read(settingsProvider).quranFontFamily;
                          final isSel = curFont == font['id'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(
                                font['name']!,
                                style: TextStyle(
                                  color: isSel ? Colors.black : Colors.white,
                                  fontFamily: 'Rabar',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              selected: isSel,
                              selectedColor: Theme.of(context).colorScheme.primary,
                              backgroundColor: Colors.white.withOpacity(0.05),
                              onSelected: (val) {
                                ref.read(settingsProvider.notifier).setQuranFontFamily(font['id']!);
                                setState(() {});
                                setModalState(() {});
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Reading theme colors
                    Text(
                      lang == 'ar'
                          ? 'لون خلفية القراءة (حماية العين)'
                          : (lang == 'en'
                              ? 'Reading Background Theme (Eye Protection)'
                              : 'ڕەنگی پاشبنەمای خوێندنەوە (Eye Protection)'),
                      style: TextStyle(color: Colors.white70, fontFamily: 'Rabar', fontSize: 13),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildColorChip('dark', lang == 'ar' ? 'أسود' : (lang == 'en' ? 'Dark' : 'ڕەش'), Theme.of(context).scaffoldBackgroundColor, setModalState),
                        _buildColorChip('sepia', lang == 'ar' ? 'سيبيا' : (lang == 'en' ? 'Sepia' : 'سێپیا (زەردباو)'), const Color(0xFF1C160E), setModalState),
                        _buildColorChip('black', lang == 'ar' ? 'داكن جداً' : (lang == 'en' ? 'Midnight' : 'تاریکی بەرز'), Colors.black, setModalState),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Arabic font size slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          lang == 'ar' ? 'حجم النص العربي' : (lang == 'en' ? 'Arabic Font Size' : 'قەبارەی دەقی عەرەبی'),
                          style: TextStyle(color: Colors.white70, fontFamily: 'Rabar'),
                        ),
                        Text('${ref.read(settingsProvider).quranArabicFontSize.toInt()} px', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar')),
                      ],
                    ),
                    Slider(
                      value: ref.read(settingsProvider).quranArabicFontSize.clamp(18.0, 42.0),
                      min: 18,
                      max: 42,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (val) {
                        ref.read(settingsProvider.notifier).setQuranArabicFontSize(val);
                        setState(() {});
                        setModalState(() {});
                      },
                    ),
                    SizedBox(height: 12),

                    // Translation font size slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          lang == 'ar' ? 'حجم نص الترجمة' : (lang == 'en' ? 'Translation Font Size' : 'قەبارەی دەقی وەرگێڕان'),
                          style: TextStyle(color: Colors.white70, fontFamily: 'Rabar'),
                        ),
                        Text('${ref.read(settingsProvider).quranTranslationFontSize.toInt()} px', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar')),
                      ],
                    ),
                    Slider(
                      value: ref.read(settingsProvider).quranTranslationFontSize.clamp(12.0, 26.0),
                      min: 12,
                      max: 26,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (val) {
                        ref.read(settingsProvider.notifier).setQuranTranslationFontSize(val);
                        setState(() {});
                        setModalState(() {});
                      },
                    ),
                    SizedBox(height: 12),

                    // Playback speed selector
                    Text(
                      lang == 'ar' ? 'سرعة التلاوة (Speed)' : (lang == 'en' ? 'Audio Playback Speed' : 'خێرایی دەنگی خوێندنەوە (Speed)'),
                      style: TextStyle(color: Colors.white70, fontFamily: 'Rabar', fontSize: 13),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [1.0, 1.25, 1.5, 2.0].map((speed) {
                        final isSel = _playbackSpeed == speed;
                        return ChoiceChip(
                          label: Text('${speed}x', style: TextStyle(color: isSel ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                          selected: isSel,
                          selectedColor: Theme.of(context).colorScheme.primary,
                          backgroundColor: Colors.white.withOpacity(0.05),
                          onSelected: (val) async {
                            setState(() => _playbackSpeed = speed);
                            try {
                              await _audioPlayer.setPlaybackRate(speed);
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setDouble('quranPlaybackSpeed', speed);
                            } catch (_) {}
                            setModalState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16),

                    // Show translation toggle
                    SwitchListTile(
                      title: Text(
                        lang == 'ar' ? 'إظهار الترجمة والتفسير' : (lang == 'en' ? 'Show Translation & Tafsir' : 'پیشاندانی وەرگێڕانی کوردی'),
                        style: TextStyle(color: Colors.white, fontFamily: 'Rabar'),
                      ),
                      value: _showTranslation,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (val) {
                        setState(() => _showTranslation = val);
                        setModalState(() {});
                      },
                    ),
                    SizedBox(height: 12),

                    // Hifz Repeat Mode (1x, 3x, 5x, 10x)
                    Text(
                      lang == 'ar' ? 'تكرار الآية للحفظ (وضع الحفظ)' : (lang == 'en' ? 'Verse Repeat Count (Hifz Mode)' : 'ژمارەی دووبارەبوونەوە بۆ لەبەرکردن (Hifz Mode)'),
                      style: TextStyle(color: Colors.white70, fontFamily: 'Rabar', fontSize: 13),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [1, 3, 5, 10].map((count) {
                        final isSel = _hifzRepeatCount == count;
                        return ChoiceChip(
                          label: Text('${count}x', style: TextStyle(color: isSel ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                          selected: isSel,
                          selectedColor: Theme.of(context).colorScheme.primary,
                          backgroundColor: Colors.white.withOpacity(0.05),
                          onSelected: (val) {
                            setState(() => _hifzRepeatCount = count);
                            setModalState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  TextStyle _getQuranTextStyle(BuildContext context, SettingsState settings, bool isPlaying) {
    final fontSize = settings.quranArabicFontSize;
    final color = isPlaying ? Theme.of(context).colorScheme.primary : Colors.white;
    switch (settings.quranFontFamily) {
      case 'Amiri':
        return GoogleFonts.amiri(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          height: 2.0,
          color: color,
        );
      case 'Scheherazade New':
        return GoogleFonts.scheherazadeNew(
          fontSize: fontSize + 2,
          fontWeight: FontWeight.bold,
          height: 2.0,
          color: color,
        );
      case 'Lateef':
        return GoogleFonts.lateef(
          fontSize: fontSize + 4,
          fontWeight: FontWeight.bold,
          height: 2.0,
          color: color,
        );
      case 'Traditional Arabic':
      default:
        return TextStyle(
          fontFamily: 'Traditional Arabic',
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          height: 2.0,
          color: color,
        );
    }
  }

  Widget _buildColorChip(String mode, String label, Color color, StateSetter setModalState) {
    final isSelected = _readingColorTheme == mode;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 12, fontFamily: 'Rabar')),
      selected: isSelected,
      selectedColor: Theme.of(context).colorScheme.primary,
      backgroundColor: color,
      onSelected: (val) {
        setState(() => _readingColorTheme = mode);
        setModalState(() {});
      },
    );
  }

  void _showTafsirModal(int verseNum, String arabicText, String translation) {
    final lang = ref.read(settingsProvider).language;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final tafsirHeader = lang == 'ar'
            ? 'تفسير وتدبر الآية $verseNum'
            : (lang == 'en'
                ? 'Tafsir & Reflection • Ayah $verseNum'
                : 'تەفسیری ڕێبەری کوردی • ئایەتی $verseNum');
        final tafsirContent = lang == 'ar'
            ? 'تفسير وتدبر الآية $verseNum:\n\nهذه الآية الكريمة تتضمن إرشادات ومواعظ قيّمة للمؤمنين في امتثال أوامر الله سبحانه وتعالى واجتناب نواهيه والتدبر في آياته.'
            : (lang == 'en'
                ? 'Meaning & Tafsir of Ayah $verseNum:\n\n$translation\n\nThis noble verse carries profound guidance and wisdom for believers to adhere to the commandments of Allah Almighty and reflect upon His divine wisdom.'
                : 'تەفسیری کوردی ئایەتی $verseNum:\n\n$translation\n\nئەم ئایەتە پیرۆزە ڕوونکردنەوەی بەهادار و پەند و ئامۆژگاری بۆ ئیمانداران لەخۆدەگرێت لەسەر بەدیهێنانی فەرمانەکانی خودای گەورە و بەدووربوون لە قەدەغەکراوەکان.');

        return Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tafsirHeader,
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
              ),
              const SizedBox(height: 12),
              Text(
                arabicText,
                style: GoogleFonts.amiri(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
              ),
              const Divider(color: Colors.white10, height: 24),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    tafsirContent,
                    style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.8, fontFamily: 'Rabar'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getBgColor() {
    if (_readingColorTheme == 'sepia') return const Color(0xFF1C160E);
    if (_readingColorTheme == 'black') return Colors.black;
    return Theme.of(context).scaffoldBackgroundColor;
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showJuzPickerModal(BuildContext context) {
    final lang = ref.read(settingsProvider).language;
    final availableJuzs = <int, int>{}; // juzNum -> firstAyahId
    if (_cachedVerses != null) {
      for (final v in _cachedVerses!) {
        final j = (v['juz'] as int?) ?? 1;
        final ayahId = (v['id'] as int?) ?? 1;
        availableJuzs.putIfAbsent(j, () => ayahId);
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F261D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  lang == 'ku'
                      ? 'پارەکانی ئەم سوورەتە'
                      : (lang == 'ar' ? 'أجزاء هذه السورة' : 'Juzs in this Surah'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Rabar',
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: availableJuzs.entries.map((e) {
                    final isCurrent = e.key == _currentVisibleJuz;
                    return ActionChip(
                      backgroundColor: isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : const Color(0xFF183B2F),
                      side: BorderSide(
                        color: isCurrent ? Colors.white : Colors.white24,
                        width: 1,
                      ),
                      label: Text(
                        lang == 'ku'
                            ? 'پارەی ${e.key} (ئایەتی ${e.value})'
                            : (lang == 'ar'
                                ? 'الجزء ${e.key} (الآية ${e.value})'
                                : 'Juz ${e.key} (Ayah ${e.value})'),
                        style: TextStyle(
                          color: isCurrent ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Rabar',
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _scrollToAyah(e.value);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSurahInfoModal(BuildContext context) {
    final lang = ref.read(settingsProvider).language;
    final startP = _startSurahPage ?? 1;
    final endP = _endSurahPage ?? startP;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F261D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.surahNameAr,
                  style: GoogleFonts.amiri(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  lang == 'en' ? widget.surahNameEn : widget.surahNameKu,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontFamily: 'Rabar',
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            lang == 'ku' ? 'ئایەتەکان' : (lang == 'ar' ? 'الآيات' : 'Verses'),
                            style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'Rabar'),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_totalVersesInSurah',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 28, color: Colors.white12),
                      Column(
                        children: [
                          Text(
                            lang == 'ku' ? 'لاپەڕەکان' : (lang == 'ar' ? 'الصفحات' : 'Pages'),
                            style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'Rabar'),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            startP == endP ? '$startP' : '$startP - $endP',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 28, color: Colors.white12),
                      Column(
                        children: [
                          Text(
                            lang == 'ku' ? 'پاره' : (lang == 'ar' ? 'الجزء' : 'Juz'),
                            style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'Rabar'),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_currentVisibleJuz',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.format_line_spacing),
                    label: Text(
                      lang == 'ar' ? 'الانتقال إلى آية أو صفحة' : (lang == 'en' ? 'Jump to Ayah or Page' : 'چوون بۆ ئایەت یان لاپەڕە'),
                      style: const TextStyle(fontFamily: 'Rabar', fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showJumpToAyahDialog();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isRTL = settings.language == 'ku' || settings.language == 'ar';
    final lang = settings.language;
    final title = widget.surahNameAr;
    final reciterName = _selectedReciter != null
        ? (lang == 'en'
            ? (_selectedReciter['name_en'] ?? _selectedReciter['name_ku'] ?? '')
            : (lang == 'ar'
                ? (_selectedReciter['name_ar'] ?? _selectedReciter['name_ku'] ?? '')
                : (_selectedReciter['name_ku'] ?? _selectedReciter['name_ar'] ?? '')))
        : (lang == 'en' ? 'Mishary Alafasy' : 'مشاري العفاسي');

    final String autoScrollTooltip = lang == 'ar' ? 'التمرير التلقائي' : (lang == 'en' ? 'Auto Scroll' : 'سووڕانی ئۆتۆماتیکی');

    return Scaffold(
      backgroundColor: _getBgColor(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF18382B),
          ),
          child: CustomPaint(
            painter: QuranAppBarBackgroundPainter(
              baseColor: const Color(0xFF18382B),
              domeColor: const Color(0xFF224A3A),
            ),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    children: [
                      // Back button
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: lang == 'ku' ? 'گەڕانەوە' : (lang == 'ar' ? 'رجوع' : 'Back'),
                      ),
                      // Left Pill: Juz
                      GestureDetector(
                        onTap: () => _showJuzPickerModal(context),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 105),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1E18).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.12)),
                          ),
                          child: Text(
                            lang == 'ku'
                                ? 'پارەی $_currentVisibleJuz'
                                : (lang == 'ar' ? 'الجزء $_currentVisibleJuz' : 'Juz $_currentVisibleJuz'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Rabar',
                            ),
                          ),
                        ),
                      ),
                      // Center: Prominent Current Mushaf Page Number
                      Expanded(
                        child: GestureDetector(
                          onTap: _showJumpToAyahDialog,
                          child: Center(
                            child: Text(
                              '$_currentVisiblePage',
                              style: GoogleFonts.amiri(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Right Pill: Surah Name
                      GestureDetector(
                        onTap: () => _showSurahInfoModal(context),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 105),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1E18).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.12)),
                          ),
                          child: Text(
                            lang == 'en'
                                ? widget.surahNameEn
                                : (lang == 'ar' ? widget.surahNameAr : widget.surahNameKu),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              fontFamily: lang == 'en' ? null : 'Rabar',
                            ),
                          ),
                        ),
                      ),
                      // More Options Menu
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white70, size: 22),
                        color: const Color(0xFF0F261D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                        ),
                        onSelected: (value) {
                          switch (value) {
                            case 'jump':
                              _showJumpToAyahDialog();
                              break;
                            case 'reciter':
                              _showReciterPickerSheet();
                              break;
                            case 'autoscroll':
                              _toggleAutoScroll();
                              break;
                            case 'translation':
                              setState(() => _showTranslation = !_showTranslation);
                              break;
                            case 'settings':
                              _showDisplaySettingsSheet();
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'jump',
                            child: Row(
                              children: [
                                Icon(Icons.format_line_spacing, color: Theme.of(context).colorScheme.primary, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  lang == 'ar' ? 'الانتقال إلى آية / صفحة' : (lang == 'en' ? 'Jump to Ayah / Page' : 'چوون بۆ ئایەت / لاپەڕە'),
                                  style: const TextStyle(color: Colors.white, fontFamily: 'Rabar'),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'reciter',
                            child: Row(
                              children: [
                                Icon(Icons.record_voice_over, color: Theme.of(context).colorScheme.primary, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  lang == 'ar' ? 'تغيير القارئ' : (lang == 'en' ? 'Change Reciter' : 'گۆڕینی دەنگی قورئانخوێن'),
                                  style: const TextStyle(color: Colors.white, fontFamily: 'Rabar'),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'autoscroll',
                            child: Row(
                              children: [
                                Icon(
                                  _isAutoScrolling ? Icons.pause_circle_filled : Icons.slow_motion_video,
                                  color: _isAutoScrolling ? const Color(0xFF10B981) : Theme.of(context).colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  autoScrollTooltip,
                                  style: const TextStyle(color: Colors.white, fontFamily: 'Rabar'),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'translation',
                            child: Row(
                              children: [
                                Icon(
                                  _showTranslation ? Icons.menu_book : Icons.menu_book_outlined,
                                  color: _showTranslation ? Theme.of(context).colorScheme.primary : Colors.white54,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _showTranslation
                                      ? (lang == 'ar' ? 'إخفاء الترجمة' : (lang == 'en' ? 'Hide Translation' : 'شاردنەوەی تەفسیر'))
                                      : (lang == 'ar' ? 'إظهار الترجمة' : (lang == 'en' ? 'Show Translation' : 'پیشاندانی تەفسیر')),
                                  style: const TextStyle(color: Colors.white, fontFamily: 'Rabar'),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'settings',
                            child: Row(
                              children: [
                                const Icon(Icons.text_format, color: Colors.white70, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  lang == 'ar' ? 'إعدادات الخط' : (lang == 'en' ? 'Font Settings' : 'ڕێکخستنی فۆنت'),
                                  style: const TextStyle(color: Colors.white, fontFamily: 'Rabar'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

      // ━━━ QURAN MAJEED PRO FLOATING BOTTOM PLAYER BAR ━━━
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Theme.of(context).cardColor, Theme.of(context).scaffoldBackgroundColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 16,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Previous Ayah button
                  IconButton(
                    icon: Icon(Icons.skip_previous, color: Theme.of(context).colorScheme.primary),
                    onPressed: () => _stepAudio(false),
                  ),

                  // Play / Pause Main Controller Button
                  GestureDetector(
                    onTap: _playFullSurahAudio,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: Center(
                        child: _isAudioLoading
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                              )
                            : Icon(
                                _isPlayingAudio ? Icons.pause : Icons.play_arrow,
                                color: Colors.black,
                                size: 30,
                              ),
                      ),
                    ),
                  ),

                  // Next Ayah button
                  IconButton(
                    icon: Icon(Icons.skip_next, color: Theme.of(context).colorScheme.primary),
                    onPressed: () => _stepAudio(true),
                  ),

                  SizedBox(width: 8),

                  Expanded(
                    child: InkWell(
                      onTap: _showReciterPickerSheet,
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang == 'en'
                                ? 'Listen to full ${widget.surahNameEn}'
                                : (lang == 'ar'
                                    ? 'الاستماع لسورة ${widget.surahNameAr}'
                                    : 'گوێگرتن لە تەواوی ${widget.surahNameKu}'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Rabar'),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Row(
                            children: [
                              Icon(Icons.record_voice_over_rounded, color: Theme.of(context).colorScheme.primary.withOpacity(0.9), size: 13),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  reciterName,
                                  style: TextStyle(color: Theme.of(context).colorScheme.primary.withOpacity(0.9), fontSize: 11, fontFamily: 'Rabar', fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.keyboard_arrow_down, color: Theme.of(context).colorScheme.primary, size: 16),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Download Offline Button
                  IconButton(
                    icon: _isDownloadingAudio
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              value: _downloadProgress > 0 ? _downloadProgress : null,
                              color: Theme.of(context).colorScheme.primary,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            _isSurahDownloaded ? Icons.check_circle : Icons.download_for_offline,
                            color: _isSurahDownloaded ? const Color(0xFF10B981) : Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                    tooltip: _isSurahDownloaded
                        ? (lang == 'ar' ? 'تم التنزيل (بدون إنترنت)' : (lang == 'en' ? 'Downloaded (Offline)' : 'داونلۆد کراوە (ئۆفلاین)'))
                        : (lang == 'ar' ? 'تنزيل للاستماع بدون إنترنت' : (lang == 'en' ? 'Download for offline listening' : 'داونلۆدکردن بۆ کارکردنی ئۆفلاین')),
                    onPressed: _downloadSurahAudio,
                  ),

                  if (_isFullSurahMode) ...[
                    Text(
                      '${_formatDuration(_fullPosition)} / ${_formatDuration(_fullDuration)}',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                    ),
                  ],
                ],
              ),
              if (_isFullSurahMode && _fullDuration > Duration.zero) ...[
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3.0,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    inactiveTrackColor: Colors.white10,
                    thumbColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: Slider(
                    min: 0.0,
                    max: _fullDuration.inSeconds.toDouble(),
                    value: _fullPosition.inSeconds.toDouble().clamp(0.0, _fullDuration.inSeconds.toDouble()),
                    onChanged: (val) {
                      _audioPlayer.seek(Duration(seconds: val.toInt()));
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),

      body: FutureBuilder<Map<String, dynamic>>(
        future: _versesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
          }

          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Text(
                lang == 'ar'
                    ? 'حدث خطأ أثناء تحميل الآيات'
                    : (lang == 'en'
                        ? 'Error loading verses'
                        : 'هەڵەیەک ڕوویدا لە بارکردنی ئایەتەکان'),
                style: const TextStyle(color: Colors.white, fontFamily: 'Rabar'),
              ),
            );
          }

          final List<dynamic> verses = snapshot.data!['verses'];
          _cachedVerses = verses;
          if (verses.isNotEmpty) {
            _startSurahPage = (verses.first['page'] as int?) ?? _startSurahPage ?? 1;
            _endSurahPage = (verses.last['page'] as int?) ?? _startSurahPage;
          }
          if (_totalVersesInSurah != verses.length) {
            _totalVersesInSurah = verses.length;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkDownloadedState();
            });
          }

          if (!_hasScrolledInitialAyah && widget.initialAyahId > 1) {
            _hasScrolledInitialAyah = true;
            _syncPageAndJuzForAyah(widget.initialAyahId);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToAyah(widget.initialAyahId);
            });
          }

          return Directionality(
            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
            child: ListView.builder(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: verses.length + 1,
              itemBuilder: (context, index) {
                // Header Bismillah Frame
                if (index == 0) {
                  final startPage = _startSurahPage ?? (verses.isNotEmpty ? ((verses.first['page'] as int?) ?? 1) : 1);
                  final endPage = _endSurahPage ?? startPage;
                  final startJuz = verses.isNotEmpty ? ((verses.first['juz'] as int?) ?? 1) : 1;
                  final endJuz = verses.isNotEmpty ? ((verses.last['juz'] as int?) ?? startJuz) : startJuz;

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F382C), Color(0xFF061E17)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.4), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.surahNameAr,
                          style: GoogleFonts.amiri(fontSize: 26, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        if (widget.surahId != 1 && widget.surahId != 9)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                              style: GoogleFonts.amiri(fontSize: 20, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        const SizedBox(height: 12),
                        // Information Badges: Juz, Pages, Ayahs
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.25)),
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 10,
                            children: [
                              Text(
                                startJuz == endJuz
                                    ? (lang == 'ku' ? 'پارەی $startJuz' : (lang == 'ar' ? 'الجزء $startJuz' : 'Juz $startJuz'))
                                    : (lang == 'ku' ? 'پارەی $startJuz - $endJuz' : (lang == 'ar' ? 'الأجزاء $startJuz - $endJuz' : 'Juz $startJuz - $endJuz')),
                                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                              ),
                              const Text('•', style: TextStyle(color: Colors.white24)),
                              Text(
                                startPage == endPage
                                    ? (lang == 'ku' ? 'لاپەڕە $startPage' : (lang == 'ar' ? 'صفحة $startPage' : 'Page $startPage'))
                                    : (lang == 'ku' ? 'لاپەڕە $startPage - $endPage' : (lang == 'ar' ? 'الصفحات $startPage - $endPage' : 'Pages $startPage - $endPage')),
                                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                              ),
                              const Text('•', style: TextStyle(color: Colors.white24)),
                              Text(
                                '${verses.length} ${lang == 'ku' ? 'ئایەت' : (lang == 'ar' ? 'آيات' : 'Ayahs')}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Rabar'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final verseIndex = index - 1;
                final verse = verses[verseIndex];
                final verseNum = verse['id'] as int;
                final pageNum = (verse['page'] as int?) ?? 1;
                final juzNum = (verse['juz'] as int?) ?? 1;
                final bool isFirstAyahOfPage = verseIndex == 0 || ((verses[verseIndex - 1]['page'] as int?) != pageNum);
                var arabicText = verse['text'] as String;

                if (widget.surahId != 1 && widget.surahId != 9 && verseNum == 1) {
                  const bismillah = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';
                  if (arabicText.startsWith(bismillah)) {
                    arabicText = arabicText.substring(bismillah.length).trim();
                  }
                }

                final transMap = verse['translations'] as Map<String, dynamic>;
                final translation = lang == 'en' ? (transMap['english'] ?? '') : (transMap['kurdish'] ?? '');
                final isPlayingThis = _playingAyahId == verseNum;
                final cardKey = _safeAyahKeys.putIfAbsent(verseNum, () => GlobalKey());

                final Widget ayahCard = Container(
                  key: cardKey,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: isPlayingThis
                        ? LinearGradient(
                            colors: [Theme.of(context).cardColor, const Color(0xFF1B150A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isPlayingThis ? null : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isPlayingThis ? const Color(0xFFFFD700) : Colors.white.withOpacity(0.04),
                      width: isPlayingThis ? 2.0 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isPlayingThis ? const Color(0xFFFFD700).withOpacity(0.25) : Colors.black.withOpacity(0.2),
                        blurRadius: isPlayingThis ? 14 : 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ━━━ QURAN MAJEED AYAH TOP TOOLBAR ━━━
                      Row(
                        children: [
                          // Ayah Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.4)),
                            ),
                            child: Text(
                              lang == 'en'
                                  ? 'Ayah $verseNum'
                                  : (lang == 'ar' ? 'الآية $verseNum' : 'ئایەتی $verseNum'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontFamily: 'Rabar',
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Quick Action Buttons (Always 100% visible without clipping or overflow)
                          Expanded(
                            child: Align(
                              alignment: isRTL ? Alignment.centerLeft : Alignment.centerRight,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.all(3),
                                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                    icon: Icon(
                                      isPlayingThis ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 20,
                                    ),
                                    tooltip: lang == 'en'
                                        ? 'Play Audio'
                                        : (lang == 'ar' ? 'تشغيل الصوت' : 'لێدانی دەنگ'),
                                    onPressed: () => _playAyahAudio(widget.surahId, verseNum),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.all(3),
                                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                    icon: _downloadingAyahNum == verseNum
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          )
                                        : Icon(
                                            _downloadedAyahs.contains(verseNum)
                                                ? Icons.offline_pin
                                                : Icons.download_for_offline_outlined,
                                            color: _downloadedAyahs.contains(verseNum)
                                                ? const Color(0xFF10B981)
                                                : Colors.white70,
                                            size: 18,
                                          ),
                                    tooltip: _downloadedAyahs.contains(verseNum)
                                        ? (lang == 'ar'
                                            ? 'تم تنزيل الآية (بدون إنترنت)'
                                            : (lang == 'en' ? 'Ayah Downloaded (Offline)' : 'ئەم ئایەتە داونلۆد کراوە (ئۆفلاین)'))
                                        : (lang == 'ar'
                                            ? 'تنزيل هذه الآية بدون إنترنت'
                                            : (lang == 'en' ? 'Download this Ayah offline' : 'داونلۆدکردنی ئەم ئایەتە بۆ ئۆفلاین')),
                                    onPressed: () => _downloadSingleAyah(verseNum),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.all(3),
                                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                    icon: const Icon(Icons.menu_book, color: Color(0xFFF59E0B), size: 18),
                                    tooltip: lang == 'en'
                                        ? 'Tafsir'
                                        : (lang == 'ar' ? 'تفسير' : 'تەفسیر'),
                                    onPressed: () => _showTafsirModal(verseNum, arabicText, translation),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.all(3),
                                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                    icon: const Icon(Icons.bookmark_border, color: Color(0xFF10B981), size: 18),
                                    tooltip: lang == 'en'
                                        ? 'Bookmark'
                                        : (lang == 'ar' ? 'إشارة مرجعية' : 'پاشەکەوت'),
                                    onPressed: () {
                                      final currentSurahName = lang == 'en'
                                          ? widget.surahNameEn
                                          : (lang == 'ar' ? widget.surahNameAr : widget.surahNameKu);
                                      final bookmarkTitle = lang == 'en'
                                          ? '$currentSurahName (Ayah $verseNum)'
                                          : (lang == 'ar'
                                              ? '$currentSurahName (الآية $verseNum)'
                                              : '$currentSurahName (ئایەتی $verseNum)');
                                      ref.read(bookmarksProvider.notifier).addBookmark(
                                        BookmarkItem(
                                          id: 'quran-${widget.surahId}-$verseNum',
                                          title: bookmarkTitle,
                                          subtitle: arabicText,
                                          type: 'quran',
                                          surahId: widget.surahId,
                                          surahName: currentSurahName,
                                        ),
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            lang == 'ar'
                                                ? 'تم حفظ الآية في الإشارات المرجعية'
                                                : (lang == 'en'
                                                    ? 'Ayah added to bookmarks'
                                                    : 'ئایەتەکە پاشەکەوت کرا'),
                                            style: const TextStyle(fontFamily: 'Rabar'),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.all(3),
                                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                    icon: const Icon(Icons.copy, color: Color(0xFF60A5FA), size: 18),
                                    tooltip: lang == 'en'
                                        ? 'Copy'
                                        : (lang == 'ar' ? 'نسخ' : 'کۆپی'),
                                    onPressed: () {
                                      final currentSurahName = lang == 'en'
                                          ? widget.surahNameEn
                                          : (lang == 'ar' ? widget.surahNameAr : widget.surahNameKu);
                                      final verseTag = lang == 'en'
                                          ? '[$currentSurahName - Ayah $verseNum]'
                                          : (lang == 'ar'
                                              ? '[$currentSurahName - الآية $verseNum]'
                                              : '[$currentSurahName - ئایەتی $verseNum]');
                                      final transPart = lang == 'ar' ? '' : '\n\n$translation';
                                      final fullText = '$arabicText$transPart\n\n$verseTag';
                                      Clipboard.setData(ClipboardData(text: fullText));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            lang == 'ar'
                                                ? 'تم نسخ النص إلى الحافظة'
                                                : (lang == 'en'
                                                    ? 'Text copied to clipboard'
                                                    : 'دەقەکە کۆپی کرا'),
                                            style: const TextStyle(fontFamily: 'Rabar'),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.all(3),
                                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                    icon: const Icon(Icons.share, color: Color(0xFFF472B6), size: 18),
                                    tooltip: lang == 'en'
                                        ? 'Share'
                                        : (lang == 'ar' ? 'مشاركة' : 'بەشداری پێکردن'),
                                    onPressed: () {
                                      final currentSurahName = lang == 'en'
                                          ? widget.surahNameEn
                                          : (lang == 'ar' ? widget.surahNameAr : widget.surahNameKu);
                                      final verseTag = lang == 'en'
                                          ? '[$currentSurahName - Ayah $verseNum]'
                                          : (lang == 'ar'
                                              ? '[$currentSurahName - الآية $verseNum]'
                                              : '[$currentSurahName - ئایەتی $verseNum]');
                                      final transPart = lang == 'ar' ? '' : '\n\n$translation';
                                      final fullText = '$arabicText$transPart\n\n$verseTag';
                                      Share.share(fullText);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        ],
                      ),
                      SizedBox(height: 12),

                      // Arabic Uthmani Text
                      Text(
                        arabicText,
                        style: _getQuranTextStyle(context, settings, isPlayingThis),
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                      ),

                      if (_viewMode == 'ayah' && _showTranslation && lang != 'ar') ...[
                        const Divider(color: Colors.white10, height: 20),
                        Text(
                          translation,
                          style: TextStyle(
                            fontSize: settings.quranTranslationFontSize,
                            height: 1.6,
                            color: Colors.white.withOpacity(0.75),
                            fontFamily: 'Rabar',
                          ),
                          textAlign: isRTL ? TextAlign.right : TextAlign.left,
                        ),
                      ],
                    ],
                  ),
                );

                final bool isEndOfPage = (verseIndex == verses.length - 1) ||
                    ((verses[verseIndex + 1]['page'] as int?) != pageNum);

                if (isEndOfPage) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ayahCard,
                      QuranPageDividerWidget(
                        pageNumber: pageNum,
                        onTap: _showJumpToAyahDialog,
                      ),
                    ],
                  );
                }

                return ayahCard;
              },
            ),
          );
        },
      ),
    );
  }
}

// ━━━ QURAN APP BAR BACKGROUND PAINTER (ISLAMIC DOME SILHOUETTE) ━━━
class QuranAppBarBackgroundPainter extends CustomPainter {
  final Color baseColor;
  final Color domeColor;

  QuranAppBarBackgroundPainter({
    required this.baseColor,
    required this.domeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Base rectangle
    final Paint basePaint = Paint()..color = baseColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);

    // 2. Islamic mosque dome silhouette centered at top behind page number
    final double cx = size.width / 2;
    const double domeWidth = 106.0;
    final double domeHeight = size.height * 0.78;
    final Paint domePaint = Paint()..color = domeColor;

    final Path domePath = Path();
    domePath.moveTo(cx - domeWidth / 2, size.height);
    domePath.lineTo(cx - domeWidth / 2, size.height - domeHeight * 0.45);
    domePath.cubicTo(
      cx - domeWidth / 2, size.height - domeHeight * 0.85,
      cx - 16, size.height - domeHeight * 0.96,
      cx, size.height - domeHeight,
    );
    domePath.cubicTo(
      cx + 16, size.height - domeHeight * 0.96,
      cx + domeWidth / 2, size.height - domeHeight * 0.85,
      cx + domeWidth / 2, size.height - domeHeight * 0.45,
    );
    domePath.lineTo(cx + domeWidth / 2, size.height);
    domePath.close();

    canvas.drawPath(domePath, domePaint);

    // Small crescent finial on dome peak
    final Paint finialPaint = Paint()
      ..color = domeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawLine(
      Offset(cx, size.height - domeHeight),
      Offset(cx, size.height - domeHeight - 5),
      finialPaint,
    );
    canvas.drawCircle(Offset(cx, size.height - domeHeight - 6), 1.6, Paint()..color = domeColor);
  }

  @override
  bool shouldRepaint(covariant QuranAppBarBackgroundPainter oldDelegate) {
    return oldDelegate.baseColor != baseColor || oldDelegate.domeColor != domeColor;
  }
}

// ━━━ QURAN ISLAMIC ORNAMENTAL PAGE DIVIDER ━━━
class QuranPageDividerWidget extends StatelessWidget {
  final int pageNumber;
  final VoidCallback? onTap;

  const QuranPageDividerWidget({
    super.key,
    required this.pageNumber,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        height: 44,
        child: CustomPaint(
          painter: QuranPageDividerPainter(
            pageNumber: pageNumber,
            dividerColor: const Color(0xFF8E9F94),
            textColor: Colors.white,
          ),
          size: const Size(double.infinity, 44),
        ),
      ),
    );
  }
}

class QuranPageDividerPainter extends CustomPainter {
  final int pageNumber;
  final Color dividerColor;
  final Color textColor;

  QuranPageDividerPainter({
    required this.pageNumber,
    required this.dividerColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    final Paint strokePaint = Paint()
      ..color = dividerColor.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    final Paint fillPaint = Paint()
      ..color = dividerColor.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    const double lineSpacing = 13.0;
    final double yTop = cy - lineSpacing;
    final double yBottom = cy + lineSpacing;

    const double halfBoxWidth = 32.0;
    const double ornamentWidth = 28.0;
    final double leftScrollStart = cx - halfBoxWidth - ornamentWidth;
    final double rightScrollEnd = cx + halfBoxWidth + ornamentWidth;

    // 1. Left outer parallel lines
    if (leftScrollStart > 12) {
      canvas.drawLine(Offset(8, yTop), Offset(leftScrollStart, yTop), strokePaint);
      canvas.drawLine(Offset(8, yBottom), Offset(leftScrollStart, yBottom), strokePaint);
    }

    // 2. Right outer parallel lines
    if (rightScrollEnd < size.width - 12) {
      canvas.drawLine(Offset(rightScrollEnd, yTop), Offset(size.width - 8, yTop), strokePaint);
      canvas.drawLine(Offset(rightScrollEnd, yBottom), Offset(size.width - 8, yBottom), strokePaint);
    }

    // 3. Central horizontal frame lines above and below number
    canvas.drawLine(Offset(cx - halfBoxWidth, yTop), Offset(cx + halfBoxWidth, yTop), strokePaint);
    canvas.drawLine(Offset(cx - halfBoxWidth, yBottom), Offset(cx + halfBoxWidth, yBottom), strokePaint);

    // Decorative apex / diamond on top and bottom frame
    final Path topApex = Path()
      ..moveTo(cx - 3.5, yTop)
      ..lineTo(cx, yTop - 3.5)
      ..lineTo(cx + 3.5, yTop)
      ..close();
    canvas.drawPath(topApex, fillPaint);

    final Path btmApex = Path()
      ..moveTo(cx - 3.5, yBottom)
      ..lineTo(cx, yBottom + 3.5)
      ..lineTo(cx + 3.5, yBottom)
      ..close();
    canvas.drawPath(btmApex, fillPaint);

    // 4. Left Arabesque Scrollwork
    _drawOrnament(
      canvas,
      strokePaint,
      fillPaint,
      cx: cx - halfBoxWidth,
      yTop: yTop,
      yBottom: yBottom,
      cy: cy,
      isLeft: true,
    );

    // 5. Right Arabesque Scrollwork
    _drawOrnament(
      canvas,
      strokePaint,
      fillPaint,
      cx: cx + halfBoxWidth,
      yTop: yTop,
      yBottom: yBottom,
      cy: cy,
      isLeft: false,
    );

    // 6. Draw Page Number in center
    final textSpan = TextSpan(
      text: pageNumber.toString(),
      style: GoogleFonts.amiri(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: textColor,
        height: 1.0,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(cx - textPainter.width / 2, cy - textPainter.height / 2 - 1),
    );
  }

  void _drawOrnament(
    Canvas canvas,
    Paint strokePaint,
    Paint fillPaint, {
    required double cx,
    required double yTop,
    required double yBottom,
    required double cy,
    required bool isLeft,
  }) {
    final double dir = isLeft ? -1.0 : 1.0;

    // Top scroll: connects from frame corner (cx, yTop) looping outward and inward
    final Path topScroll = Path();
    topScroll.moveTo(cx, yTop);
    topScroll.cubicTo(
      cx + dir * 10, yTop - 5,
      cx + dir * 22, yTop - 3,
      cx + dir * 20, cy - 2,
    );
    topScroll.cubicTo(
      cx + dir * 18, cy,
      cx + dir * 10, cy - 4,
      cx + dir * 14, cy - 7,
    );
    canvas.drawPath(topScroll, strokePaint);

    // Bottom scroll: connects from frame corner (cx, yBottom) looping outward and inward
    final Path btmScroll = Path();
    btmScroll.moveTo(cx, yBottom);
    btmScroll.cubicTo(
      cx + dir * 10, yBottom + 5,
      cx + dir * 22, yBottom + 3,
      cx + dir * 20, cy + 2,
    );
    btmScroll.cubicTo(
      cx + dir * 18, cy,
      cx + dir * 10, cy + 4,
      cx + dir * 14, cy + 7,
    );
    canvas.drawPath(btmScroll, strokePaint);

    // Connecting horizontal flourish in the middle
    final Path midFlourish = Path();
    midFlourish.moveTo(cx, cy);
    midFlourish.lineTo(cx + dir * 26, cy);
    canvas.drawPath(midFlourish, strokePaint);

    // Decorative dots
    canvas.drawCircle(Offset(cx + dir * 26, cy), 2.2, fillPaint);
    canvas.drawCircle(Offset(cx + dir * 14, cy - 7), 1.5, fillPaint);
    canvas.drawCircle(Offset(cx + dir * 14, cy + 7), 1.5, fillPaint);
  }

  @override
  bool shouldRepaint(covariant QuranPageDividerPainter oldDelegate) {
    return oldDelegate.pageNumber != pageNumber ||
        oldDelegate.dividerColor != dividerColor ||
        oldDelegate.textColor != textColor;
  }
}
