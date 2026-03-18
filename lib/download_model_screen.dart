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

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/ai_model_list_item.dart';
import 'providers/model_download_provider.dart';
import 'providers/downloaded_models_provider.dart';
import 'services/device_ram_service.dart';
import 'services/storage_permission_service.dart';

/// Curated model browser + downloader for GGUF files.
///
/// This screen reads `assets/ai_list.json`, estimates device capability (RAM),
/// and helps the user download models into the app’s shared storage folder.
class DownloadModelScreen extends ConsumerStatefulWidget {
  const DownloadModelScreen({super.key});

  @override
  ConsumerState<DownloadModelScreen> createState() => _DownloadModelScreenState();
}

class _DownloadModelScreenState extends ConsumerState<DownloadModelScreen> {
  static const String _androidDownloadRoot = '/storage/emulated/0/RA_LocalAiChat';

  String? _downloadsPath;
  List<AiModelListItem> _models = [];
  double? _deviceRamGb;
  bool _loading = true;
  String? _loadError;
  bool? _hasStoragePermission;

  @override
  void initState() {
    super.initState();
    _resolveDownloadsPath();
    _loadData();
    if (Platform.isAndroid) {
      hasStoragePermissionForDownloads().then((v) {
        if (mounted) setState(() => _hasStoragePermission = v);
      });
    } else {
      _hasStoragePermission = true;
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final ram = await getDeviceRamGb();
      String jsonString;
      try {
        jsonString = await rootBundle.loadString('assets/ai_list.json');
      } catch (e) {
        jsonString = '{"models":[]}';
      }
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      final list = map['models'] as List<dynamic>? ?? [];
      final models = list
          .map((e) => AiModelListItem.fromJson(e as Map<String, dynamic>))
          .where((m) => m.name.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _deviceRamGb = ram;
        _models = models;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _resolveDownloadsPath() async {
    String path;
    if (Platform.isAndroid) {
      // Use shared device storage root for RA_LocalAiChat.
      path = _androidDownloadRoot;
    } else {
      final dir = await getDownloadsDirectory();
      final base = dir?.path ?? '';
      path = base.isEmpty ? '' : '$base/RA_LocalAiChat';
    }
    if (!mounted) return;
    setState(() {
      _downloadsPath = path;
    });
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(modelDownloadProvider);
    final downloadedAsync = ref.watch(downloadedModelsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final downloadedNames = downloadedAsync.valueOrNull
        ?.map((m) => m.name)
        .toSet() ?? <String>{};

    // When download completes, load is already done via chatProvider (same as "Use external model"). Show feedback and return to chat.
    ref.listen<ModelDownloadState>(modelDownloadProvider, (prev, next) {
      if (prev?.status != ModelDownloadStatus.completed &&
          next.status == ModelDownloadStatus.completed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Model loaded. Ready to chat.',
              style: GoogleFonts.plusJakartaSans(),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download model'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 48, color: colorScheme.error),
                          const SizedBox(height: 12),
                          Text(
                            'Could not load list',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _loadError!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: colorScheme.error),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  )
                : _models.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.list_rounded, size: 48, color: colorScheme.outline),
                            const SizedBox(height: 12),
                            Text(
                              'No models in list',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Model downloads',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Browse models that fit your device RAM. Tap a model to download it into RA_LocalAiChat storage and auto-load it for chatting.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      color: colorScheme.onSurfaceVariant,
                                      height: 1.5,
                                    ),
                                  ),
                                  if (Platform.isAndroid && _hasStoragePermission == false) ...[
                                    const SizedBox(height: 12),
                                    Material(
                                      color: colorScheme.errorContainer.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.warning_amber_rounded,
                                              size: 22,
                                              color: colorScheme.error,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Storage permission required',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w700,
                                                      color: colorScheme.onErrorContainer,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Without permission you cannot download GGUF models. Tap a model to grant access or open Settings.',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 13,
                                                      color: colorScheme.onErrorContainer,
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (_deviceRamGb != null) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.memory_rounded, color: colorScheme.primary, size: 22),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Your device: ${_deviceRamGb!.toStringAsFixed(1)} GB RAM',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.folder_rounded, color: colorScheme.primary, size: 22),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _downloadsPath == null || _downloadsPath!.isEmpty
                                                ? 'Models will be saved into the RA_LocalAiChat folder in your storage.'
                                                : 'Save to: $_downloadsPath',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              color: colorScheme.onSurface,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'RAM needed (GB) ≈ (Parameters × 0.6) + 1.5',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: colorScheme.outline,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            sliver: SliverList.builder(
                              itemCount: _models.length,
                              itemBuilder: (context, index) {
                      final model = _models[index];
                      final expectedFileName = model.ggufFile.isNotEmpty
                          ? model.ggufFile
                          : '${model.name}.gguf';
                      final isDownloaded = downloadedNames.contains(expectedFileName);
                      final isDownloading =
                          downloadState.status == ModelDownloadStatus.inProgress &&
                          downloadState.modelName == model.name;
                      final ramGb = model.ramNeededGb;
                      final compatible = _deviceRamGb != null && _deviceRamGb! >= ramGb;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: isDownloaded
                              ? const Color(0xFFDCFCE7)
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: downloadState.status ==
                                    ModelDownloadStatus.inProgress
                                ? null
                                : () async {
                                    final hasAccess = await requestStoragePermissionForDownloads();
                                    if (!context.mounted) return;
                                    setState(() => _hasStoragePermission = hasAccess);
                                    if (!hasAccess) {
                                      await showDialog<void>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          icon: Icon(
                                            Icons.warning_amber_rounded,
                                            size: 48,
                                            color: colorScheme.error,
                                          ),
                                          title: Text(
                                            'Cannot download without permission',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          content: Text(
                                            'Without storage permission you cannot download GGUF model files. '
                                            'Please allow access in Settings so models can be saved to RA_LocalAiChat.',
                                            style: GoogleFonts.plusJakartaSans(height: 1.5),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(ctx).pop(),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              onPressed: () {
                                                Navigator.of(ctx).pop();
                                                openAppSettings();
                                              },
                                              child: const Text('Open Settings'),
                                            ),
                                          ],
                                        ),
                                      );
                                      return;
                                    }
                                    // RAM warnings: won't run vs may have problems
                                    if (_deviceRamGb != null) {
                                      final deviceRam = _deviceRamGb!;
                                      if (deviceRam < ramGb) {
                                        final proceed = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            icon: Icon(
                                              Icons.error_outline_rounded,
                                              size: 48,
                                              color: colorScheme.error,
                                            ),
                                            title: Text(
                                              'This model won\'t run on your phone',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            content: Text(
                                              'Your device has ${deviceRam.toStringAsFixed(1)} GB RAM, but this model needs about ${ramGb.toStringAsFixed(1)} GB. '
                                              'The app may fail to load it or crash. Consider a smaller model, or download anyway to use on another device.',
                                              style: GoogleFonts.plusJakartaSans(height: 1.5),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(ctx).pop(false),
                                                child: const Text('Cancel'),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.of(ctx).pop(true),
                                                child: const Text('Download anyway'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (!context.mounted || proceed != true) return;
                                      } else if (deviceRam < ramGb + 1.0) {
                                        final proceed = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            icon: Icon(
                                              Icons.info_outline_rounded,
                                              size: 48,
                                              color: colorScheme.primary,
                                            ),
                                            title: Text(
                                              'This model may run slowly or be unstable',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            content: Text(
                                              'Your device has ${deviceRam.toStringAsFixed(1)} GB RAM, which is close to what this model needs (~${ramGb.toStringAsFixed(1)} GB). '
                                              'It may run slowly or become unstable. For a smoother experience, consider a smaller model.',
                                              style: GoogleFonts.plusJakartaSans(height: 1.5),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(ctx).pop(false),
                                                child: const Text('Cancel'),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.of(ctx).pop(true),
                                                child: const Text('Download anyway'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (!context.mounted || proceed != true) return;
                                      }
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor:
                                            colorScheme.errorContainer,
                                        content: Text(
                                          '[Warning] Do not close the app while the model is downloading. If you close it, the download will stop.',
                                          style: GoogleFonts.plusJakartaSans(
                                            color:
                                                colorScheme.onErrorContainer,
                                          ),
                                        ),
                                        duration:
                                            const Duration(seconds: 6),
                                      ),
                                    );
                                    ref
                                        .read(modelDownloadProvider.notifier)
                                        .startDownload(model);
                                  },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          model.displayName,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: compatible
                                              ? colorScheme.tertiaryContainer.withValues(alpha: 0.7)
                                              : colorScheme.errorContainer.withValues(alpha: 0.6),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          compatible ? 'Compatible' : 'Needs ${ramGb.toStringAsFixed(1)} GB',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: compatible
                                                ? colorScheme.onTertiaryContainer
                                                : colorScheme.onErrorContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    model.description,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        model.sizeDisplay,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: colorScheme.outline,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '~${ramGb.toStringAsFixed(1)} GB RAM',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: colorScheme.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isDownloading) ...[
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                      value: downloadState.progress > 0 &&
                                              downloadState.progress <= 1
                                          ? downloadState.progress
                                          : null,
                                    ),
                                    const SizedBox(height: 4),
                                    Builder(
                                      builder: (_) {
                                        final percent = (downloadState.progress * 100)
                                            .clamp(0, 100);
                                        final bps = downloadState.bytesPerSecond;
                                        String speedText;
                                        if (bps <= 0) {
                                          speedText = 'Calculating speed…';
                                        } else if (bps >= 1024 * 1024) {
                                          final mbps = bps / (1024 * 1024);
                                          speedText = '${mbps.toStringAsFixed(1)} MB/s';
                                        } else if (bps >= 1024) {
                                          final kbps = bps / 1024;
                                          speedText = '${kbps.toStringAsFixed(1)} KB/s';
                                        } else {
                                          speedText = '$bps B/s';
                                        }
                                        return Text(
                                          '${percent.toStringAsFixed(1)}% · $speedText',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 4),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: () {
                                          ref
                                              .read(
                                                  modelDownloadProvider.notifier)
                                              .cancel();
                                        },
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(
                                          Icons.stop_rounded,
                                          size: 16,
                                        ),
                                        label: const Text('Stop download'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}
