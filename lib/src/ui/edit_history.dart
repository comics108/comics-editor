import 'models.dart';

/// Стек истории отмены/повтора — снапшоты документа ([ComicsDoc.clone]).
/// Живёт в рамках одного открытого документа: [EditorController] вызывает
/// [clear] при `newDoc()`/`openRecent()`, не переживает закрытие приложения
/// (только в памяти, не сериализуется на диск).
///
/// Снапшоты — прямые deep copy через [ComicsDoc.clone], а не JSON-round-trip
/// через `comicsToCore`/`comicsFromCore`: документы, созданные `newDoc()`/
/// `openRecent()`, не имеют backing `CoreDocument` (`coreDoc` остаётся null),
/// поэтому снапшот должен работать без него.
class EditHistory {
  final List<ComicsDoc> _undoStack = [];
  final List<ComicsDoc> _redoStack = [];
  ComicsDoc? _pending;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// Вызывать ДО мутации. [snapshot] — состояние документа на момент вызова
  /// (т.е. до предстоящей мутации), обычно `doc.clone()`.
  void beginTransaction(ComicsDoc snapshot) {
    _pending = snapshot;
  }

  /// Вызывать ПОСЛЕ мутации (или после серии мутаций одного жеста).
  /// No-op, если [beginTransaction] не вызывался.
  void commitTransaction() {
    if (_pending == null) return;
    _undoStack.add(_pending!);
    _redoStack.clear();
    _pending = null;
  }

  /// [currentSnapshot] — состояние ДО отмены (кладётся в redo-стек).
  /// Возвращает снапшот, на который нужно откатиться, или null, если
  /// стек пуст.
  ComicsDoc? undo(ComicsDoc currentSnapshot) {
    if (_undoStack.isEmpty) return null;
    _redoStack.add(currentSnapshot);
    return _undoStack.removeLast();
  }

  /// [currentSnapshot] — состояние ДО повтора (кладётся в undo-стек).
  ComicsDoc? redo(ComicsDoc currentSnapshot) {
    if (_redoStack.isEmpty) return null;
    _undoStack.add(currentSnapshot);
    return _redoStack.removeLast();
  }

  /// Вызывать при открытии нового документа — история одного документа не
  /// должна протекать в другой.
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    _pending = null;
  }
}
