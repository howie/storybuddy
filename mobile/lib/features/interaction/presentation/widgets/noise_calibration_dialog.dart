/// T092 [P] [US5] Noise calibration dialog widget.
///
/// Shows calibration progress and instructions to the user
/// before starting interactive story mode.
library;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:storybuddy/features/interaction/data/services/noise_calibration_service.dart';

/// State for the calibration dialog.
enum CalibrationState {
  /// Showing instructions before starting.
  instructions,

  /// Calibration in progress.
  calibrating,

  /// Calibration completed successfully.
  completed,

  /// Calibration failed.
  failed,
}

/// Dialog for noise calibration before interactive mode.
class NoiseCalibrationDialog extends ConsumerStatefulWidget {

  const NoiseCalibrationDialog({
    required this.onCalibrationComplete, required this.onCancel, required this.audioStream, super.key,
  });
  /// Callback when calibration completes successfully.
  final void Function(CalibrationResult result) onCalibrationComplete;

  /// Callback when calibration is cancelled.
  final VoidCallback onCancel;

  /// Audio frame stream for calibration.
  final Stream<List<int>> audioStream;

  @override
  ConsumerState<NoiseCalibrationDialog> createState() =>
      _NoiseCalibrationDialogState();
}

class _NoiseCalibrationDialogState extends ConsumerState<NoiseCalibrationDialog>
    with SingleTickerProviderStateMixin {
  CalibrationState _state = CalibrationState.instructions;
  double _progress = 0;
  String? _errorMessage;
  CalibrationResult? _result;

  final NoiseCalibrationService _calibrationService = NoiseCalibrationService();
  StreamSubscription<List<int>>? _audioSubscription;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioSubscription?.cancel();
    _calibrationService.dispose();
    super.dispose();
  }

  void _startCalibration() {
    setState(() {
      _state = CalibrationState.calibrating;
      _progress = 0.0;
    });

    _calibrationService.startCalibration();

    _audioSubscription = widget.audioStream.listen(
      (audioData) {
        final frame =
            List<int>.from(audioData);

        final needsMore = _calibrationService.addFrame(
          List<int>.from(frame).toList(),
        );

        setState(() {
          _progress = _calibrationService.progress;
        });

        if (!needsMore) {
          _completeCalibration();
        }
      },
      onError: (error) {
        setState(() {
          _state = CalibrationState.failed;
          _errorMessage = '音訊錯誤：$error';
        });
      },
    );

    // Timeout after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (_state == CalibrationState.calibrating) {
        _completeCalibration();
      }
    });
  }

  void _completeCalibration() {
    _audioSubscription?.cancel();

    try {
      final result = _calibrationService.completeCalibration();
      setState(() {
        _state = CalibrationState.completed;
        _result = result;
      });

      // Auto-proceed after showing result
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && _state == CalibrationState.completed) {
          widget.onCalibrationComplete(result);
        }
      });
    } catch (e) {
      setState(() {
        _state = CalibrationState.failed;
        _errorMessage = '校準失敗：$e';
      });
    }
  }

  void _retry() {
    _calibrationService.reset();
    setState(() {
      _state = CalibrationState.instructions;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildContent(),
            const SizedBox(height: 24),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String title;
    IconData icon;
    Color iconColor;

    switch (_state) {
      case CalibrationState.instructions:
        title = '環境噪音校準';
        icon = Icons.mic;
        iconColor = Theme.of(context).colorScheme.primary;
        break;
      case CalibrationState.calibrating:
        title = '正在校準...';
        icon = Icons.hearing;
        iconColor = Theme.of(context).colorScheme.secondary;
        break;
      case CalibrationState.completed:
        title = '校準完成';
        icon = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case CalibrationState.failed:
        title = '校準失敗';
        icon = Icons.error;
        iconColor = Theme.of(context).colorScheme.error;
        break;
    }

    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final scale = _state == CalibrationState.calibrating
                ? 1.0 + 0.1 * _pulseController.value
                : 1.0;
            return Transform.scale(
              scale: scale,
              child: Icon(icon, size: 48, color: iconColor),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case CalibrationState.instructions:
        return Column(
          children: [
            Text(
              '為了更好地偵測孩子的聲音，我們需要先測量環境噪音。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildInstructionItem(Icons.volume_off, '請保持安靜'),
                  const SizedBox(height: 8),
                  _buildInstructionItem(Icons.timer, '只需 2 秒鐘'),
                ],
              ),
            ),
          ],
        );

      case CalibrationState.calibrating:
        return Column(
          children: [
            Text(
              '請保持安靜...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _progress,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );

      case CalibrationState.completed:
        return Column(
          children: [
            Text(
              '環境噪音已校準',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            if (_result != null) ...[
              Text(
                '噪音等級：${_result!.noiseFloorDb.toStringAsFixed(1)} dB',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
              ),
              const SizedBox(height: 8),
              _buildEnvironmentQuality(_result!),
            ],
          ],
        );

      case CalibrationState.failed:
        return Column(
          children: [
            Icon(
              Icons.warning,
              size: 32,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '校準過程中發生錯誤',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ],
        );
    }
  }

  Widget _buildInstructionItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }

  Widget _buildEnvironmentQuality(CalibrationResult result) {
    String label;
    Color color;
    IconData icon;

    if (result.isQuietEnvironment) {
      label = '環境安靜，適合互動';
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (result.isNoisyEnvironment) {
      label = '環境較吵，可能影響偵測';
      color = Colors.orange;
      icon = Icons.warning;
    } else {
      label = '環境適中';
      color = Colors.blue;
      icon = Icons.info;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildActions() {
    switch (_state) {
      case CalibrationState.instructions:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: widget.onCancel,
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: _startCalibration,
              icon: const Icon(Icons.play_arrow),
              label: const Text('開始校準'),
            ),
          ],
        );

      case CalibrationState.calibrating:
        return TextButton(
          onPressed: () {
            _audioSubscription?.cancel();
            _calibrationService.cancelCalibration();
            widget.onCancel();
          },
          child: const Text('取消'),
        );

      case CalibrationState.completed:
        return const SizedBox.shrink(); // Auto-proceeds

      case CalibrationState.failed:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: widget.onCancel,
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: _retry,
              child: const Text('重試'),
            ),
          ],
        );
    }
  }
}

/// Shows the calibration dialog.
///
/// Returns the calibration result if successful, null if cancelled.
Future<CalibrationResult?> showCalibrationDialog({
  required BuildContext context,
  required Stream<List<int>> audioStream,
}) {
  return showDialog<CalibrationResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => NoiseCalibrationDialog(
      audioStream: audioStream,
      onCalibrationComplete: (result) => Navigator.of(context).pop(result),
      onCancel: () => Navigator.of(context).pop(),
    ),
  );
}
