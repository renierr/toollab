import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:intl/intl.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/collapsible_section.dart';

import '../health_database.dart';
import '../health_record.dart';
import 'health_data_tile.dart';
import 'health_empty_state.dart';

class HealthAllDataPage extends StatefulWidget {
  const HealthAllDataPage({super.key});

  @override
  State<HealthAllDataPage> createState() => _HealthAllDataPageState();
}

class _HealthAllDataPageState extends State<HealthAllDataPage> {
  final _scrollController = ScrollController();
  final _records = <HealthRecord>[];
  var _isLoading = true;
  var _isFetchingMore = false;
  var _hasMore = true;
  var _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scrollController.offset > 400;
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
    if (_scrollController.position.extentAfter < 300 &&
        !_isFetchingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isFetchingMore || !_hasMore) return;
    setState(() => _isFetchingMore = true);
    try {
      final page = await HealthDatabase.instance.recordsPage(
        offset: _records.length,
      );
      if (!mounted) return;
      setState(() {
        _records.addAll(page);
        _hasMore = page.length == 100;
        _isLoading = false;
      });
    } catch (e) {
      errorLog('[HealthAllDataPage] Load error: $e');
    } finally {
      if (mounted) setState(() => _isFetchingMore = false);
    }
  }

  List<MapEntry<String, List<HealthRecord>>> _groupedByMonth(
    BuildContext context,
  ) {
    final locale = Localizations.localeOf(context).toString();
    final formatter = DateFormat.yMMMM(locale);
    final map = <String, List<HealthRecord>>{};

    final sortedRecords = List<HealthRecord>.from(_records)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    for (final record in sortedRecords) {
      final date = DateTime.fromMillisecondsSinceEpoch(record.startTime);
      final monthKey = formatter.format(date);
      (map[monthKey] ??= []).add(record);
    }
    return map.entries.toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final monthGroups = _groupedByMonth(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthDashboardAllData)),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton.small(
              tooltip: 'Scroll to top',
              onPressed: () {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              child: const Icon(Icons.arrow_upward_rounded),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
          ? const HealthEmptyState()
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: monthGroups.length + (_isFetchingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == monthGroups.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final group = monthGroups[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MonthGroupSection(
                    title: group.key,
                    records: group.value,
                    initiallyExpanded: index == 0,
                    hasMoreDatabasePages: _hasMore,
                    onLoadMoreDatabasePages: _loadMore,
                  ),
                );
              },
            ),
    );
  }
}

class _MonthGroupSection extends StatefulWidget {
  final String title;
  final List<HealthRecord> records;
  final bool initiallyExpanded;
  final bool hasMoreDatabasePages;
  final VoidCallback onLoadMoreDatabasePages;

  const _MonthGroupSection({
    required this.title,
    required this.records,
    required this.initiallyExpanded,
    required this.hasMoreDatabasePages,
    required this.onLoadMoreDatabasePages,
  });

  @override
  State<_MonthGroupSection> createState() => _MonthGroupSectionState();
}

class _MonthGroupSectionState extends State<_MonthGroupSection> {
  var _visibleCount = 50;

  void _showMore() {
    setState(() {
      _visibleCount += 100;
    });
    if (_visibleCount >= widget.records.length && widget.hasMoreDatabasePages) {
      widget.onLoadMoreDatabasePages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleRecords = widget.records.take(_visibleCount).toList();
    final remainingInGroup = widget.records.length - visibleRecords.length;
    final showButton = remainingInGroup > 0 || widget.hasMoreDatabasePages;

    return CollapsibleSection(
      icon: Icons.calendar_month_outlined,
      title: '${widget.title} (${widget.records.length})',
      initiallyExpanded: widget.initiallyExpanded,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: [
            ...visibleRecords.map((record) => HealthDataTile(record: record)),
            if (showButton)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextButton.icon(
                  onPressed: _showMore,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    remainingInGroup > 0
                        ? 'Show 100 more ($remainingInGroup remaining)'
                        : 'Load more records...',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
