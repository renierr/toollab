import 'package:tool_lab/tools/notes/note.dart';

/// Sort order applied inside a note thread.
enum NoteThreadSort { created, updated }

/// One note plus its follow-ups. Built in memory from the flat note list;
/// threading links notes by `short_id`, so a child whose parent has not been
/// pulled yet simply surfaces as an orphan root instead of disappearing.
class NoteThreadNode {
  final Note note;
  final int depth;
  final List<NoteThreadNode> children;

  /// Child whose declared parent is missing from the active note set.
  final bool orphan;

  NoteThreadNode({
    required this.note,
    required this.depth,
    required this.children,
    this.orphan = false,
  });

  int get descendantCount =>
      children.fold(0, (sum, c) => sum + 1 + c.descendantCount);

  /// Newest `updated_at` in this node's subtree — keeps an active thread from
  /// sinking in the archive just because its root text is old.
  int get threadUpdatedAt => children.fold(
    note.updatedAt,
    (latest, c) => c.threadUpdatedAt > latest ? c.threadUpdatedAt : latest,
  );

  /// This node and all descendants, depth first.
  List<NoteThreadNode> flatten() => [
    this,
    for (final child in children) ...child.flatten(),
  ];
}

class NoteThread {
  final List<NoteThreadNode> roots;
  final Map<String, NoteThreadNode> byShortId;

  const NoteThread({required this.roots, required this.byShortId});

  static const NoteThread empty = NoteThread(roots: [], byShortId: {});

  NoteThreadNode? nodeForShortId(String? shortId) =>
      shortId == null ? null : byShortId[shortId];

  NoteThreadNode? nodeForId(int id) {
    for (final node in byShortId.values) {
      if (node.note.id == id) return node;
    }
    return null;
  }

  /// Root note of the thread [shortId] belongs to.
  NoteThreadNode? rootOf(String shortId) {
    var node = byShortId[shortId];
    if (node == null) return null;
    final seen = <String>{};
    while (seen.add(node!.note.shortId)) {
      final parent = byShortId[node.note.parentShortId];
      if (parent == null) return node;
      node = parent;
    }
    return node;
  }

  /// Ancestors of [shortId], outermost first, excluding the note itself.
  List<NoteThreadNode> ancestorsOf(String shortId) {
    final result = <NoteThreadNode>[];
    final seen = <String>{shortId};
    var parent = byShortId[byShortId[shortId]?.note.parentShortId];
    while (parent != null && seen.add(parent.note.shortId)) {
      result.insert(0, parent);
      parent = byShortId[parent.note.parentShortId];
    }
    return result;
  }

  static NoteThread build(
    List<Note> notes, {
    NoteThreadSort sort = NoteThreadSort.created,
  }) {
    if (notes.isEmpty) return empty;

    final byShortId = {for (final note in notes) note.shortId: note};

    final childrenOf = <String, List<Note>>{};
    final rootNotes = <Note>[];
    final orphans = <String>{};
    for (final note in notes) {
      final parent = note.parentShortId;
      if (parent == null || !byShortId.containsKey(parent)) {
        if (parent != null) orphans.add(note.shortId);
        rootNotes.add(note);
      } else {
        childrenOf.putIfAbsent(parent, () => []).add(note);
      }
    }

    int compare(Note a, Note b) => sort == NoteThreadSort.created
        ? a.createdAt.compareTo(b.createdAt)
        : b.updatedAt.compareTo(a.updatedAt);

    final nodes = <String, NoteThreadNode>{};
    NoteThreadNode buildNode(Note note, int depth, Set<String> path) {
      final rawChildren = [...?childrenOf[note.shortId]]..sort(compare);
      final children = [
        for (final child in rawChildren)
          if (path.add(child.shortId)) buildNode(child, depth + 1, path),
      ];
      final node = NoteThreadNode(
        note: note,
        depth: depth,
        children: children,
        orphan: orphans.contains(note.shortId),
      );
      nodes[note.shortId] = node;
      return node;
    }

    final roots = [
      for (final note in rootNotes) buildNode(note, 0, {note.shortId}),
    ]..sort((a, b) => b.threadUpdatedAt.compareTo(a.threadUpdatedAt));

    return NoteThread(roots: roots, byShortId: nodes);
  }
}
