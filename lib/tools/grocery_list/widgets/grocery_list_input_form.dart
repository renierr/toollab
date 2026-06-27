import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import '../grocery_item.dart';
import '../grocery_list_state.dart';

class GroceryListInputForm extends StatefulWidget {
  final GroceryItem? editingItem;
  final Function(String name, double amount, String unit) onSave;
  final VoidCallback onCancelEdit;

  const GroceryListInputForm({
    super.key,
    this.editingItem,
    required this.onSave,
    required this.onCancelEdit,
  });

  @override
  State<GroceryListInputForm> createState() => _GroceryListInputFormState();
}

class _GroceryListInputFormState extends State<GroceryListInputForm>
    with DisposeCleanup {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController(text: '1');
  final _focusNode = FocusNode();
  String _selectedUnit = 'pcs';
  bool _showSuggestions = false;

  final List<String> _units = [
    'pcs',
    'kg',
    'g',
    'lb',
    'oz',
    'L',
    'ml',
    'box',
    'pack',
  ];

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
    _focusNode.addListener(_onFocusChanged);
    _updateFormValues();

    onDispose(() {
      _nameController.removeListener(_onNameChanged);
      _focusNode.removeListener(_onFocusChanged);
      _nameController.dispose();
      _amountController.dispose();
      _focusNode.dispose();
    });
  }

  @override
  void didUpdateWidget(covariant GroceryListInputForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editingItem != widget.editingItem) {
      _updateFormValues();
    }
  }

  void _onNameChanged() {
    if (_focusNode.hasFocus && _nameController.text.trim().isNotEmpty) {
      setState(() {
        _showSuggestions = true;
      });
    } else {
      setState(() {
        _showSuggestions = false;
      });
    }
  }

  void _onFocusChanged() {
    setState(() {
      _showSuggestions =
          _focusNode.hasFocus && _nameController.text.trim().isNotEmpty;
    });
  }

  void _updateFormValues() {
    if (widget.editingItem != null) {
      final item = widget.editingItem!;
      _nameController.text = item.name;
      _amountController.text = _formatAmount(item.amount);
      setState(() {
        if (_units.contains(item.unit)) {
          _selectedUnit = item.unit;
        } else {
          _selectedUnit = 'pcs';
        }
      });
    } else {
      _nameController.clear();
      _amountController.text = '1';
      setState(() {
        _selectedUnit = 'pcs';
      });
    }
  }

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.round().toString();
    }
    return amount.toString();
  }

  void _adjustAmount(double delta) {
    final current = double.tryParse(_amountController.text) ?? 1.0;
    final newValue = current + delta;
    if (newValue > 0) {
      setState(() {
        _amountController.text = _formatAmount(newValue);
      });
    }
  }

  void _handleSubmit() {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text) ?? 1.0;
    if (name.isEmpty || amount <= 0) return;

    widget.onSave(name, amount, _selectedUnit);
    _nameController.clear();
    _amountController.text = '1';
    setState(() {
      _selectedUnit = 'pcs';
      _showSuggestions = false;
    });
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = context.watch<GroceryListState>();
    final history = state.history;

    // Filter history based on search query
    final query = _nameController.text.trim().toLowerCase();
    final filteredHistory = history
        .where((name) => name.toLowerCase().contains(query))
        .toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.editingItem != null
                  ? l10n.groceryEditItem
                  : l10n.groceryAddItem,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: widget.editingItem != null
                    ? AppTheme.accentGreen
                    : AppTheme.accentTeal,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 600;

                final nameField = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        TextField(
                          controller: _nameController,
                          focusNode: _focusNode,
                          decoration: InputDecoration(
                            labelText: l10n.groceryItemName,
                            hintText: 'Milk, Bread, Eggs...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) {
                            if (isCompact) {
                              FocusScope.of(context).nextFocus();
                            } else {
                              _handleSubmit();
                            }
                          },
                        ),
                        if (_showSuggestions && filteredHistory.isNotEmpty)
                          Positioned(
                            top: 60,
                            left: 0,
                            right: 0,
                            child: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(12),
                              color: Theme.of(context).colorScheme.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.grey[800]!
                                      : Colors.grey[200]!,
                                ),
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 200,
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: filteredHistory.length,
                                  itemBuilder: (context, index) {
                                    final suggestion = filteredHistory[index];
                                    return ListTile(
                                      title: Text(suggestion),
                                      onTap: () {
                                        setState(() {
                                          _nameController.text = suggestion;
                                          _showSuggestions = false;
                                        });
                                        _focusNode.requestFocus();
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );

                final amountField = Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _adjustAmount(-1),
                        icon: const Icon(Icons.remove),
                        color: AppTheme.statusRed,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            labelText: l10n.groceryAmount,
                            labelStyle: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontSize: 12,
                            ),
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (_) => _handleSubmit(),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _adjustAmount(1),
                        icon: const Icon(Icons.add),
                        color: AppTheme.accentTeal,
                      ),
                    ],
                  ),
                );

                final unitField = DropdownButtonFormField<String>(
                  initialValue: _selectedUnit,
                  decoration: InputDecoration(
                    labelText: l10n.groceryUnit,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  items: _units.map((unit) {
                    return DropdownMenuItem<String>(
                      value: unit,
                      child: Text(unit),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedUnit = val;
                      });
                    }
                  },
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      nameField,
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(flex: 3, child: amountField),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: unitField),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (widget.editingItem != null) ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: widget.onCancelEdit,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(l10n.commonCancel),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.editingItem != null
                                    ? AppTheme.accentGreen
                                    : AppTheme.accentTeal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                widget.editingItem != null
                                    ? l10n.groceryUpdate
                                    : l10n.groceryAdd,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                } else {
                  // Wide landscape layout
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: nameField),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: amountField),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: unitField),
                      const SizedBox(width: 12),
                      Column(
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (widget.editingItem != null) ...[
                                OutlinedButton(
                                  onPressed: widget.onCancelEdit,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                      horizontal: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(l10n.commonCancel),
                                ),
                                const SizedBox(width: 8),
                              ],
                              ElevatedButton(
                                onPressed: _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: widget.editingItem != null
                                      ? AppTheme.accentGreen
                                      : AppTheme.accentTeal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                    horizontal: 24,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  widget.editingItem != null
                                      ? l10n.groceryUpdate
                                      : l10n.groceryAdd,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
