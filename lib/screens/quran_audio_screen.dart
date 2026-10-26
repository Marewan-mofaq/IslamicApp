import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/settings_provider.dart';
import '../services/data_service.dart';
import '../services/audio_downloader_service.dart';
import '../services/notification_service.dart';
import '../services/quran_audio_handler.dart';

class QuranAudioScreen extends ConsumerStatefulWidget {
  final int? initialSurahId;
  const QuranAudioScreen({super.key, this.initialSurahId});

  @override
  ConsumerState<QuranAudioScreen> createState() => _QuranAudioScreenState();
}

class _QuranAudioScreenState extends ConsumerState<QuranAudioScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  List<dynamic> _surahs = [];
  List<dynamic> _reciters = [];
  dynamic _selectedReciter;
  dynamic _currentSurah;
  
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isAutoNext = true;
  double _playbackSpeed = 1.0;
  
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  // Offline caching states
  Set<int> _downloadedSurahs = {};
  final Map<int, double> _downloadProgress = {};

  // Streams subscriptions
  dynamic _positionSub;
  dynamic _durationSub;
  dynamic _stateSub;
  dynamic _completeSub;
  StateSetter? _modalSetState;

  /// Safely call _modalSetState - catches errors when the modal is already dismissed
  void _safeModalSetState() {
    try {
      _modalSetState?.call(() {});
    } catch (_) {
      _modalSetState = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _initAudio();
    _loadData();
  }

  void _initAudio() {
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
        debugPrint('[QuranAudio] Error setting audio context: $e');
      }
    }

    _positionSub = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) {
        setState(() => _position = p);
        _safeModalSetState();
      }
    });
    _durationSub = _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) {
        setState(() => _duration = d);
        _safeModalSetState();
      }
      QuranAudioHandler.instance?.updatePlaybackStatus(
        isPlaying: _isPlaying,
        position: _position,
        duration: d,
        speed: _playbackSpeed,
      );
    });
    _stateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (state != PlayerState.playing) {
            _isLoading = false;
          }
        });
        _safeModalSetState();
        _updateNotification();
      }
    });
    _completeSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (_isAutoNext) {
        _playNext();
      } else {
        if (mounted) {
          setState(() => _isPlaying = false);
          _safeModalSetState();
          _updateNotification(isDismissed: true);
        }
      }
    });

    final handler = QuranAudioHandler.instance;
    if (handler != null) {
      handler.onPlayCallback = () {
        if (_currentSurah != null && !_isPlaying) {
          _playSurah(_currentSurah);
        }
      };
      handler.onPauseCallback = () {
        if (_isPlaying) {
          _audioPlayer.pause();
        }
      };
      handler.onStopCallback = () {
        _audioPlayer.stop();
        if (mounted) {
          setState(() => _isPlaying = false);
          _modalSetState?.call(() {});
        }
        _updateNotification(isDismissed: true);
      };
      handler.onSkipToNextCallback = () {
        _playNext();
      };
      handler.onSkipToPreviousCallback = () {
        _playPrevious();
      };
      handler.onSeekCallback = (pos) {
        _audioPlayer.seek(pos);
      };
    }

    NotificationService.onQuranPlaybackAction = (action) {
      if (!mounted) return;
      if (action == 'quran_play_pause') {
        if (_currentSurah != null) _playSurah(_currentSurah);
      } else if (action == 'quran_prev') {
        _playPrevious();
      } else if (action == 'quran_next') {
        _playNext();
      } else if (action == 'quran_stop') {
        _audioPlayer.stop();
        setState(() => _isPlaying = false);
        _modalSetState?.call(() {});
        _updateNotification(isDismissed: true);
      }
    };
  }

  void _updateNotification({bool isDismissed = false}) {
    if (isDismissed) {
      NotificationService.dismissQuranPlaybackNotification();
      QuranAudioHandler.instance?.updatePlaybackStatus(
        isPlaying: false,
        position: Duration.zero,
        isStopped: true,
      );
      return;
    }

    if (_currentSurah == null || _selectedReciter == null) return;
    final settings = ref.read(settingsProvider);
    final lang = settings.language;
    final surahName = lang == 'en'
        ? (_currentSurah['name_en'] ?? _currentSurah['name_ar'] ?? '')
        : (lang == 'ar' ? (_currentSurah['name_ar'] ?? _currentSurah['name_ku'] ?? '') : (_currentSurah['name_ku'] ?? _currentSurah['name_ar'] ?? ''));
    final reciterName = lang == 'en'
        ? (_selectedReciter['name_en'] ?? _selectedReciter['name_ar'] ?? '')
        : (lang == 'ar' ? (_selectedReciter['name_ar'] ?? _selectedReciter['name_ku'] ?? '') : (_selectedReciter['name_ku'] ?? _selectedReciter['name_ar'] ?? ''));

    NotificationService.showQuranPlaybackNotification(
      surahName: surahName.toString(),
      reciterName: reciterName.toString(),
      isPlaying: _isPlaying,
    );

    final handler = QuranAudioHandler.instance;
    if (handler != null) {
      handler.setQuranMediaItem(
        id: '${_currentSurah['id']}_${_selectedReciter['id']}',
        title: surahName.toString(),
        artist: reciterName.toString(),
        duration: _duration > Duration.zero ? _duration : null,
      );
      handler.updatePlaybackStatus(
        isPlaying: _isPlaying,
        position: _position,
        duration: _duration > Duration.zero ? _duration : null,
        speed: _playbackSpeed,
      );
    }
  }

  Future<void> _loadData() async {
    try {
      final surahs = await DataService.loadSurahInfo();
      final reciters = await DataService.loadReciters();
      
      if (mounted) {
        setState(() {
          _surahs = surahs;
          _reciters = reciters;
          if (_reciters.isNotEmpty) {
            _selectedReciter = _reciters.first;
          }
        });

        await _updateDownloadedList();

        if (widget.initialSurahId != null) {
          final target = _surahs.firstWhere(
            (s) => s['id'] == widget.initialSurahId,
            orElse: () => null,
          );
          if (target != null) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!mounted) return;
              _playSurah(target);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading audio metadata: $e');
    }
  }

  Future<void> _updateDownloadedList() async {
    if (_selectedReciter == null) return;
    final reciterId = _selectedReciter['id'].toString();
    final downloaded = <int>{};
    for (final s in _surahs) {
      final id = s['id'] as int;
      final exists = await AudioDownloaderService.isDownloaded(reciterId, id);
      if (exists) {
        downloaded.add(id);
      }
    }
    if (mounted) {
      setState(() {
        _downloadedSurahs = downloaded;
      });
    }
  }

  @override
  void dispose() {
    _updateNotification(isDismissed: true);
    if (NotificationService.onQuranPlaybackAction != null) {
      NotificationService.onQuranPlaybackAction = null;
    }
    final handler = QuranAudioHandler.instance;
    if (handler != null) {
      handler.onPlayCallback = null;
      handler.onPauseCallback = null;
      handler.onStopCallback = null;
      handler.onSkipToNextCallback = null;
      handler.onSkipToPreviousCallback = null;
      handler.onSeekCallback = null;
      handler.stop();
    }
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    _audioPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _playSurah(dynamic surah, {bool forceReload = false}) async {
    if (_selectedReciter == null) return;
    
    final isSameSurah = _currentSurah != null && _currentSurah['id'] == surah['id'];
    if (isSameSurah && !forceReload) {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.resume();
      }
      return;
    }

    setState(() {
      _currentSurah = surah;
      _isLoading = true;
      _position = Duration.zero;
      _duration = Duration.zero;
    });

    try {
      final int id = surah['id'];
      final reciterId = _selectedReciter['id'].toString();
      final isOffline = _downloadedSurahs.contains(id);

      Source source;
      if (isOffline) {
        final localPath = await AudioDownloaderService.getLocalPath(reciterId, id);
        source = DeviceFileSource(localPath);
      } else {
        final paddedNumber = id.toString().padLeft(3, '0');
        final primaryUrl = '${_selectedReciter['server_mp3']}$paddedNumber.mp3';
        source = UrlSource(primaryUrl);
      }
      
      await _audioPlayer.stop();
      await _audioPlayer.setPlaybackRate(_playbackSpeed);
      await _audioPlayer.play(source);
      
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isPlaying = true;
      });
    } catch (e) {
      // Fallback mirror if primary server fails
      try {
        final int id = surah['id'];
        final paddedNumber = id.toString().padLeft(3, '0');
        final fallbackUrl = 'https://download.quranicaudio.com/quran/mishaari_raashid_al_3afaasee/$paddedNumber.mp3';
        await _audioPlayer.play(UrlSource(fallbackUrl));
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isPlaying = true;
        });
        return;
      } catch (_) {}

      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        final lang = ref.read(settingsProvider).language;
        final errorMsg = lang == 'ku'
            ? 'نەتوانرا دەنگی ئەم قورئانخوێنە لە سەرڤەرەوە لێبدرێت'
            : lang == 'ar'
                ? 'تعذر تشغيل تلاوة هذا القارئ من الخادم'
                : 'Could not stream audio for this reciter from the server';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    }
  }

  Future<void> _downloadSurah(dynamic surah) async {
    final lang = ref.read(settingsProvider).language;
    if (!kIsWeb) {
      final hasNet = await AudioDownloaderService.hasInternetConnection();
      if (!hasNet) {
        if (mounted) {
          final failMsg = lang == 'ku'
              ? '❌ هێڵی ئینتەرنێت کوژاوەتەوە! بۆ داونلۆدکردن تکایە ئینتەرنێت دابگیرسێنە.'
              : lang == 'ar'
                  ? '❌ لا يوجد اتصال بالإنترنت! يرجى تفعيل الإنترنت لتنزيل السورة.'
                  : '❌ No internet connection! Please turn on internet to download.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFEF4444),
              content: Text(failMsg),
            ),
          );
        }
        return;
      }
    }

    final int id = surah['id'];
    final reciterId = _selectedReciter['id'].toString();
    final paddedNumber = id.toString().padLeft(3, '0');
    final audioUrl = '${_selectedReciter['server_mp3']}$paddedNumber.mp3';

    if (!mounted) return;
    setState(() {
      _downloadProgress[id] = 0.01;
    });

    final localPath = await AudioDownloaderService.downloadAudio(
      reciterId,
      id,
      audioUrl,
      (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress[id] = progress;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _downloadProgress.remove(id);
      });
      if (localPath != null) {
        await _updateDownloadedList();
      } else {
        final lang = ref.read(settingsProvider).language;
        final failMsg = lang == 'ku'
            ? 'داونلۆدکردن سەرکەوتوو نەبوو. هێڵی ئینتەرنێت پشکنە.'
            : lang == 'ar'
                ? 'فشل التحميل. يرجى التحقق من اتصال الإنترنت.'
                : 'Download failed. Check your network.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failMsg)),
        );
      }
    }
  }

  Future<void> _deleteSurah(dynamic surah) async {
    final int id = surah['id'];
    final reciterId = _selectedReciter['id'].toString();
    
    final deleted = await AudioDownloaderService.deleteDownloaded(reciterId, id);
    if (deleted) {
      await _updateDownloadedList();
      if (mounted) {
        final lang = ref.read(settingsProvider).language;
        final sName = lang == 'ku'
            ? (surah['name_ku'] ?? surah['name_ar'])
            : lang == 'ar'
                ? (surah['name_ar'] ?? surah['name_ku'])
                : (surah['name_en'] ?? surah['name_ar']);
        final delMsg = lang == 'ku'
            ? '$sName لە یادگەی ئۆفلاین سڕایەوە.'
            : lang == 'ar'
                ? 'تم حذف $sName من التخزين بدون إنترنت.'
                : '$sName deleted from offline storage.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(delMsg)),
        );
      }
    }
  }

  void _playNext() {
    if (_surahs.isEmpty || _currentSurah == null) return;
    final currentIndex = _surahs.indexWhere((s) => s['id'] == _currentSurah['id']);
    if (currentIndex != -1 && currentIndex < _surahs.length - 1) {
      _playSurah(_surahs[currentIndex + 1], forceReload: true);
    }
  }

  void _playPrevious() {
    if (_surahs.isEmpty || _currentSurah == null) return;
    final currentIndex = _surahs.indexWhere((s) => s['id'] == _currentSurah['id']);
    if (currentIndex > 0) {
      _playSurah(_surahs[currentIndex - 1], forceReload: true);
    }
  }

  void _changePlaybackSpeed() {
    double nextSpeed = 1.0;
    if (_playbackSpeed == 1.0) {
      nextSpeed = 1.25;
    } else if (_playbackSpeed == 1.25) {
      nextSpeed = 1.5;
    } else if (_playbackSpeed == 1.5) {
      nextSpeed = 2.0;
    } else {
      nextSpeed = 1.0;
    }

    setState(() {
      _playbackSpeed = nextSpeed;
    });
    _audioPlayer.setPlaybackRate(_playbackSpeed);
  }

  void _showReciterSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'دەنگخوێن هەڵبژێرە',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
              ),
            ),
            const Divider(color: Colors.white10),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: _reciters.length,
                itemBuilder: (context, index) {
                  final reciter = _reciters[index];
                  final isSelected = _selectedReciter != null && _selectedReciter['id'] == reciter['id'];
                  
                  return ListTile(
                    leading: Text(reciter['flag'] ?? '🎙️', style: TextStyle(fontSize: 22)),
                    title: Text(
                      reciter['name_ku'] ?? '',
                      style: TextStyle(
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontFamily: 'Rabar',
                      ),
                    ),
                    trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
                    onTap: () async {
                      final prevSurah = _currentSurah;
                      final prevPos = _position;
                      final wasPlaying = _isPlaying;
                      final isDifferent = _selectedReciter == null || _selectedReciter['id'] != reciter['id'];

                      setState(() {
                        _selectedReciter = reciter;
                      });
                      await _updateDownloadedList();
                      if (!mounted) return;
                      Navigator.pop(context);

                      if (isDifferent && prevSurah != null) {
                        if (wasPlaying) {
                          await _playSurah(prevSurah, forceReload: true);
                          if (prevPos > Duration.zero) {
                            try {
                              await _audioPlayer.seek(prevPos);
                            } catch (_) {}
                          }
                        }
                      }
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFullPlayer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        final settings = ref.read(settingsProvider);
        return StatefulBuilder(
          builder: (context, setModalState) {
            _modalSetState = setModalState;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // Reciter Title
                  Text(
                    settings.language == 'ku'
                        ? (_selectedReciter['name_ku'] ?? _selectedReciter['name_ar'])
                        : settings.language == 'ar'
                            ? (_selectedReciter['name_ar'] ?? _selectedReciter['name_ku'])
                            : (_selectedReciter['name_en'] ?? _selectedReciter['name_ar']),
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                  ),
                  SizedBox(height: 4),
                  
                  // Surah Title
                  Text(
                    settings.language == 'ku'
                        ? (_currentSurah['name_ku'] ?? _currentSurah['name_ar'])
                        : settings.language == 'ar'
                            ? (_currentSurah['name_ar'] ?? _currentSurah['name_ku'])
                            : (_currentSurah['name_en'] ?? _currentSurah['name_ar']),
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Rabar'),
                  ),
                  SizedBox(height: 30),
                  
                  // Progress Bar
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Theme.of(context).colorScheme.primary,
                      inactiveTrackColor: Colors.white.withOpacity(0.1),
                      thumbColor: Theme.of(context).colorScheme.primary,
                      overlayColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      value: _position.inMilliseconds.toDouble(),
                      max: _duration.inMilliseconds.toDouble() > 0
                          ? _duration.inMilliseconds.toDouble()
                          : 1.0,
                      onChanged: (val) {
                        _audioPlayer.seek(Duration(milliseconds: val.toInt()));
                      },
                    ),
                  ),
                  
                  // Duration labels
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(_position), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                        Text(_formatDuration(_duration), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // Controls row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Previous
                      IconButton(
                        icon: Icon(Icons.skip_previous, size: 36, color: Colors.white),
                        onPressed: () {
                          _playPrevious();
                          setModalState(() {});
                        },
                      ),
                      SizedBox(width: 24),
                      
                      // Play/Pause
                      GestureDetector(
                        onTap: () {
                          _playSurah(_currentSurah);
                          setModalState(() {});
                        },
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(color: Theme.of(context).cardColor),
                          child: Center(
                            child: _isLoading
                                ? CircularProgressIndicator(color: Colors.white)
                                : Icon(
                                    _isPlaying ? Icons.pause : Icons.play_arrow,
                                    size: 40,
                                    color: Colors.black,
                                  ),
                          ),
                        ),
                      ),
                      SizedBox(width: 24),
                      
                      // Next
                      IconButton(
                        icon: Icon(Icons.skip_next, size: 36, color: Colors.white),
                        onPressed: () {
                          _playNext();
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 40),
                  
                  // Bottom Utility Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Playback Speed
                      TextButton(
                        onPressed: () {
                          _changePlaybackSpeed();
                          setModalState(() {});
                        },
                        child: Text(
                          '${_playbackSpeed}x',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                        ),
                      ),
                      
                      // Auto Next Toggle
                      IconButton(
                        icon: Icon(
                          Icons.repeat_one,
                          color: _isAutoNext ? Theme.of(context).colorScheme.primary : Colors.white.withOpacity(0.5),
                          size: 24,
                        ),
                        onPressed: () {
                          setState(() {
                            _isAutoNext = !_isAutoNext;
                          });
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _modalSetState = null;
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.palette;
    
    final title = settings.language == 'ku'
        ? '🎧 دەنگی قورئان'
        : settings.language == 'ar'
            ? '🎧 تلاوات القرآن الكريم'
            : '🎧 Quran Audio';
    final searchPlaceholder = settings.language == 'ku'
        ? 'گەڕان بەدوای سورەت...'
        : settings.language == 'ar'
            ? 'ابحث عن سورة...'
            : 'Search Surah...';

    final filteredSurahs = _surahs.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final nameKu = (s['name_ku'] ?? '').toString().toLowerCase();
      final nameAr = (s['name_ar'] ?? '').toString().toLowerCase();
      final nameEn = (s['name_en'] ?? '').toString().toLowerCase();
      final idStr = (s['id'] ?? '').toString();
      return nameKu.contains(q) || nameAr.contains(q) || nameEn.contains(q) || idStr.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Rabar')),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Reciter Selection Pill Card
          if (_selectedReciter != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: InkWell(
                onTap: _showReciterSelection,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      Text(_selectedReciter['flag'] ?? '🎙️', style: TextStyle(fontSize: 22)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          settings.language == 'ku'
                              ? (_selectedReciter['name_ku'] ?? _selectedReciter['name_ar'])
                              : settings.language == 'ar'
                                  ? (_selectedReciter['name_ar'] ?? _selectedReciter['name_ku'])
                                  : (_selectedReciter['name_en'] ?? _selectedReciter['name_ar']),
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Rabar'),
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down, color: Colors.white.withOpacity(0.5)),
                    ],
                  ),
                ),
              ),
            ),
            
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: searchPlaceholder,
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontFamily: 'Rabar'),
                prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18, color: Colors.white),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.02),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.04)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.04)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
          ),
          
          // Surahs list
          Expanded(
            child: _surahs.isEmpty
                ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    itemCount: filteredSurahs.length,
                    itemBuilder: (context, index) {
                      final surah = filteredSurahs[index];
                      final id = surah['id'] as int;
                      final isCurrent = _currentSurah != null && _currentSurah['id'] == id;
                      final isOffline = _downloadedSurahs.contains(id);
                      final downloadVal = _downloadProgress[id];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isCurrent ? Theme.of(context).colorScheme.primary.withOpacity(0.04) : Colors.white.withOpacity(0.01),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCurrent ? Theme.of(context).colorScheme.primary : Colors.white.withOpacity(0.03),
                            width: isCurrent ? 1.5 : 1.0,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCurrent ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.white.withOpacity(0.03),
                            ),
                            child: Center(
                              child: isCurrent && _isPlaying
                                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                                  : Text(
                                      '$id',
                                      style: TextStyle(
                                        color: isCurrent ? Theme.of(context).colorScheme.primary : Colors.white.withOpacity(0.6),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                            ),
                          ),
                          title: Text(
                            settings.language == 'ku'
                                ? (surah['name_ku'] ?? surah['name_ar'])
                                : settings.language == 'ar'
                                    ? (surah['name_ar'] ?? surah['name_ku'])
                                    : (surah['name_en'] ?? surah['name_ar']),
                            style: TextStyle(
                              color: isCurrent ? Theme.of(context).colorScheme.primary : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Rabar',
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            '${surah['type'] == 'Meccan' ? (settings.language == 'ku' ? 'مەککی' : settings.language == 'ar' ? 'مكية' : 'Meccan') : (settings.language == 'ku' ? 'مەدەنی' : settings.language == 'ar' ? 'مدنية' : 'Medinan')} • ${surah['verses_count']} ${settings.language == 'ku' ? 'ئایەت' : settings.language == 'ar' ? 'آيات' : 'Verses'}',
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontFamily: 'Rabar'),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Download status/button
                              if (downloadVal != null)
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    value: downloadVal,
                                    color: Theme.of(context).colorScheme.primary,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              else if (isOffline)
                                IconButton(
                                  icon: Icon(Icons.speed, color: Theme.of(context).colorScheme.primary),
                                  onPressed: () => _deleteSurah(surah),
                                )
                              else
                                IconButton(
                                  icon: Icon(Icons.download_for_offline_outlined, color: Colors.white30, size: 24),
                                  onPressed: () => _downloadSurah(surah),
                                ),
                              SizedBox(width: 8),

                              // Play / Pause button
                              IconButton(
                                icon: Icon(
                                  isCurrent && _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                  color: isCurrent ? Theme.of(context).colorScheme.primary : Colors.white.withOpacity(0.6),
                                  size: 32,
                                ),
                                onPressed: () => _playSurah(surah),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // Mini Player bar
          if (_currentSurah != null)
            GestureDetector(
              onTap: _showFullPlayer,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                      ),
                      child: Center(
                        child: Icon(Icons.music_note, color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            settings.language == 'ku'
                                ? (_currentSurah['name_ku'] ?? _currentSurah['name_ar'])
                                : settings.language == 'ar'
                                    ? (_currentSurah['name_ar'] ?? _currentSurah['name_ku'])
                                    : (_currentSurah['name_en'] ?? _currentSurah['name_ar']),
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Rabar'),
                          ),
                          SizedBox(height: 2),
                          Text(
                            settings.language == 'ku'
                                ? (_selectedReciter['name_ku'] ?? _selectedReciter['name_ar'])
                                : settings.language == 'ar'
                                    ? (_selectedReciter['name_ar'] ?? _selectedReciter['name_ku'])
                                    : (_selectedReciter['name_en'] ?? _selectedReciter['name_ar']),
                            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontFamily: 'Rabar'),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: _isLoading
                          ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary, strokeWidth: 2))
                          : Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 28),
                      onPressed: () => _playSurah(_currentSurah),
                    ),
                    IconButton(
                      icon: Icon(Icons.skip_next, color: Colors.white, size: 28),
                      onPressed: _playNext,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
