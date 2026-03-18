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
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// Simple “About” page with external links.
///
/// This screen is intentionally static and contains no business logic; it
/// exists to provide attribution and a place for public contact links.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static final Uri _website = Uri.parse('https://rezaafrasyabi.com');
  static final Uri _github = Uri.parse('https://github.com/RezaXAfrasyabi');
  static final Uri _instagram = Uri.parse('https://www.instagram.com/reza_o_afrasyabi/');

  /// Opens [url] in an external browser and surfaces a snackbar on failure.
  Future<void> _open(BuildContext context, Uri url) async {
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${url.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'About',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            'RA Local AI is a lightweight, offline-first chat app that runs AI models locally on your phone.\n\n'
            'You can download or import a GGUF model, tweak generation settings, and keep multiple chats saved on-device.\n\n'
            'Created by Reza Afrasyabi.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              height: 1.4,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Links',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _LinkTile(
            icon: Icons.public_rounded,
            title: 'Website',
            subtitle: 'rezaafrasyabi.com',
            onTap: () => _open(context, _website),
          ),
          const SizedBox(height: 8),
          _LinkTile(
            icon: Icons.code_rounded,
            title: 'GitHub',
            subtitle: 'github.com/RezaXAfrasyabi',
            onTap: () => _open(context, _github),
          ),
          const SizedBox(height: 8),
          _LinkTile(
            icon: Icons.camera_alt_rounded,
            title: 'Instagram',
            subtitle: 'instagram.com/reza_o_afrasyabi',
            onTap: () => _open(context, _instagram),
          ),
        ],
      ),
    );
  }
}

/// List tile used by [AboutScreen] for consistent link styling.
class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: colorScheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.open_in_new_rounded, size: 18, color: colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

