/// Sort order applied inside a note thread.
enum NoteThreadSort { created, updated }

/// One note plus its follow-ups. Built in memory from the flat note list;
/// threading links notes by `short_id`, so a child whose parent has not been
/// pulled yet simply surfaces as an orphan root instead of disappearing.
class NoteThreadNode {
  final Map<String, dynamic> note;
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

  int get id => note['id'] as int;
  String get shortId => note['short_id'] as String;
  String? get parentShortId => note['parent_short_id'] as String?;
  int get createdAt => note['created_at'] as int? ?? 0;
  int get updatedAt => note['updated_at'] as int? ?? 0;

  int get descendantCount =>
      children.fold(0, (sum, c) => sum + 1 + c.descendantCount);

  /// Newest `updated_at` in this node's subtree — keeps an active thread from
  /// sinking in the archive just because its root text is old.
  int get threadUpdatedAt => children.fold(
    updatedAt,
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
      if (node.id == id) return node;
    }
    return null;
  }

  /// Root note of the thread [shortId] belongs to.
  NoteThreadNode? rootOf(String shortId) {
    var node = byShortId[shortId];
    if (node == null) return null;
    final seen = <String>{};
    while (seen.add(node!.shortId)) {
      final parent = byShortId[node.parentShortId];
      if (parent == null) return node;
      node = parent;
    }
    return node;
  }

  /// Ancestors of [shortId], outermost first, excluding the note itself.
  List<NoteThreadNode> ancestorsOf(String shortId) {
    final result = <NoteThreadNode>[];
    final seen = <String>{shortId};
    var parent = byShortId[byShortId[shortId]?.parentShortId];
    while (parent != null && seen.add(parent.shortId)) {
      result.insert(0, parent);
      parent = byShortId[parent.parentShortId];
    }
    return result;
  }

  static NoteThread build(
    List<Map<String, dynamic>> notes, {
    NoteThreadSort sort = NoteThreadSort.created,
  }) {
    if (notes.isEmpty) return empty;

    final byShortId = <String, Map<String, dynamic>>{};
    for (final note in notes) {
      final shortId = note['short_id'] as String?;
      if (shortId != null) byShortId[shortId] = note;
    }

    final childrenOf = <String, List<Map<String, dynamic>>>{};
    final rootNotes = <Map<String, dynamic>>[];
    final orphans = <String>{};
    for (final note in notes) {
      final parent = note['parent_short_id'] as String?;
      if (parent == null || !byShortId.containsKey(parent)) {
        if (parent != null) orphans.add(note['short_id'] as String);
        rootNotes.add(note);
      } else {
        childrenOf.putIfAbsent(parent, () => []).add(note);
      }
    }

    int compare(Map<String, dynamic> a, Map<String, dynamic> b) =>
        sort == NoteThreadSort.created
        ? (a['created_at'] as int? ?? 0).compareTo(b['created_at'] as int? ?? 0)
        : (b['updated_at'] as int? ?? 0).compareTo(
            a['updated_at'] as int? ?? 0,
          );

    final nodes = <String, NoteThreadNode>{};
    NoteThreadNode buildNode(
      Map<String, dynamic> note,
      int depth,
      Set<String> path,
    ) {
      final shortId = note['short_id'] as String;
      final rawChildren = [...?childrenOf[shortId]]..sort(compare);
      final children = [
        for (final child in rawChildren)
          if (path.add(child['short_id'] as String))
            buildNode(child, depth + 1, path),
      ];
      final node = NoteThreadNode(
        note: note,
        depth: depth,
        children: children,
        orphan: orphans.contains(shortId),
      );
      nodes[shortId] = node;
      return node;
    }

    final roots = [
      for (final note in rootNotes)
        buildNode(note, 0, {note['short_id'] as String}),
    ]..sort((a, b) => b.threadUpdatedAt.compareTo(a.threadUpdatedAt));

    return NoteThread(roots: roots, byShortId: nodes);
  }
}
