import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

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
  final _records = <HealthRecord>[];
  var _isLoading = true;
  var _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading && _records.isNotEmpty || !_hasMore) return;
    final page = await HealthDatabase.instance.recordsPage(
      typePrefix: 'health.',
      offset: _records.length,
    );
    if (!mounted) return;
    setState(() {
      _records.addAll(page);
      _hasMore = page.length == 100;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthDashboardAllData)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
          ? const HealthEmptyState()
          : NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.extentAfter < 240) _loadMore();
                return false;
              },
              child: ListView.builder(
                itemCount: _records.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) => index == _records.length
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : HealthDataTile(record: _records[index]),
              ),
            ),
    );
  }
}
