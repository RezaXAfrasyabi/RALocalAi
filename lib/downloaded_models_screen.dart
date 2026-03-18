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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'providers/app_providers.dart';
import 'providers/downloaded_models_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/model_download_provider.dart';
import 'providers/model_list_provider.dart';
import 'services/storage_permission_service.dart';

/// Lists GGUF models downloaded into the app’s shared storage folder.
///
/// Users can:
/// - Load a downloaded model into the chat runtime
/// - Delete model files from storage
class DownloadedModelsScreen extends ConsumerStatefulWidget {
  const DownloadedModelsScreen({super.key});

  @override
  ConsumerState<DownloadedModelsScreen> createState() => _DownloadedModelsScreenState();
}

class _DownloadedModelsScreenState extends ConsumerState<DownloadedModelsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await requestStoragePermissionForDownloads();
      if (!mounted) return;
      ref.invalidate(downloadedModelsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncModels = ref.watch(downloadedModelsProvider);
    final downloadState = ref.watch(modelDownloadProvider);
    final modelListState = ref.watch(modelListProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloaded models'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: asyncModels.when(
            data: (models) {
              if (models.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.download_done_rounded,
                        size: 48,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No downloaded models',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Models you download into RA_LocalAiChat will appear here.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: models.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final m = models[index];
                  final mPath = File(m.path).absolute.path;
                  final isDownloading = downloadState.status ==
                          ModelDownloadStatus.inProgress &&
                      downloadState.filePath != null &&
                      File(downloadState.filePath!).absolute.path == mPath;
                  final isLoaded = modelListState.currentPath != null &&
                      File(modelListState.currentPath!).absolute.path == mPath;

                  return Material(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: isDownloading
                          ? null
                          : () async {
                              await ref
                                  .read(chatProvider.notifier)
                                  .loadModel(m.path);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Loaded ${m.name}. You can chat now.',
                                      style: GoogleFonts.plusJakartaSans(),
                                    ),
                                  ),
                                );
                                Navigator.of(context).pop();
                              }
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isDownloading
                                  ? Icons.downloading_rounded
                                  : Icons.download_done_rounded,
                              size: 22,
                              color: isDownloading
                                  ? colorScheme.primary
                                  : colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          m.name,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurface,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isDownloading)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primaryContainer,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Downloading',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                        )
                                      else if (isLoaded)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle_rounded,
                                                size: 14,
                                                color: const Color(0xFF22C55E),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Loaded successfully',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFF15803D),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  if (isDownloading)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: downloadState.progress > 0 &&
                                                  downloadState.progress <= 1
                                              ? downloadState.progress
                                              : null,
                                          minHeight: 4,
                                        ),
                                      ),
                                    )
                                  else
                                    Text(
                                      m.sizeDisplay,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: colorScheme.outline,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (!isDownloading)
                              IconButton(
                              onPressed: () async {
                                final remove = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title:
                                        const Text('Delete downloaded model?'),
                                    content: Text(
                                      'Delete "${m.name}" from storage? This will remove the file from RA_LocalAiChat.',
                                      style: GoogleFonts.plusJakartaSans(),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFDC2626),
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (remove == true) {
                                  try {
                                    final file = File(m.path);
                                    if (await file.exists()) {
                                      await file.delete();
                                    }
                                  } catch (_) {}
                                  ref.read(modelListProvider.notifier).removeModel(m.path);
                                  final lastPath = await ref.read(lastModelPathProvider.future);
                                  if (lastPath == m.path) {
                                    await clearLastModelPath();
                                    ref.invalidate(lastModelPathProvider);
                                  }
                                  ref.invalidate(downloadedModelsProvider);
                                }
                              },
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (_, __) => Center(
              child: Text(
                'Could not list downloaded models.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: colorScheme.error,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

