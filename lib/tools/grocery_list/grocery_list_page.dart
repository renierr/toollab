import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'config.dart';
import 'grocery_item.dart';
import 'grocery_list_state.dart';
import 'grocery_list_sync_delegate.dart';
import 'widgets/grocery_list_input_form.dart';
import 'widgets/grocery_list_item_row.dart';
import 'widgets/grocery_list_menu.dart';

class GroceryListPage extends StatefulWidget {
  const GroceryListPage({super.key});

  @override
  State<GroceryListPage> createState() => _GroceryListPageState();
}

class _GroceryListPageState extends State<GroceryListPage> with DisposeCleanup {
  GroceryItem? _editingItem;

  @override
  void initState() {
    super.initState();

    final appState = context.read<AppState>();
    final listState = context.read<GroceryListState>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      listState.loadItems();

      if (appState.syncEnabled && appState.syncServerUrl.isNotEmpty) {
        appState
            .syncWithBackend([GroceryListSyncDelegate()])
            .then((_) {
              if (mounted) {
                listState.loadItems();
              }
            })
            .catchError((e) {
              debugPrint('[GroceryListPage] Auto-sync on open failed: $e');
            });
      }
    });
  }

  void _onEditItem(GroceryItem item) {
    setState(() {
      _editingItem = item;
    });
  }

  void _onCancelEdit() {
    setState(() {
      _editingItem = null;
    });
  }

  Future<void> _onSaveItem(String name, double amount, String unit) async {
    final listState = context.read<GroceryListState>();
    if (_editingItem != null) {
      final updated = _editingItem!.copyWith(
        name: name,
        amount: amount,
        unit: unit,
      );
      await listState.saveItem(updated);
      setState(() {
        _editingItem = null;
      });
    } else {
      final item = GroceryItem(
        shortId: '',
        name: name,
        amount: amount,
        unit: unit,
        createdAt: 0,
        updatedAt: 0,
      );
      await listState.saveItem(item);
    }
  }

  Future<void> _onToggleCheck(GroceryItem item, bool? checked) async {
    final listState = context.read<GroceryListState>();
    final updated = item.copyWith(checked: checked ?? false);
    await listState.saveItem(updated);
  }

  Future<void> _onDeleteItem(GroceryItem item) async {
    if (item.id == null) return;
    final l10n = AppLocalizations.of(context);
    final confirm = await ConfirmActionDialog.show(
      context: context,
      title: l10n.commonDelete,
      message: l10n.groceryConfirmDelete(item.name),
      confirmLabel: l10n.commonDelete,
    );

    if (confirm == true && mounted) {
      final listState = context.read<GroceryListState>();
      await listState.deleteItem(item.id!);
      if (_editingItem?.id == item.id) {
        setState(() {
          _editingItem = null;
        });
      }
    }
  }

  Future<void> _onClearBought() async {
    final listState = context.read<GroceryListState>();
    final checkedCount = listState.items.where((i) => i.checked).length;
    if (checkedCount == 0) return;

    final l10n = AppLocalizations.of(context);
    final confirm = await ConfirmActionDialog.show(
      context: context,
      title: l10n.groceryClearBought,
      message: l10n.groceryConfirmClearBought(checkedCount),
      confirmLabel: l10n.commonClear,
    );

    if (confirm == true && mounted) {
      await listState.clearCheckedItems();
    }
  }

  Future<void> _onReAddBought() async {
    final listState = context.read<GroceryListState>();
    final l10n = AppLocalizations.of(context);
    await listState.reAddCheckedItems();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.groceryAllBoughtMovedBack),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    }
  }

  Future<void> _onImport() async {
    final l10n = AppLocalizations.of(context);
    try {
      const typeGroup = XTypeGroup(
        label: 'JSON Backups',
        extensions: ['json'],
        mimeTypes: ['application/json'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: const [typeGroup]);
      if (file == null) return;

      final text = await file.readAsString();
      final data = jsonDecode(text) as Map<String, dynamic>;

      if (data['generator'] != 'browser-toolkit-grocery-list') {
        throw Exception('Invalid backup file: generator mismatch');
      }

      final items = data['items'] as List<dynamic>?;
      if (items == null) {
        throw Exception('No items found in backup file');
      }

      final itemsList = items.cast<Map<String, dynamic>>();
      if (!mounted) return;
      final state = context.read<GroceryListState>();
      final results = await state.importFromJson(itemsList);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.groceryImportComplete(
                results['imported'] ?? 0,
                results['skipped'] ?? 0,
              ),
            ),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.groceryImportFailed(e.toString())),
            backgroundColor: AppTheme.statusRed,
          ),
        );
      }
    }
  }

  Future<void> _onExport() async {
    final l10n = AppLocalizations.of(context);
    try {
      final state = context.read<GroceryListState>();
      final items = state.items;

      final itemsJson = items.map((item) {
        return {
          'shortId': item.shortId,
          'name': item.name,
          'amount': item.amount,
          'unit': item.unit,
          'checked': item.checked,
          'createdAt': item.createdAt,
          'updatedAt': item.updatedAt,
        };
      }).toList();

      final backupData = {
        'generator': 'browser-toolkit-grocery-list',
        'version': 1,
        'exportedAt': DateTime.now().millisecondsSinceEpoch,
        'items': itemsJson,
      };

      final jsonString = jsonEncode(backupData);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      final date = FormatHelper.dateTime(
        DateTime.now(),
        style: DateStyle.dateOnly,
      );

      if (!mounted) return;
      await FileSaveHelper.saveFile(
        context: context,
        suggestedName: 'grocery-list-backup-$date.json',
        bytes: bytes,
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'JSON Backups',
            extensions: ['json'],
            mimeTypes: ['application/json'],
          ),
        ],
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.groceryImportFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _onSync() async {
    final appState = context.read<AppState>();
    final listState = context.read<GroceryListState>();
    final l10n = AppLocalizations.of(context);

    try {
      final results = await appState.syncWithBackend([
        GroceryListSyncDelegate(),
      ]);
      if (results != null) {
        await listState.loadItems();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.notesSyncFinished(
                  results['pulled'] ?? 0,
                  results['pushed'] ?? 0,
                  results['deleted'] ?? 0,
                ),
              ),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.notesSyncConfigureServerUrl)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.notesSyncFailed(e.toString())),
            backgroundColor: AppTheme.statusRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appState = context.watch<AppState>();
    final listState = context.watch<GroceryListState>();
    final items = listState.items;

    final unchecked = items.where((i) => !i.checked).toList();
    final checked = items.where((i) => i.checked).toList();

    return ToolLayout(
      title: GroceryListTool.config.localizedName(l10n),
      fullscreen: false,
      actions: [
        GroceryListMenu(
          checkedCount: checked.length,
          onReAddBought: _onReAddBought,
          onClearBought: _onClearBought,
          onImport: _onImport,
          onExport: _onExport,
          onSync: _onSync,
          isSyncing: appState.isSyncing,
          hasBackend: appState.syncServerUrl.isNotEmpty,
        ),
      ],
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GroceryListInputForm(
                    editingItem: _editingItem,
                    onSave: _onSaveItem,
                    onCancelEdit: _onCancelEdit,
                  ),
                  const SizedBox(height: 8),
                  if (checked.isNotEmpty || unchecked.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        l10n.groceryItemsCount(
                          unchecked.length,
                          checked.length,
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48.0),
                      child: Center(
                        child: Text(
                          l10n.groceryNoItems,
                          style: const TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    // Standard list representation
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return GroceryListItemRow(
                          key: ValueKey(item.shortId),
                          item: item,
                          onToggle: (val) => _onToggleCheck(item, val),
                          onEdit: () => _onEditItem(item),
                          onDelete: () => _onDeleteItem(item),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
