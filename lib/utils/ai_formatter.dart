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

/// Prompt format type for different model families.
/// Each type uses the template the model was trained with.
enum ModelType {
  /// Llama 3, Llama 3.1, DeepSeek-V3
  llama3,

  /// Qwen, Yi, Mistral-Instruct, Hermes, Dolphin
  chatml,

  /// Older instruction-tuned models
  alpaca,

  /// Llama 2–style, Vicuna
  vicuna,

  /// Google Gemma 1 & 2
  gemma,
}

/// Builds the correct prompt prefix for the given model type so the model
/// follows the chat format it was trained with.
class AIFormatter {
  AIFormatter._();

  /// Builds a complete prompt for the given [type].
  ///
  /// Inputs:
  /// - [system]: system policy / instructions
  /// - [user]: the user message to answer
  ///
  /// Output is a single string in the template the model family expects.
  static String buildPrompt({
    required String system,
    required String user,
    required ModelType type,
  }) {
    switch (type) {
      case ModelType.llama3:
        return '''<|begin_of_text|><|start_header_id|>system<|end_header_id|>

$system<|eot_id|><|start_header_id|>user<|end_header_id|>

$user<|eot_id|><|start_header_id|>assistant<|end_header_id|>

''';

      case ModelType.chatml:
        return '''<|im_start|>system
$system<|im_end|>
<|im_start|>user
$user<|im_end|>
<|im_start|>assistant
''';

      case ModelType.alpaca:
        return '''### Instruction:
$system
$user

### Response:
''';

      case ModelType.vicuna:
        return '''SYSTEM: $system
USER: $user
ASSISTANT: ''';

      case ModelType.gemma:
        return '''<start_of_turn>user
$system
$user<end_of_turn>
<start_of_turn>model
''';
    }
  }

  /// Infers [ModelType] from model file name (or path).
  /// Uses lowercase matching; unknown names default to [ModelType.chatml].
  static ModelType inferFromModelName(String nameOrPath) {
    final name = nameOrPath.split(RegExp(r'[/\\]')).last.toLowerCase();
    if (name.contains('llama3') || name.contains('llama-3') || name.contains('deepseek')) {
      return ModelType.llama3;
    }
    if (name.contains('qwen') || name.contains('yi-') || name.contains('mistral') ||
        name.contains('hermes') || name.contains('dolphin')) {
      return ModelType.chatml;
    }
    if (name.contains('alpaca')) return ModelType.alpaca;
    if (name.contains('vicuna') || name.contains('llama2')) return ModelType.vicuna;
    if (name.contains('gemma')) return ModelType.gemma;
    // Llama (without 2/3) often means 3.x or chatml; default to llama3 for "llama"
    if (name.contains('llama')) return ModelType.llama3;
    return ModelType.chatml;
  }
}
