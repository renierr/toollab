enum TodoSwipeAction {
  none,
  complete,
  delete,
  important,
  myDay;

  static TodoSwipeAction parse(String? raw, TodoSwipeAction fallback) =>
      values.asNameMap()[raw] ?? fallback;
}
