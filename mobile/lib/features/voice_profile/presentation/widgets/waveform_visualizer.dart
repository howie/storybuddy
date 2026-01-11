import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Widget that visualizes audio waveform from amplitude stream.
class WaveformVisualizer extends StatefulWidget {
  const WaveformVisualizer({
    required this.amplitudeStream,
    this.barCount = 30,
    this.barWidth = 4.0,
    this.barSpacing = 2.0,
    this.minBarHeight = 4.0,
    this.maxBarHeight = 60.0,
    this.activeColor,
    this.inactiveColor,
    this.isRecording = true,
    super.key,
  });

  final Stream<double>? amplitudeStream;
  final int barCount;
  final double barWidth;
  final double barSpacing;
  final double minBarHeight;
  final double maxBarHeight;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool isRecording;

  @override
  State<WaveformVisualizer> createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<WaveformVisualizer>
    with SingleTickerProviderStateMixin {
  late List<double> _amplitudes;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _amplitudes = List.filled(widget.barCount, 0);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _listenToAmplitude();
  }

  void _listenToAmplitude() {
    widget.amplitudeStream?.listen((amplitude) {
      if (mounted && widget.isRecording) {
        setState(() {
          // Shift amplitudes left
          for (var i = 0; i < _amplitudes.length - 1; i++) {
            _amplitudes[i] = _amplitudes[i + 1];
          }
          // Add new amplitude at the end
          _amplitudes[_amplitudes.length - 1] = amplitude;
        });
      }
    });
  }

  @override
  void didUpdateWidget(WaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amplitudeStream != widget.amplitudeStream) {
      _listenToAmplitude();
    }
    if (!widget.isRecording) {
      // Fade out bars when not recording
      _amplitudes = List.filled(widget.barCount, 0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = widget.activeColor ?? theme.colorScheme.primary;
    final inactiveColor =
        widget.inactiveColor ?? theme.colorScheme.surfaceContainerHighest;

    return SizedBox(
      height: widget.maxBarHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.barCount, (index) {
          final amplitude = _amplitudes[index];
          final barHeight = widget.minBarHeight +
              (widget.maxBarHeight - widget.minBarHeight) * amplitude;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 50),
            margin: EdgeInsets.symmetric(horizontal: widget.barSpacing / 2),
            width: widget.barWidth,
            height: barHeight,
            decoration: BoxDecoration(
              color: amplitude > 0 ? activeColor : inactiveColor,
              borderRadius: BorderRadius.circular(widget.barWidth / 2),
            ),
          );
        }),
      ),
    );
  }
}

/// Static waveform display for recorded audio preview.
class StaticWaveform extends StatelessWidget {
  const StaticWaveform({
    required this.amplitudes,
    this.barCount = 30,
    this.barWidth = 4.0,
    this.barSpacing = 2.0,
    this.minBarHeight = 4.0,
    this.maxBarHeight = 60.0,
    this.color,
    this.progress = 0.0,
    this.progressColor,
    super.key,
  });

  final List<double> amplitudes;
  final int barCount;
  final double barWidth;
  final double barSpacing;
  final double minBarHeight;
  final double maxBarHeight;
  final Color? color;
  final double progress;
  final Color? progressColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = color ?? theme.colorScheme.surfaceContainerHighest;
    final playedColor = progressColor ?? theme.colorScheme.primary;

    // Resample amplitudes to match bar count
    final resampledAmplitudes = _resampleAmplitudes(amplitudes, barCount);
    final progressIndex = (progress * barCount).floor();

    return SizedBox(
      height: maxBarHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(barCount, (index) {
          final amplitude = resampledAmplitudes[index];
          final barHeight =
              minBarHeight + (maxBarHeight - minBarHeight) * amplitude;
          final isPlayed = index <= progressIndex;

          return Container(
            margin: EdgeInsets.symmetric(horizontal: barSpacing / 2),
            width: barWidth,
            height: barHeight,
            decoration: BoxDecoration(
              color: isPlayed ? playedColor : baseColor,
              borderRadius: BorderRadius.circular(barWidth / 2),
            ),
          );
        }),
      ),
    );
  }

  List<double> _resampleAmplitudes(List<double> source, int targetCount) {
    if (source.isEmpty) {
      return List.filled(targetCount, 0);
    }

    if (source.length == targetCount) {
      return source;
    }

    final result = <double>[];
    final ratio = source.length / targetCount;

    for (var i = 0; i < targetCount; i++) {
      final startIndex = (i * ratio).floor();
      final endIndex = math.min(((i + 1) * ratio).floor(), source.length);

      if (startIndex >= source.length) {
        result.add(0);
      } else {
        // Average amplitude in this segment
        var sum = 0.0;
        var count = 0;
        for (var j = startIndex; j < endIndex; j++) {
          sum += source[j];
          count++;
        }
        result.add(count > 0 ? sum / count : 0.0);
      }
    }

    return result;
  }
}
