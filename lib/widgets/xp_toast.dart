import 'package:flutter/material.dart';

/// Show a small floating "+N XP" toast near the top of the screen.
/// Auto-dismisses after ~1.6 seconds.
///
/// Usage:
///   showXpToast(context, amount: 50);
///   showXpToast(context, amount: 50, icon: Icons.local_fire_department);
void showXpToast(
  BuildContext context, {
  required int amount,
  Color? color,
  IconData? icon,
}) {
  if (amount <= 0) return;

  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => _XpToastOverlay(
      amount: amount,
      color: color,
      icon: icon,
      onDone: () => entry.remove(),
    ),
  );

  overlay.insert(entry);
}

class _XpToastOverlay extends StatefulWidget {
  final int amount;
  final Color? color;
  final IconData? icon;
  final VoidCallback onDone;

  const _XpToastOverlay({
    required this.amount,
    required this.onDone,
    this.color,
    this.icon,
  });

  @override
  State<_XpToastOverlay> createState() => _XpToastOverlayState();
}

class _XpToastOverlayState extends State<_XpToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDone();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = widget.color ?? scheme.primary;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 24,
      right: 24,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            final slide = t < 0.15 ? -20.0 * (1 - (t / 0.15)) : 0.0;
            final opacity = t > 0.75 ? 1.0 - ((t - 0.75) / 0.25) : 1.0;

            return Transform.translate(
              offset: Offset(0, slide),
              child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
            );
          },
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon ?? Icons.auto_awesome,
                      size: 18,
                      color: accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+${widget.amount} XP',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: accent,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
