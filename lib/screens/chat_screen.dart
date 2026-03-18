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

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../about_screen.dart';
import '../download_model_screen.dart';
import '../downloaded_models_screen.dart';
import '../generation_settings_screen.dart';
import 'terminal_screen.dart';
import '../isolates/writer_isolate.dart';
import '../models/chat_message.dart';
import '../services/app_log_service.dart';
import '../providers/app_providers.dart';
import '../providers/chat_history_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/model_download_provider.dart';
import '../providers/model_list_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/device_info.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/coach_marks_overlay.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_banner.dart';
import '../widgets/typing_indicator_bubble.dart';

/// Primary chat UI for local GGUF inference.
///
/// Responsibilities:
/// - Load/import models (including Android permission and URI handling)
/// - Display chat history + streaming assistant output
/// - Provide navigation to supporting tools (downloads, settings, terminal, about)
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    this.showTutorial = false,
    this.onTutorialComplete,
  });

  /// When true, shows coach marks (spotlight) overlay on first frame.
  final bool showTutorial;

  /// Called after the tutorial overlay has been completed/dismissed.
  final VoidCallback? onTutorialComplete;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _menuKey = GlobalKey();
  final _inputKey = GlobalKey();
  String? _startupFailedModelName;
  OverlayEntry? _tutorialOverlayEntry;
  bool _tutorialShown = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _requestFileAccessPermission();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAutoLoadLastModel();
    });
    if (widget.showTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showCoachMarks());
    }
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showTutorial && !oldWidget.showTutorial && !_tutorialShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showCoachMarks());
    }
  }

  void _showCoachMarks() {
    if (!mounted || !widget.showTutorial || _tutorialShown) return;
    final menuContext = _menuKey.currentContext;
    final inputContext = _inputKey.currentContext;
    if (menuContext == null || inputContext == null) return;
    final menuBox = menuContext.findRenderObject() as RenderBox?;
    final inputBox = inputContext.findRenderObject() as RenderBox?;
    if (menuBox == null || inputBox == null) return;
    final menuOffset = menuBox.localToGlobal(Offset.zero);
    final menuRect = Rect.fromLTWH(menuOffset.dx, menuOffset.dy, menuBox.size.width, menuBox.size.height);
    final inputOffset = inputBox.localToGlobal(Offset.zero);
    final inputRect = Rect.fromLTWH(inputOffset.dx, inputOffset.dy, inputBox.size.width, inputBox.size.height);
    _tutorialShown = true;
    _tutorialOverlayEntry = OverlayEntry(
      builder: (context) => CoachMarksOverlay(
        stepRects: [menuRect, inputRect],
        steps: const [
          CoachMarkStep(
            title: 'Open the menu',
            subtitle: 'Tap here to load a model (file or import), download a model, or switch chats.',
          ),
          CoachMarkStep(
            title: 'Chat with the AI',
            subtitle: 'Type your message here and send. Load a model from the menu first.',
          ),
        ],
        onComplete: () {
          _tutorialOverlayEntry?.remove();
          _tutorialOverlayEntry = null;
          widget.onTutorialComplete?.call();
        },
      ),
    );
    Overlay.of(context).insert(_tutorialOverlayEntry!);
  }

  @override
  void dispose() {
    _tutorialOverlayEntry?.remove();
    _tutorialOverlayEntry = null;
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// If a last model path is saved and the file still exists, load it on startup.
  Future<void> _tryAutoLoadLastModel() async {
    final lastPath = await ref.read(lastModelPathProvider.future);
    if (lastPath == null || lastPath.isEmpty || !mounted) return;
    if (!File(lastPath).existsSync()) return;
    try {
      await ref.read(chatProvider.notifier).loadModel(lastPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Previous model loaded.')),
        );
      }
    } catch (_) {
      await clearLastModelPath();
      ref.invalidate(lastModelPathProvider);
      ref.read(modelListProvider.notifier).removeModel(lastPath);
      if (mounted) {
        setState(() {
          _startupFailedModelName =
              lastPath.split(RegExp(r'[\\/]+')).isNotEmpty ? lastPath.split(RegExp(r'[\\/]+')).last : lastPath;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load previous model.')),
        );
      }
    }
  }

  Future<bool> _hasFileAccess() async {
    if (!Platform.isAndroid) return true;
    final storage = await Permission.storage.status;
    if (storage.isGranted) return true;
    final photos = await Permission.photos.status;
    return photos.isGranted;
  }

  Future<void> _requestFileAccessPermission() async {
    if (!Platform.isAndroid || !mounted) return;
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    if (await _hasFileAccess()) return;

    final shouldRequest = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'File access',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'To pick a model file (.gguf) from your device, this app needs permission. '
          'Tap "Allow" on the next screen.',
          style: GoogleFonts.plusJakartaSans(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (shouldRequest != true || !mounted) return;

    var result = await Permission.storage.request();
    if (!mounted) return;
    if (!result.isGranted) result = await Permission.photos.request();
    if (!mounted) return;
    if (result.isDenied || result.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Permission denied. You can still tap "Load Model" to open the file picker.',
          ),
          action: SnackBarAction(label: 'Settings', onPressed: () => openAppSettings()),
        ),
      );
    }
  }

  /// [forceImport] true = always copy into app (Import Model). false = use external path when possible (like ChatterUI).
  Future<void> _pickAndLoadModel({bool forceImport = false}) async {
    if (Platform.isAndroid && !await _hasFileAccess()) {
      await _requestFileAccessPermission();
      if (!mounted) return;
      if (!await _hasFileAccess()) return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (!mounted) return;

    // Show loading dialog immediately so user sees feedback as soon as they select a file
    final loadingLog = ValueNotifier<List<String>>(['Preparing…']);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading model',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: ListenableBuilder(
                      listenable: loadingLog,
                      builder: (_, __) {
                        final lines = loadingLog.value;
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: lines.length,
                          itemBuilder: (_, i) {
                            final line = lines[i];
                            final isError = line.startsWith('Error:') ||
                                line.startsWith('Error ');
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${i + 1}. $line',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: isError
                                      ? colorScheme.error
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: isError
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    // Run all loading work after the next frame so the dialog is painted first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _continueModelLoad(file: file, forceImport: forceImport, loadingLog: loadingLog);
    });
  }

  /// Called after the loading dialog has had a frame to paint. Does path resolution, validation, and load.
  Future<void> _continueModelLoad({
    required PlatformFile file,
    required bool forceImport,
    required ValueNotifier<List<String>> loadingLog,
  }) async {
    void addLog(String msg) {
      if (!mounted) return;
      loadingLog.value = [...loadingLog.value, msg];
      appLogService.log(msg);
    }

    final path = file.path ?? file.xFile.path;
    if (path.isEmpty) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get file path.')),
        );
      }
      return;
    }
    if (!path.toLowerCase().endsWith('.gguf') &&
        !file.name.toLowerCase().endsWith('.gguf')) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a .gguf model file.')),
        );
      }
      return;
    }

    // ChatterUI-style: Use External Model (direct path) when possible, else Import Model (copy into app).
    String loadablePath = path;
    try {
      if (!forceImport && _canUsePathDirectly(path)) {
        loadablePath = File(path).absolute.path;
        addLog('Using external path (no copy)');
      } else {
        addLog(forceImport ? 'Importing into app…' : 'Copying file into app…');
        loadablePath = await _copyToAppDir(file, addLog);
        addLog('Copy complete ✓');
      }

      addLog('Initialising model…');
      await Future<void>.delayed(const Duration(milliseconds: 80));

      await ref
          .read(chatProvider.notifier)
          .loadModel(loadablePath)
          .timeout(
            const Duration(minutes: 5),
            onTimeout: () =>
                throw TimeoutException('Model load timed out after 5 minutes'),
          );

      final chatState = ref.read(chatProvider);
      if (chatState.error != null) {
        addLog('Error: ${chatState.error}');
        ref.read(chatProvider.notifier).clearError();
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load model: ${chatState.error}'),
              duration: const Duration(seconds: 6),
            ),
          );
        }
        return;
      }

      addLog('Ready ✓');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model loaded. You can chat now.')),
        );
      }
    } catch (e, stack) {
      addLog('Error: $e');
      ref.read(chatProvider.notifier).clearError();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 6),
          ),
        );
      }
      debugPrint('Load model error: $e\n$stack');
    }
  }

  /// True when we can load the GGUF from this path directly (Use External Model). Else we copy into app (Import Model).
  static bool _canUsePathDirectly(String path) {
    if (path.isEmpty) return false;
    if (path.startsWith('content://')) return false;
    if (path.contains('(') || path.contains(')')) return false;
    // Never use file_picker cache path: native loader may fail and cache can be cleared.
    if (path.contains('/cache/')) return false;
    final f = File(path);
    return f.existsSync();
  }

  static String _sanitizeModelFilename(String name) {
    if (name.isEmpty) return 'model.gguf';
    String s = name.replaceAll(RegExp(r'[()\[\]\s]+'), '_');
    if (!s.toLowerCase().endsWith('.gguf')) s = '$s.gguf';
    return s;
  }

  Future<String> _copyToAppDir(
    PlatformFile file,
    void Function(String) onLog,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final rawName = file.name.isNotEmpty && file.name.toLowerCase().endsWith('.gguf')
        ? file.name
        : 'model_${DateTime.now().millisecondsSinceEpoch}.gguf';
    final name = _sanitizeModelFilename(rawName);
    final destPath = '${dir.path}/$name';

    final path = file.path ?? file.xFile.path;
    final pathExists = path.isNotEmpty &&
        !path.startsWith('content://') &&
        File(path).existsSync() &&
        !path.contains('/cache/');

    if (pathExists) {
      onLog('Direct path copy…');
      return Isolate.run(() async {
        await File(path).openRead().pipe(File(destPath).openWrite());
        return destPath;
      });
    }

    // Content URI or cache path: stream via xFile → writer isolate
    onLog('Streaming copy…');

    final mainReceivePort = ReceivePort();
    final portCompleter = Completer<SendPort>();
    final resultCompleter = Completer<String>();

    mainReceivePort.listen((message) {
      if (message is SendPort) {
        if (!portCompleter.isCompleted) portCompleter.complete(message);
      } else if (message is String) {
        if (!resultCompleter.isCompleted) resultCompleter.complete(message);
      }
    });

    await Isolate.spawn(writerIsolateEntry, mainReceivePort.sendPort);
    final writerSendPort = await portCompleter.future;
    writerSendPort.send(destPath);

    // Use a longer timeout for large GGUF files (8 GB+)
    final stream = file.xFile.openRead().timeout(const Duration(minutes: 15));
    int chunkCount = 0;

    await for (final chunk in stream) {
      // Send raw chunk — no List.from() copy on main isolate
      writerSendPort.send(chunk);
      chunkCount++;

      // Log every 100 chunks and yield a frame so the UI can repaint
      if (chunkCount % 100 == 0 || chunkCount == 1) {
        onLog('Copied $chunkCount chunks…');
        // 16 ms = one frame — enough for Flutter to repaint the dialog
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
    }

    // Signal writer to flush and close
    writerSendPort.send(null);

    final resultPath = await resultCompleter.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () => throw TimeoutException('Writer isolate did not respond'),
    );
    mainReceivePort.close();
    onLog('Done — $chunkCount chunks total.');
    return resultPath;
  }

  void _send() {
    final text = _inputController.text;
    if (text.trim().isEmpty) return;
    _inputController.clear();
    ref.read(chatProvider.notifier).sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final service = ref.watch(localAiServiceProvider);
    final lastPath = ref.watch(lastModelPathProvider);
    final historyState = ref.watch(chatHistoryProvider);
    final modelListState = ref.watch(modelListProvider);

    // When current chat changes (e.g. history loaded or user switched chat), load that chat's messages
    ref.listen<ChatHistoryState>(chatHistoryProvider, (prev, next) {
      if (prev?.currentChatId != next.currentChatId) {
        ref.read(chatProvider.notifier).loadChat(next.currentChatId);
      }
    });

    // Auto-scroll to bottom when new content arrives
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colorScheme.surfaceContainerLowest,
      drawer: _buildDrawer(context, colorScheme),
      appBar: AppBar(
        leading: IconButton(
          key: widget.showTutorial ? _menuKey : null,
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: 'Menu',
        ),
        title: Text(
          historyState.currentChat?.title ?? 'RA Local AI',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        titleSpacing: 16,
        actions: [
          if (chatState.isGenerating)
            IconButton(
              onPressed: () => ref.read(chatProvider.notifier).stopGeneration(),
              icon: const Icon(Icons.stop_rounded),
              tooltip: 'Stop',
            ),
          if (_startupFailedModelName != null && !service.isReady)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.6,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_startupFailedModelName!} · model failed to load',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
            )
          else
            lastPath.when(
            data: (p) {
              final name = modelListState.currentModel?.name ?? (p != null && p.isNotEmpty ? p.split('/').last : null);
              return name != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.4,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.appBarTheme.foregroundColor?.withValues(alpha: 0.2) ?? Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: theme.appBarTheme.foregroundColor?.withValues(alpha: 0.9) ?? Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (chatState.error != null)
            ErrorBanner(
              message: chatState.error!,
              onDismiss: () => ref.read(chatProvider.notifier).clearError(),
            ),
          Expanded(
            child: chatState.messages.isEmpty &&
                    chatState.streamingContent.isEmpty
                ? EmptyState(hasModel: service.isReady)
                : Builder(
                    builder: (context) {
                      final hasStreaming =
                          chatState.streamingContent.isNotEmpty;
                      final showTypingIndicator =
                          chatState.isGenerating && !hasStreaming;
                      final extraItems =
                          (hasStreaming ? 1 : 0) + (showTypingIndicator ? 1 : 0);

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 20),
                        itemCount: chatState.messages.length + extraItems,
                        itemBuilder: (context, index) {
                          if (index < chatState.messages.length) {
                            return ChatBubble(
                                message: chatState.messages[index]);
                          }

                          var offset = index - chatState.messages.length;

                          if (hasStreaming && offset == 0) {
                            return ChatBubble(
                              message: ChatMessage(
                                id: 'streaming',
                                isUser: false,
                                content: chatState.streamingContent,
                              ),
                              isStreaming: true,
                            );
                          }

                          if (showTypingIndicator &&
                              offset == (hasStreaming ? 1 : 0)) {
                            return const TypingIndicatorBubble();
                          }

                          return const SizedBox.shrink();
                        },
                      );
                    },
                  ),
          ),
          if (chatState.isLoadingModel)
            LinearProgressIndicator(
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          Container(
            key: widget.showTutorial ? _inputKey : null,
            constraints: const BoxConstraints(maxHeight: 140),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message…',
                      ),
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      enabled: !chatState.isLoadingModel &&
                          !chatState.isGenerating,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: chatState.isLoadingModel
                          ? null
                          : (chatState.isGenerating
                              ? () => ref
                                  .read(chatProvider.notifier)
                                  .stopGeneration()
                              : _send),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          chatState.isGenerating
                              ? Icons.stop_rounded
                              : Icons.arrow_upward_rounded,
                          color: colorScheme.onPrimary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, ColorScheme colorScheme) {
    final chatState = ref.watch(chatProvider);
    final historyState = ref.watch(chatHistoryProvider);
    final modelListState = ref.watch(modelListProvider);
    final service = ref.watch(localAiServiceProvider);

    Widget sectionTitle(String text) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );

    return Drawer(
      backgroundColor: colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                'Chats',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Material(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    final newId = ref.read(chatHistoryProvider.notifier).createNewChat();
                    ref.read(chatProvider.notifier).loadChat(newId);
                    _scaffoldKey.currentState?.closeDrawer();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.add_rounded, size: 22, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          'New chat',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Consumer(
              builder: (context, ref, _) {
                final downloadState = ref.watch(modelDownloadProvider);
                if (downloadState.status != ModelDownloadStatus.inProgress ||
                    (downloadState.modelName ?? '').isEmpty) {
                  return const SizedBox.shrink();
                }
                final percent =
                    (downloadState.progress * 100).clamp(0, 100).toStringAsFixed(1);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.download_rounded,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Downloading model: ${downloadState.modelName}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: downloadState.progress > 0 &&
                                  downloadState.progress <= 1
                              ? downloadState.progress
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$percent% downloaded',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                ref
                                    .read(modelDownloadProvider.notifier)
                                    .cancel();
                              },
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 0),
                              ),
                              child: Text(
                                'Stop',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    sectionTitle('RECENT CHATS'),
                    ...historyState.chats.map((chat) {
                            final isSelected = historyState.currentChatId == chat.id;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Material(
                                color: isSelected
                                    ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                                    : colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: () {
                                    ref.read(chatHistoryProvider.notifier).setCurrentChatId(chat.id);
                                    ref.read(chatProvider.notifier).loadChat(chat.id);
                                    _scaffoldKey.currentState?.closeDrawer();
                                  },
                                  onLongPress: () async {
                                    final delete = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete chat?'),
                                        content: Text(
                                          'Remove "${chat.title}"?',
                                          style: GoogleFonts.plusJakartaSans(),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(ctx).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.of(ctx).pop(true),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: const Color(0xFFDC2626),
                                            ),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (delete == true && mounted) {
                                      ref.read(chatHistoryProvider.notifier).deleteChat(chat.id);
                                      ref.read(chatProvider.notifier).loadChat(
                                        ref.read(chatHistoryProvider).currentChatId,
                                      );
                                      _scaffoldKey.currentState?.closeDrawer();
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          size: 20,
                                          color: isSelected
                                              ? colorScheme.primary
                                              : colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            chat.title,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: isSelected
                                                  ? colorScheme.primary
                                                  : colorScheme.onSurface,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                    }),
                    sectionTitle('MODEL'),
                    Material(
                      color: service.isReady
                          ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: chatState.isLoadingModel
                            ? null
                            : () {
                                _scaffoldKey.currentState?.closeDrawer();
                                _pickAndLoadModel(forceImport: false);
                              },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              if (chatState.isLoadingModel)
                                const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF2563EB)),
                                  ),
                                )
                              else
                                Icon(
                                  Icons.folder_open_rounded,
                                  size: 22,
                                  color: service.isReady
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  chatState.isLoadingModel
                                      ? 'Loading…'
                                      : 'Use external model',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: service.isReady
                                        ? colorScheme.primary
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: chatState.isLoadingModel
                            ? null
                            : () {
                                _scaffoldKey.currentState?.closeDrawer();
                                _pickAndLoadModel(forceImport: true);
                              },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.copy_rounded,
                                size: 22,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Import model (copy into app)',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (Platform.isAndroid) ...[
                            const SizedBox(height: 8),
                            Material(
                              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                onTap: chatState.isLoadingModel
                                    ? null
                                    : () {
                                        _scaffoldKey.currentState?.closeDrawer();
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const DownloadModelScreen(),
                                          ),
                                        );
                                      },
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 14),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.download_rounded,
                                        size: 22,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Download model',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.primary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Material(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                onTap: () {
                                  _scaffoldKey.currentState?.closeDrawer();
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const DownloadedModelsScreen(),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 14),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.list_rounded,
                                        size: 22,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Downloaded models',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: service.isReady
                                  ? colorScheme.tertiaryContainer.withValues(alpha: 0.5)
                                  : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: service.isReady
                                        ? colorScheme.tertiary
                                        : colorScheme.outline,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    service.isReady ? 'Ready' : 'No model',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: service.isReady
                                          ? colorScheme.onTertiaryContainer
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                    sectionTitle('TOOLS'),
                    Material(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () {
                          _scaffoldKey.currentState?.closeDrawer();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const GenerationSettingsScreen(),
                            ),
                          );
                        },
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 14),
                                child: Row(
                                  children: [
                                    Icon(Icons.tune_rounded, size: 22, color: colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Generation settings',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Material(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: () {
                                _scaffoldKey.currentState?.closeDrawer();
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const TerminalScreen(),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 14),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.terminal,
                                      size: 22,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Terminal',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                    sectionTitle('SAVED MODELS'),
                    if (modelListState.models.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Load a model to see it here.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: colorScheme.outline,
                                ),
                              ),
                            )
                          else
                            ...modelListState.models.map((model) {
                              final isCurrent = modelListState.currentPath == model.path;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Material(
                                  color: isCurrent
                                      ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                                      : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    onTap: chatState.isLoadingModel
                                        ? null
                                        : () async {
                                            _scaffoldKey.currentState?.closeDrawer();
                                            await ref.read(chatProvider.notifier).loadModel(model.path);
                                          },
                                    onLongPress: () async {
                                      final remove = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Remove from list?'),
                                          content: Text(
                                            'Remove "${model.name}" from saved models? The file is not deleted.',
                                            style: GoogleFonts.plusJakartaSans(),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(ctx).pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.of(ctx).pop(true),
                                              child: const Text('Remove'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (remove == true && mounted) {
                                        ref.read(modelListProvider.notifier).removeModel(model.path);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.memory_rounded,
                                            size: 20,
                                            color: isCurrent ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  model.name,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: isCurrent ? colorScheme.primary : colorScheme.onSurface,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  model.sizeDisplay,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 11,
                                                    color: colorScheme.outline,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                    sectionTitle('SETTINGS'),
                    Material(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.dark_mode_rounded,
                                    size: 22,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Dark mode',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: ref.watch(themeModeProvider) == ThemeMode.dark,
                                    onChanged: (value) {
                                      ref.read(themeModeProvider.notifier).setDarkMode(value);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Material(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () {
                                _scaffoldKey.currentState?.closeDrawer();
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const AboutScreen(),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      size: 22,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'About',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    Icon(Icons.chevron_right_rounded, color: colorScheme.outline),
                                  ],
                                ),
                              ),
                            ),
                          ),
                    sectionTitle('DEVICE INFORMATION'),
                    FutureBuilder<Map<String, String>>(
                            future: loadDeviceInfo(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'Loading…',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: colorScheme.outline,
                                    ),
                                  ),
                                );
                              }
                              final info = snapshot.data!;
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    deviceInfoRow(context, 'Phone', info['phone'] ?? '—'),
                                    const SizedBox(height: 4),
                                    deviceInfoRow(context, 'CPU', info['cpu'] ?? '—'),
                                    const SizedBox(height: 4),
                                    deviceInfoRow(context, 'RAM', info['ram'] ?? '—'),
                                    const SizedBox(height: 4),
                                    deviceInfoRow(context, 'Storage', info['storage'] ?? '—'),
                                  ],
                                ),
                              );
                            },
                          ),
                    ],
                  ),
                ),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Created by Reza Afrasyabi',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        GestureDetector(
                          onTap: () {
                            final url = Uri.parse('https://rezaafrasyabi.com');
                            launchUrl(url, mode: LaunchMode.externalApplication);
                          },
                          child: Text(
                            'rezaafrasyabi.com',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
