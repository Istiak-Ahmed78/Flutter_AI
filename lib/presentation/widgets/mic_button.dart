import 'package:flutter/material.dart';

class MicButton extends StatelessWidget {
  final bool isListening;
  final VoidCallback onTap;
  final AnimationController? pulseAnimation;

  const MicButton({
    super.key,
    required this.isListening,
    required this.onTap,
    this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    // If no animation is provided, use a dummy animation
    final effectiveAnimation = pulseAnimation ?? _DummyAnimation();
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: effectiveAnimation,
        builder: (context, child) {
          return Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isListening ? Colors.red : Colors.deepPurple,
              boxShadow: isListening && pulseAnimation != null
                  ? [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 20 * (pulseAnimation?.value ?? 1),
                        spreadRadius: 5 * (pulseAnimation?.value ?? 1),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              isListening ? Icons.mic : Icons.mic_none,
              color: Colors.white,
              size: 40,
            ),
          );
        },
      ),
    );
  }
}

// Complete dummy animation class with correct method signatures
class _DummyAnimation extends Animation<double> {
  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  void addStatusListener(AnimationStatusListener listener) {}

  @override
  void removeStatusListener(AnimationStatusListener listener) {}

  @override
  double get value => 1.0;

  @override
  AnimationStatus get status => AnimationStatus.completed;

  @override
  Animation<U> drive<U>(Animatable<U> child) {
    // Return a dummy animation of the requested type
    return _DummyAnimationOfType<U>();
  }

  @override
  String toStringDetails() {
    return 'dummy';
  }

  @override
  bool get isCompleted => true;

  @override
  bool get isDismissed => false;

  @override
  bool get isAnimating => false;
}

// Generic dummy animation for any type
class _DummyAnimationOfType<T> extends Animation<T> {
  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  void addStatusListener(AnimationStatusListener listener) {}

  @override
  void removeStatusListener(AnimationStatusListener listener) {}

  @override
  T get value => throw UnimplementedError('Dummy animation value should not be used');

  @override
  AnimationStatus get status => AnimationStatus.completed;

  @override
  Animation<U> drive<U>(Animatable<U> child) {
    return _DummyAnimationOfType<U>();
  }

  @override
  String toStringDetails() {
    return 'dummy_of_type';
  }

  @override
  bool get isCompleted => true;

  @override
  bool get isDismissed => false;

  @override
  bool get isAnimating => false;
}