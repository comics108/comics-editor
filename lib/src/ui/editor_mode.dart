// flows/sdd-flutter-comics Plan Task 1.3: moved verbatim out of models.dart
// when that file relocated to libs/flutter_comics -- these three are pure
// editor-UI-state (never persisted), unlike ScrollType/PreferredOrientation,
// which stayed with the model.

/// vdd-comics-editor-uiux-lettering, Task 5.1: view-only UI state (not
/// persisted -- like `EditorController.lang`, this lives entirely on the
/// controller). `edit` is today's existing workspace; `lettering` swaps the
/// left+right panes for the balloon rail + balloon editor (Phase 5).
/// vdd-comics-editor-ai-uiux: `cutting` is the third mode, added alongside `edit`/`lettering`.
/// Functional on desktop only (03-specifications.md/`02-visual.md`) -- the mode switch itself is
/// disabled on mobile (`top_bar.dart`), so `EditorController.mode` should never actually become
/// `cutting` there, but the enum value isn't platform-gated at this layer.
enum EditorMode { edit, lettering, cutting }

/// Review is orthogonal to the existing editing modes and never persisted.
enum EditorWorkspace { editor, viewer }

enum PropertiesTab { selection, document, general }

extension EditorModeLabel on EditorMode {
  String get label => switch (this) {
    EditorMode.edit => 'Edit',
    EditorMode.lettering => 'Lettering',
    EditorMode.cutting => 'Cutting',
  };
}

const kEditorModes = EditorMode.values;
