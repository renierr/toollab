enum TodoSwipeAction {
  none,
  complete,
  delete,
  important,
  myDay,
  tomorrow,
  nextWeek;

  static TodoSwipeAction parse(String? raw, TodoSwipeAction fallback) =>
      values.asNameMap()[raw] ?? fallback;
}
