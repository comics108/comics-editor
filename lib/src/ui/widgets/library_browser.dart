import 'dart:io';

import 'package:flutter/material.dart';

import '../../ai/multimodal_paths.dart';
import '../controller.dart';
import '../theme.dart';

/// vdd-comics-editor-ai-uiux, Task 5.1: Cutting mode's Library tab -- reads
/// `work/library/{characters,environments}/<name>/*.png` directly off disk (no subprocess, no
/// manifest file -- `build_library.py` never writes one, per 03-specifications.md's Data Flow).
/// Each subdirectory is one cluster: folder name = cluster name, file count = crop count,
/// thumbnail = first file. "Insert as layer" (Task 5.2) reuses
/// [EditorController.insertLibraryItemAsLayer].
class LibraryBrowser extends StatefulWidget {
  const LibraryBrowser({super.key, required this.controller, String? Function()? resolveLibraryDir})
      : resolveLibraryDir = resolveLibraryDir ?? MultimodalPaths.resolveLibraryDir;
  final EditorController controller;

  /// Overridable for tests, so they don't scan the real, shared
  /// `apps/comics-ai/comics-multimodal/work/library/` directory -- same testability seam as
  /// `EditorController.resolveLibraryDir` (Task 3.4).
  final String? Function() resolveLibraryDir;

  @override
  State<LibraryBrowser> createState() => _LibraryBrowserState();
}

class LibraryCluster {
  const LibraryCluster({required this.name, required this.kind, required this.files});
  final String name;
  final String kind; // "character" | "background"
  final List<File> files;
}

class _LibraryBrowserState extends State<LibraryBrowser> {
  String _query = '';
  List<LibraryCluster>? _clusters;
  String? _libraryRoot;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  void _scan() {
    final root = widget.resolveLibraryDir();
    _libraryRoot = root;
    if (root == null) {
      setState(() => _clusters = []);
      return;
    }
    final clusters = <LibraryCluster>[
      ..._scanKindDir(Directory('$root/characters'), 'character'),
      ..._scanKindDir(Directory('$root/environments'), 'background'),
    ];
    setState(() => _clusters = clusters);
  }

  List<LibraryCluster> _scanKindDir(Directory dir, String kind) {
    if (!dir.existsSync()) return const [];
    final clusters = <LibraryCluster>[];
    for (final entity in dir.listSync()) {
      if (entity is! Directory) continue;
      final files = entity
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.png'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      if (files.isEmpty) continue;
      clusters.add(LibraryCluster(
        name: entity.uri.pathSegments.where((s) => s.isNotEmpty).last,
        kind: kind,
        files: files,
      ));
    }
    clusters.sort((a, b) => a.name.compareTo(b.name));
    return clusters;
  }

  @override
  Widget build(BuildContext context) {
    final clusters = _clusters;
    if (clusters == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_libraryRoot == null) {
      return const _EmptyState(
        message: 'comics-multimodal checkout not found — Library needs a local Python '
            'pipeline checkout to browse (see COMICS_MULTIMODAL_PATH).',
      );
    }
    if (clusters.isEmpty) {
      return const _EmptyState(
        message: 'Library builds up as you cut or insert items.',
      );
    }

    final filtered = _query.isEmpty
        ? clusters
        : clusters.where((c) => c.name.toLowerCase().contains(_query.toLowerCase())).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: TextField(
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 18),
              hintText: 'Search',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('No characters or environments match "$_query".',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Hs.textSecondary, fontSize: 13)),
                )
              : ListView(
                  children: [
                    _Section(
                      title: 'CHARACTERS',
                      clusters: filtered.where((c) => c.kind == 'character').toList(),
                      controller: widget.controller,
                    ),
                    _Section(
                      title: 'ENVIRONMENTS',
                      clusters: filtered.where((c) => c.kind == 'background').toList(),
                      controller: widget.controller,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.perm_media_outlined, color: Hs.textTertiary, size: 28),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center,
              style: const TextStyle(color: Hs.textSecondary, fontSize: 13)),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.clusters, required this.controller});
  final String title;
  final List<LibraryCluster> clusters;
  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    if (clusters.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Text(title, style: kSectionLabel),
        ),
        for (final cluster in clusters) _ClusterTile(cluster: cluster, controller: controller),
      ],
    );
  }
}

class _ClusterTile extends StatelessWidget {
  const _ClusterTile({required this.cluster, required this.controller});
  final LibraryCluster cluster;
  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(cluster.files.first, width: 36, height: 36, fit: BoxFit.cover,
            errorBuilder: (context, error, stack) =>
                const SizedBox(width: 36, height: 36, child: Icon(Icons.image_outlined, size: 18))),
      ),
      title: Text('${cluster.name} (${cluster.files.length})',
          style: const TextStyle(fontSize: 14)),
      trailing: TextButton(
        onPressed: () async {
          final bytes = await cluster.files.first.readAsBytes();
          await controller.insertLibraryItemAsLayer(bytes, cluster.kind);
        },
        child: const Text('Insert as layer'),
      ),
    );
  }
}
