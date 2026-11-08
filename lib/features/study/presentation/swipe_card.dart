import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:recall/app/theme/app_theme.dart';
import 'package:recall/core/markdown_lite.dart';
import 'package:recall/features/decks/domain/models.dart';
import 'package:recall/features/study/domain/scheduler/models.dart';
import 'package:recall/features/study/presentation/grade_style.dart';
import 'package:recall/l10n/gen/app_localizations.dart';

/// Lets buttons and keyboard shortcuts trigger the same fly-off as a swipe.
class SwipeCardController {
  _SwipeCardState? _state;

  void fling(Grade g) => _state?._exit(g, null);
}

/// The hero card: 3D flip, finger-following drag, spring-back and fling.
class SwipeCard extends StatefulWidget {
  const SwipeCard({
    required this.card,
    required this.flipped,
    required this.canGrade,
    required this.onFlip,
    required this.onGrade,
    required this.controller,
    super.key,
    this.peek = 0,
  });

  final StudyCard card;
  final bool flipped;
  final bool canGrade;
  final VoidCallback onFlip;
  final ValueChanged<Grade> onGrade;
  final SwipeCardController controller;

  /// How many cards to hint behind this one (0..2).
  final int peek;

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

const _spring = SpringDescription(mass: 1, stiffness: 320, damping: 26);
const _flipSpring = SpringDescription(mass: 1, stiffness: 240, damping: 20);
const _exitSpring = SpringDescription(mass: 1, stiffness: 110, damping: 21);

class _SwipeCardState extends State<SwipeCard> with TickerProviderStateMixin {
  late final AnimationController _x = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _y = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _flip = AnimationController.unbounded(
    vsync: this,
    value: widget.flipped ? 1 : 0,
  );
  // Entrance scale/fade, and the fade-out used when motion is reduced.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  var _busy = false;
  var _gone = false;
  var _entered = false;
  var _size = const Size(360, 520);
  var _viewport = const Size(400, 800);
  var _threshold = 110.0;

  bool get _reduce => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewport = MediaQuery.sizeOf(context);
    if (_entered) return;
    _entered = true;
    if (_reduce) {
      _enter.value = 1;
    } else {
      _enter.forward();
    }
  }

  @override
  void didUpdateWidget(SwipeCard old) {
    super.didUpdateWidget(old);
    widget.controller._state = this;
    if (old.flipped != widget.flipped) _animateFlip(widget.flipped);
    // A failed save puts the same card back in the answer state.
    if (_gone && widget.canGrade && !old.canGrade) {
      _gone = false;
      _busy = false;
      _x.value = 0;
      _y.value = 0;
      _enter
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    widget.controller._state = null;
    _x.dispose();
    _y.dispose();
    _flip.dispose();
    _enter.dispose();
    super.dispose();
  }

  void _animateFlip(bool toBack) {
    final target = toBack ? 1.0 : 0.0;
    if (_reduce) {
      _flip.animateTo(
        target,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    } else {
      _flip.animateWith(SpringSimulation(_flipSpring, _flip.value, target, 0));
    }
  }

  // ---- drag -------------------------------------------------------------

  void _onPanStart(DragStartDetails d) {
    if (!widget.canGrade || _busy) return;
    _x.stop();
    _y.stop();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!widget.canGrade || _busy) return;
    _x.value += d.delta.dx;
    _y.value += d.delta.dy;
  }

  void _onPanEnd(DragEndDetails d) {
    if (!widget.canGrade || _busy) return;
    final v = d.velocity.pixelsPerSecond;
    final o = Offset(_x.value, _y.value);
    // Where the card would be 120ms from now: lets a flick count as intent.
    final projected = o + v * 0.12;
    final grade = gradeForOffset(projected);
    final dist = grade.direction.dx != 0
        ? projected.dx.abs()
        : projected.dy.abs();
    if (dist >= _threshold && o.distance > 24) {
      _exit(grade, v);
    } else {
      _springBack(v);
    }
  }

  void _springBack(Offset v) {
    _x.animateWith(SpringSimulation(_spring, _x.value, 0, v.dx));
    _y.animateWith(SpringSimulation(_spring, _y.value, 0, v.dy));
  }

  void _exit(Grade g, Offset? velocity) {
    if (_busy || _gone) return;
    _busy = true;
    if (_reduce) {
      unawaited(
        _enter.animateTo(0, duration: const Duration(milliseconds: 160)).then((
          _,
        ) {
          _gone = true;
          if (mounted) widget.onGrade(g);
        }),
      );
      return;
    }
    final dir = g.direction;
    final horizontal = dir.dx != 0;
    final main = horizontal ? _x : _y;
    final cross = horizontal ? _y : _x;
    final sign = horizontal ? dir.dx : dir.dy;
    final reach =
        (horizontal ? _viewport.width : _viewport.height) * 1.0 +
        (horizontal ? _size.width : _size.height);
    final v = velocity == null ? 0.0 : (horizontal ? velocity.dx : velocity.dy);
    // Always leave at a lively speed, even from a slow drag or a button.
    final v0 = sign * math.max(sign * v, 1400);
    final vCross = velocity == null
        ? 0.0
        : (horizontal ? velocity.dy : velocity.dx);

    var fired = false;
    void watch() {
      if (!fired && main.value.abs() > reach * 0.8) {
        fired = true;
        main.removeListener(watch);
        _gone = true;
        if (mounted) widget.onGrade(g);
      }
    }

    main
      ..addListener(watch)
      ..animateWith(
        SpringSimulation(_exitSpring, main.value, sign * reach, v0),
      );
    cross.animateWith(
      SpringSimulation(
        _exitSpring,
        cross.value,
        cross.value + vCross * 0.2,
        vCross,
      ),
    );
  }

  // ---- build -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final reduce = _reduce;
    return LayoutBuilder(
      builder: (context, c) {
        _size = Size(c.maxWidth, c.maxHeight);
        _threshold = math.max(90, c.maxWidth * 0.26);
        return Stack(
          alignment: Alignment.center,
          children: [
            for (var i = widget.peek; i >= 1; i--) _Peek(depth: i),
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([_x, _y, _flip, _enter]),
                builder: (context, _) => _gone && !reduce
                    ? const SizedBox.shrink()
                    : _buildCard(context, reduce),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, bool reduce) {
    final o = Offset(_x.value, _y.value);
    final target = gradeForOffset(o);
    final p = (target.direction.dx != 0 ? o.dx.abs() : o.dy.abs()) / _threshold;
    final pull = o == Offset.zero || !widget.canGrade ? 0.0 : p.clamp(0.0, 1.0);
    final tint = target.color(context);
    final tilt = (_x.value / _size.width).clamp(-1.0, 1.0) * 0.22;
    final enter = Curves.easeOutCubic.transform(_enter.value.clamp(0.0, 1.0));
    final angle = reduce ? 0.0 : _flip.value * math.pi;
    final backShowing = reduce ? _flip.value > 0.5 : angle > math.pi / 2;

    Widget face = _Face(
      card: widget.card,
      back: backShowing,
      pull: pull,
      tint: tint,
      grade: pull > 0.15 ? target : null,
    );
    if (backShowing && !reduce) {
      face = Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(math.pi),
        child: face,
      );
    }
    if (!reduce) {
      face = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0011)
          ..rotateY(angle),
        child: face,
      );
    }

    return Opacity(
      opacity: reduce ? enter : enter.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(_x.value, _y.value + (reduce ? 0 : 24 * (1 - enter))),
        child: Transform.rotate(
          angle: tilt,
          alignment: Alignment.bottomCenter,
          child: Transform.scale(
            scale: reduce ? 1 : 0.94 + 0.06 * enter,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onFlip,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: Semantics(
                button: true,
                label: backShowing
                    ? widget.card.card.back
                    : widget.card.card.front,
                onTap: widget.onFlip,
                child: SizedBox(
                  width: _size.width,
                  height: _size.height,
                  child: ColoredBox(
                    color: Colors.transparent,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: context.paper.shadow,
                            blurRadius: 30 + 14 * pull,
                            offset: Offset(0, 16 + 6 * pull),
                            spreadRadius: -10,
                          ),
                        ],
                      ),
                      child: face,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Peek extends StatelessWidget {
  const _Peek({required this.depth});
  final int depth;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: Offset(0, 12.0 * depth),
    child: Transform.scale(
      scale: 1 - 0.045 * depth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.lerp(
            context.paper.card,
            context.colors.surfaceContainerHighest,
            0.35 * depth,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: context.colors.outlineVariant),
        ),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _Face extends StatelessWidget {
  const _Face({
    required this.card,
    required this.back,
    required this.pull,
    required this.tint,
    required this.grade,
  });

  final StudyCard card;
  final bool back;
  final double pull;
  final Color tint;
  final Grade? grade;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = context.colors;
    final text = context.text;
    final c = card.card;
    final image = c.imagePath;
    final hasImage = image != null && !kIsWeb && File(image).existsSync();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.paper.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Color.lerp(scheme.outlineVariant, tint, pull)!,
          width: 1.5 + 2.5 * pull,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: ColoredBox(color: tint.withValues(alpha: 0.12 * pull)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) => Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: box.maxWidth,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasImage && !back)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.file(
                                        File(image),
                                        height: 150,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                if (back) ...[
                                  Opacity(
                                    opacity: 0.6,
                                    child: MarkdownText(
                                      c.front,
                                      style: text.bodyMedium,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    child: SizedBox(
                                      width: 48,
                                      child: Divider(
                                        thickness: 2,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                                MarkdownText(
                                  back ? c.back : c.front,
                                  style: _bodyStyle(
                                    text,
                                    back ? c.back : c.front,
                                    back,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    back ? l.swipeHint : l.tapToFlip,
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            if (grade != null)
              Positioned(
                top: 18,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: pull,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: tint,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(grade!.icon, size: 16, color: scheme.surface),
                          const SizedBox(width: 6),
                          Text(
                            grade!.label(l),
                            style: text.labelLarge?.copyWith(
                              color: scheme.surface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  TextStyle? _bodyStyle(TextTheme t, String s, bool back) {
    final short = s.length <= 60;
    if (back) return short ? t.headlineSmall : t.bodyLarge;
    return short ? t.headlineMedium : t.titleLarge;
  }
}
