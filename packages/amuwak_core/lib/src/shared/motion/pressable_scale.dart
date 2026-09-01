import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// Wraps a [child] so it scales down slightly while pressed, springing back
/// on release — a tactile, premium press feedback. Owns the tap via a
/// [GestureDetector] (so it behaves correctly inside scrollables: a scroll
/// that wins the gesture arena fires `onTapCancel` and the scale releases).
///
/// Also focusable and keyboard-activatable (Enter/numpad Enter/Space), with
/// a click cursor and a visible focus outline on desktop/web — a
/// `GestureDetector` alone gives none of that, unlike `InkWell`, so it's
/// added explicitly here.
///
/// Honours the OS reduce-motion setting: when disabled, the scale stays at 1.
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;
  bool _focused = false;

  void _setPressed(bool value) {
    if (mounted && _pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final scaled = AnimatedScale(
      scale: (_pressed && !reduceMotion) ? AppMotion.pressScale : 1.0,
      duration: reduceMotion ? Duration.zero : AppMotion.fast,
      curve: AppMotion.standard,
      child: widget.child,
    );

    if (widget.onTap == null) return scaled;

    return Focus(
      canRequestFocus: true,
      onFocusChange: (focused) {
        if (mounted) setState(() => _focused = focused);
      },
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.space) {
          widget.onTap!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Semantics(
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            // A visible cue for keyboard focus — pointer users already get the
            // press-scale + hover cursor; without this, a keyboard user who
            // tabs onto a card has no indication it's focused.
            child: Container(
              decoration: _focused
                  ? BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              child: scaled,
            ),
          ),
        ),
      ),
    );
  }
}
