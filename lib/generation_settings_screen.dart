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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'providers/generation_settings_provider.dart';
import 'screens/terminal_screen.dart';
import 'utils/ai_formatter.dart';

/// UI for configuring local inference generation parameters.
///
/// This screen edits values persisted in `generationSettingsProvider` and
/// immediately writes updates when the user changes a control.
class GenerationSettingsScreen extends ConsumerStatefulWidget {
  const GenerationSettingsScreen({super.key});

  @override
  ConsumerState<GenerationSettingsScreen> createState() =>
      _GenerationSettingsScreenState();
}

class _GenerationSettingsScreenState
    extends ConsumerState<GenerationSettingsScreen> {
  late double _temperature;
  late double _topP;
  late int _topK;
  late int _maxTokens;
  late double _repeatPenalty;
  late int _contextSize;
  ModelType? _promptFormat;

  @override
  void initState() {
    super.initState();
    final s = ref.read(generationSettingsProvider);
    _temperature = s.temperature;
    _topP = s.topP;
    _topK = s.topK;
    _maxTokens = s.maxTokens;
    _repeatPenalty = s.repeatPenalty;
    _contextSize = s.contextSize;
    _promptFormat = s.promptFormat;
  }

  void _save() {
    ref.read(generationSettingsProvider.notifier).update(
          GenerationSettings(
            temperature: _temperature,
            topP: _topP,
            topK: _topK,
            maxTokens: _maxTokens,
            repeatPenalty: _repeatPenalty,
            contextSize: _contextSize,
            promptFormat: _promptFormat,
          ),
        );
  }

  /// Human-readable label for a prompt format [ModelType].
  static String _formatLabel(ModelType t) {
    switch (t) {
      case ModelType.llama3:
        return 'Llama 3 / DeepSeek';
      case ModelType.chatml:
        return 'ChatML (Qwen, Mistral, etc.)';
      case ModelType.alpaca:
        return 'Alpaca';
      case ModelType.vicuna:
        return 'Vicuna / Llama 2';
      case ModelType.gemma:
        return 'Gemma';
    }
  }

  /// Small helper for consistent “hint” text styling.
  Widget _hint(BuildContext context, String text) {
    final color = Theme.of(context).colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final secondaryColor = colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Generation settings',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Context size (load-time; takes effect on next model load)
          Text(
            'Context size',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: secondaryColor,
            ),
          ),
          DropdownButtonFormField<int>(
            value: kContextSizeOptions.contains(_contextSize)
                ? _contextSize
                : kContextSizeOptions.first,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: kContextSizeOptions
                .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => _contextSize = v);
                _save();
              }
            },
          ),
          _hint(context,
              'How much conversation the model can “see” at once. Smaller = less RAM and faster; larger = longer memory. Takes effect after you load a model.'),
          const SizedBox(height: 20),
          Text(
            'Prompt format',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: secondaryColor,
            ),
          ),
          DropdownButtonFormField<ModelType?>(
            value: _promptFormat,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              const DropdownMenuItem<ModelType?>(
                value: null,
                child: Text('Auto (from model name)'),
              ),
              ...ModelType.values.map(
                (e) => DropdownMenuItem<ModelType?>(
                  value: e,
                  child: Text(_formatLabel(e)),
                ),
              ),
            ],
            onChanged: (v) {
              setState(() => _promptFormat = v);
              _save();
            },
          ),
          _hint(context,
              'Chat template used for the model. Auto picks from the loaded model filename (e.g. Llama 3, Qwen, Gemma). Override if replies are wrong.'),
          const SizedBox(height: 20),
          Text(
            'Temperature',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: secondaryColor,
            ),
          ),
          Slider(
            value: _temperature,
            min: 0,
            max: 2,
            divisions: 20,
            label: _temperature.toStringAsFixed(1),
            onChanged: (v) => setState(() => _temperature = v),
            onChangeEnd: (_) => _save(),
          ),
          _hint(context,
              'Randomness of replies. Lower = more focused and deterministic; higher = more varied and creative.'),
          const SizedBox(height: 20),
          Text(
            'Top P',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: secondaryColor,
            ),
          ),
          Slider(
            value: _topP,
            min: 0,
            max: 1,
            divisions: 20,
            label: _topP.toStringAsFixed(2),
            onChanged: (v) => setState(() => _topP = v),
            onChangeEnd: (_) => _save(),
          ),
          _hint(context,
              'Nucleus sampling: only considers tokens whose cumulative probability is within this fraction. Lower = more focused; higher = more diversity.'),
          const SizedBox(height: 20),
          Text(
            'Top K',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: secondaryColor,
            ),
          ),
          Slider(
            value: _topK.toDouble(),
            min: 1,
            max: 100,
            divisions: 99,
            label: '$_topK',
            onChanged: (v) => setState(() => _topK = v.round()),
            onChangeEnd: (_) => _save(),
          ),
          _hint(context,
              'Limits choices to the top K most likely tokens. Lower = more deterministic; higher = more variety.'),
          const SizedBox(height: 20),
          Text(
            'Max tokens',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: secondaryColor,
            ),
          ),
          Slider(
            value: _maxTokens.toDouble(),
            min: 64,
            max: 2048,
            divisions: 31,
            label: '$_maxTokens',
            onChanged: (v) => setState(() => _maxTokens = v.round()),
            onChangeEnd: (_) => _save(),
          ),
          _hint(context,
              'Maximum length of each reply in tokens. Shorter = quicker responses; longer = more room for detailed answers.'),
          const SizedBox(height: 20),
          Text(
            'Repeat penalty',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: secondaryColor,
            ),
          ),
          Slider(
            value: _repeatPenalty,
            min: 1,
            max: 2,
            divisions: 20,
            label: _repeatPenalty.toStringAsFixed(1),
            onChanged: (v) => setState(() => _repeatPenalty = v),
            onChangeEnd: (_) => _save(),
          ),
          _hint(context,
              'Discourages repeating the same words or phrases. Higher = less repetition; too high can make output awkward.'),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _temperature = 0.7;
                _topP = 0.9;
                _topK = 40;
                _maxTokens = 512;
                _repeatPenalty = 1.1;
                _contextSize = 2048;
                _promptFormat = null;
              });
              ref.read(generationSettingsProvider.notifier).update(
                    const GenerationSettings(),
                  );
            },
            icon: const Icon(Icons.restore_rounded, size: 20),
            label: Text(
              'Set as default settings',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TerminalScreen(),
                ),
              );
            },
            icon: const Icon(Icons.terminal, size: 20),
            label: Text(
              'Terminal',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
