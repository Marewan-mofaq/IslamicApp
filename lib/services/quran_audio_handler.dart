import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

class QuranAudioHandler extends BaseAudioHandler with SeekHandler {
  static QuranAudioHandler? instance;

  // Callbacks hooked by current audio playing screen
  VoidCallback? onPlayCallback;
  VoidCallback? onPauseCallback;
  VoidCallback? onStopCallback;
  VoidCallback? onSkipToNextCallback;
  VoidCallback? onSkipToPreviousCallback;
  ValueChanged<Duration>? onSeekCallback;

  QuranAudioHandler() {
    instance = this;
    playbackState.add(
      PlaybackState(
        controls: const [
          MediaControl.skipToPrevious,
          MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
  }

  void setQuranMediaItem({
    required String id,
    required String title,
    required String artist,
    String? album,
    Duration? duration,
    Uri? artUri,
  }) {
    mediaItem.add(
      MediaItem(
        id: id,
        title: title,
        artist: artist,
        album: album ?? 'دەنگی قورئانی پیرۆز',
        duration: duration,
        artUri: artUri,
      ),
    );
  }

  bool? _lastIsPlaying;
  bool? _lastIsStopped;
  double? _lastSpeed;
  Duration? _lastPosition;
  DateTime? _lastUpdateTime;

  void updatePlaybackStatus({
    required bool isPlaying,
    required Duration position,
    Duration? duration,
    double speed = 1.0,
    bool isStopped = false,
  }) {
    if (duration != null && duration > Duration.zero) {
      final current = mediaItem.value;
      if (current != null && current.duration != duration) {
        mediaItem.add(current.copyWith(duration: duration));
      }
    }

    final now = DateTime.now();
    final bool stateChanged = isPlaying != _lastIsPlaying ||
        isStopped != _lastIsStopped ||
        speed != _lastSpeed;
    final bool isSeek = _lastPosition != null &&
        (position - _lastPosition!).inMilliseconds.abs() > 2500;
    final bool throttleExpired = _lastUpdateTime == null ||
        now.difference(_lastUpdateTime!).inMilliseconds > 1500;

    if (!stateChanged && !isSeek && !throttleExpired && !isStopped) {
      return;
    }

    _lastIsPlaying = isPlaying;
    _lastIsStopped = isStopped;
    _lastSpeed = speed;
    _lastPosition = position;
    _lastUpdateTime = now;

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          isPlaying ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: isStopped ? AudioProcessingState.idle : AudioProcessingState.ready,
        playing: isPlaying,
        updatePosition: position,
        bufferedPosition: position,
        speed: speed,
      ),
    );
  }

  @override
  Future<void> play() async {
    onPlayCallback?.call();
  }

  @override
  Future<void> pause() async {
    onPauseCallback?.call();
  }

  @override
  Future<void> stop() async {
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
    onStopCallback?.call();
  }

  @override
  Future<void> skipToNext() async {
    onSkipToNextCallback?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    onSkipToPreviousCallback?.call();
  }

  @override
  Future<void> seek(Duration position) async {
    onSeekCallback?.call(position);
  }
}
