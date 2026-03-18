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

import 'package:flutter/material.dart';

import '../onboarding_screen.dart';
import 'chat_screen.dart';

/// First-run router for onboarding and tutorial UX.
///
/// Behavior:
/// - If onboarding has not been completed, shows `OnboardingScreen`.
/// - Otherwise, shows `ChatScreen` and optionally triggers a one-time tutorial
///   overlay (coach marks) after onboarding completion.
class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  bool? _hasSeenOnboarding;
  bool _showTutorial = false;

  @override
  void initState() {
    super.initState();
    hasCompletedOnboarding().then((done) {
      if (mounted) setState(() => _hasSeenOnboarding = done);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasSeenOnboarding == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }
    if (_hasSeenOnboarding!) {
      return ChatScreen(
        showTutorial: _showTutorial,
        onTutorialComplete: _showTutorial
            ? () => setState(() => _showTutorial = false)
            : null,
      );
    }
    return OnboardingScreen(
      onComplete: (showTutorial) {
        setState(() {
          _hasSeenOnboarding = true;
          _showTutorial = showTutorial;
        });
      },
    );
  }
}
