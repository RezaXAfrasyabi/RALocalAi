/*
 * Copyright (C) 2026 Reza Afrasyabi afrasyabireza50@gmail.com
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// One step in a coach marks / spotlight tutorial.
class CoachMarkStep {
  /// Creates a tutorial step.
  const CoachMarkStep({
    required this.title,
    required this.subtitle,
  });

  /// Short headline shown in the tooltip.
  final String title;

  /// Supporting description shown under [title].
  final String subtitle;
}

/// Full-screen overlay with a spotlight (hole) on a target [Rect] and a
/// tooltip card. Used for app walkthrough / feature discovery.
class CoachMarksOverlay extends StatefulWidget {
  const CoachMarksOverlay({
    super.key,
    required this.stepRects,
    required this.steps,
    required this.onComplete,
  });

  /// Target rectangles to highlight (one per step).
  final List<Rect> stepRects;

  /// Step metadata (title/subtitle). Must align with [stepRects].
  final List<CoachMarkStep> steps;

  /// Called when the last step is completed.
  final VoidCallback onComplete;

  @override
  State<CoachMarksOverlay> createState() => _CoachMarksOverlayState();
}

class _CoachMarksOverlayState extends State<CoachMarksOverlay> {
  int _currentIndex = 0;

  void _next() {
    if (_currentIndex >= widget.steps.length - 1) {
      widget.onComplete();
      return;
    }
    setState(() => _currentIndex++);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stepRects.isEmpty ||
        widget.steps.isEmpty ||
        _currentIndex >= widget.stepRects.length ||
        _currentIndex >= widget.steps.length) {
      return const SizedBox.shrink();
    }

    final rect = widget.stepRects[_currentIndex];
    final step = widget.steps[_currentIndex];
    final isLast = _currentIndex >= widget.steps.length - 1;
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dark overlay with spotlight hole
          CustomPaint(
            size: size,
            painter: _SpotlightPainter(
              spotlightRect: rect,
              overlayColor: Colors.black.withValues(alpha: 0.65),
              borderRadius: 12,
            ),
          ),
          // Tooltip popover near the spotlight
          _TooltipCard(
            rect: rect,
            title: step.title,
            subtitle: step.subtitle,
            isLast: isLast,
            onPrimary: _next,
            onComplete: widget.onComplete,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.spotlightRect,
    required this.overlayColor,
    required this.borderRadius,
  });

  final Rect spotlightRect;
  final Color overlayColor;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          spotlightRect,
          Radius.circular(borderRadius),
        ),
      );
    final path = Path.combine(PathOperation.difference, fullPath, holePath);
    canvas.drawPath(path, Paint()..color = overlayColor);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      old.spotlightRect != spotlightRect || old.overlayColor != overlayColor;
}

class _TooltipCard extends StatelessWidget {
  const _TooltipCard({
    required this.rect,
    required this.title,
    required this.subtitle,
    required this.isLast,
    required this.onPrimary,
    required this.onComplete,
    required this.colorScheme,
  });

  final Rect rect;
  final String title;
  final String subtitle;
  final bool isLast;
  final VoidCallback onPrimary;
  final VoidCallback onComplete;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    const cardWidth = 280.0;
    const padding = 20.0;

    // Prefer tooltip above spotlight if there's room, else below
    final spaceAbove = rect.top;
    final spaceBelow = size.height - rect.bottom;
    final showAbove = spaceAbove >= 160 || spaceAbove >= spaceBelow;

    double top;
    if (showAbove) {
      top = rect.top - 12 - 140; // card height ~140, gap 12
    } else {
      top = rect.bottom + 12;
    }
    top = top.clamp(padding, size.height - 180);
    final left = (size.width - cardWidth) / 2;
    final leftClamped = left.clamp(padding, size.width - cardWidth - padding);

    return Positioned(
      left: leftClamped,
      top: top,
      width: cardWidth,
      child: Material(
        elevation: 8,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  height: 1.4,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isLast)
                    FilledButton(
                      onPressed: onComplete,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Got it',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    )
                  else
                    FilledButton(
                      onPressed: onPrimary,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Next',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
