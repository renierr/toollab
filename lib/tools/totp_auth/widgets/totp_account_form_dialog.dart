import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../totp.dart';
import '../totp_account.dart';

class TotpAccountFormDialog extends StatefulWidget {
  final TotpAccount? initial;

  const TotpAccountFormDialog({super.key, this.initial});

  static Future<TotpAccount?> show(
    BuildContext context, {
    TotpAccount? initial,
  }) {
    return showDialog<TotpAccount>(
      context: context,
      builder: (_) => TotpAccountFormDialog(initial: initial),
    );
  }

  @override
  State<TotpAccountFormDialog> createState() => _TotpAccountFormDialogState();
}

class _TotpAccountFormDialogState extends State<TotpAccountFormDialog> {
  late final TextEditingController _linkCtrl;
  late final TextEditingController _issuerCtrl;
  late final TextEditingController _accountCtrl;
  late final TextEditingController _secretCtrl;
  late final TextEditingController _periodCtrl;
  late final TextEditingController _counterCtrl;

  late TotpAlgorithm _algorithm;
  late int _digits;
  late TotpType _type;
  late bool _advanced;
  bool _hideSecret = true;
  String? _error;
  String? _appliedLink;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _linkCtrl = TextEditingController();
    _issuerCtrl = TextEditingController(text: initial?.issuer ?? '');
    _accountCtrl = TextEditingController(text: initial?.accountName ?? '');
    _secretCtrl = TextEditingController(text: initial?.secret ?? '');
    _periodCtrl = TextEditingController(text: '${initial?.period ?? 30}');
    _counterCtrl = TextEditingController(text: '${initial?.counter ?? 0}');
    _algorithm = initial?.algorithm ?? TotpAlgorithm.sha1;
    _digits = initial?.digits ?? 6;
    _type = initial?.type ?? TotpType.totp;
    _advanced =
        initial != null &&
        (initial.type == TotpType.hotp ||
            initial.algorithm != TotpAlgorithm.sha1 ||
            initial.digits != 6 ||
            initial.period != 30);
  }

  @override
  void dispose() {
    _linkCtrl.dispose();
    _issuerCtrl.dispose();
    _accountCtrl.dispose();
    _secretCtrl.dispose();
    _periodCtrl.dispose();
    _counterCtrl.dispose();
    super.dispose();
  }

  void _applyUri(String value) {
    final trimmed = value.trim();
    if (!trimmed.toLowerCase().startsWith('otpauth://')) return;
    if (trimmed == _appliedLink) return;
    final parts = Totp.parseOtpAuthUri(trimmed);
    if (parts == null) return;
    _appliedLink = trimmed;
    setState(() {
      _issuerCtrl.text = parts.issuer;
      _accountCtrl.text = parts.account;
      _secretCtrl.text = parts.secret;
      _algorithm = parts.algorithm;
      _digits = parts.digits;
      _type = parts.type;
      _periodCtrl.text = '${parts.period}';
      _counterCtrl.text = '${parts.counter}';
      _error = null;
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    if (text.toLowerCase().startsWith('otpauth://')) {
      _linkCtrl.text = text;
      _applyUri(text);
      return;
    }
    if (Totp.isValidSecret(text)) {
      setState(() {
        _secretCtrl.text = Totp.normalizeSecret(text);
        _error = null;
      });
    }
  }

  void _save() {
    final l10n = AppLocalizations.of(context);
    final secret = Totp.normalizeSecret(_secretCtrl.text);
    if (!Totp.isValidSecret(secret)) {
      setState(() => _error = l10n.totpInvalidSecret);
      return;
    }
    final issuer = _issuerCtrl.text.trim();
    final account = _accountCtrl.text.trim();
    if (issuer.isEmpty && account.isEmpty) {
      setState(() => _error = l10n.totpMissingFields);
      return;
    }
    final period = int.tryParse(_periodCtrl.text.trim());
    if (_type == TotpType.totp &&
        (period == null || period < 1 || period > 3600)) {
      setState(() => _error = l10n.totpInvalidPeriod);
      return;
    }
    final counter = int.tryParse(_counterCtrl.text.trim());
    if (_type == TotpType.hotp && (counter == null || counter < 0)) {
      setState(() => _error = l10n.totpInvalidCounter);
      return;
    }

    final TotpAccount result;
    if (widget.initial == null) {
      result = TotpAccount.newAccount(
        issuer: issuer,
        accountName: account,
        secret: secret,
        algorithm: _algorithm,
        digits: _digits,
        period: _type == TotpType.totp ? period! : 30,
        type: _type,
        counter: _type == TotpType.hotp ? counter! : 0,
      );
    } else {
      result = widget.initial!.copy()
        ..issuer = issuer
        ..accountName = account
        ..secret = secret
        ..algorithm = _algorithm
        ..digits = _digits
        ..period = _type == TotpType.totp ? period! : 30
        ..type = _type
        ..counter = _type == TotpType.hotp ? counter! : 0;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final preview = _previewCode();

    return ResponsiveAlertDialog(
      title: Text(
        widget.initial == null ? l10n.totpAddAccount : l10n.totpEditAccount,
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _linkCtrl,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: l10n.totpFieldUri,
                  helperText: l10n.totpUriHelper,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: l10n.totpPaste,
                    onPressed: _paste,
                    icon: const Icon(Icons.content_paste_outlined),
                  ),
                ),
                onChanged: _applyUri,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _issuerCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.totpFieldIssuer,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _accountCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.totpFieldAccount,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _secretCtrl,
                obscureText: _hideSecret,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                  letterSpacing: 1.1,
                ),
                decoration: InputDecoration(
                  labelText: l10n.totpFieldSecret,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: l10n.totpPaste,
                    onPressed: _paste,
                    icon: const Icon(Icons.content_paste_outlined),
                  ),
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
              Row(
                children: [
                  Checkbox(
                    value: !_hideSecret,
                    visualDensity: VisualDensity.compact,
                    onChanged: (value) =>
                        setState(() => _hideSecret = !(value ?? false)),
                  ),
                  Text(l10n.totpShowSecret, style: theme.textTheme.bodySmall),
                ],
              ),
              if (preview != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text(
                        l10n.totpPreview,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        Totp.groupedCode(preview),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  initiallyExpanded: _advanced,
                  onExpansionChanged: (value) =>
                      setState(() => _advanced = value),
                  title: Text(l10n.totpAdvancedOptions),
                  children: [
                    SegmentedButton<TotpType>(
                      segments: [
                        ButtonSegment(
                          value: TotpType.totp,
                          label: Text(l10n.totpTypeTotp),
                        ),
                        ButtonSegment(
                          value: TotpType.hotp,
                          label: Text(l10n.totpTypeHotp),
                        ),
                      ],
                      selected: {_type},
                      onSelectionChanged: (selection) =>
                          setState(() => _type = selection.first),
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 168,
                          child: _EnumField<TotpAlgorithm>(
                            label: l10n.totpAlgorithm,
                            value: _algorithm,
                            items: TotpAlgorithm.values,
                            labelOf: Totp.algorithmName,
                            onChanged: (value) =>
                                setState(() => _algorithm = value),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: _EnumField<int>(
                            label: l10n.totpDigits,
                            value: _digits,
                            items: const [6, 7, 8],
                            labelOf: (value) => '$value',
                            onChanged: (value) =>
                                setState(() => _digits = value),
                          ),
                        ),
                        if (_type == TotpType.totp)
                          SizedBox(
                            width: 140,
                            child: TextField(
                              controller: _periodCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: l10n.totpPeriod,
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() => _error = null),
                            ),
                          )
                        else
                          SizedBox(
                            width: 140,
                            child: TextField(
                              controller: _counterCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: l10n.totpCounter,
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() => _error = null),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(
            widget.initial == null ? l10n.commonAdd : l10n.commonSave,
          ),
        ),
      ],
    );
  }

  String? _previewCode() {
    final secret = Totp.normalizeSecret(_secretCtrl.text);
    if (!Totp.isValidSecret(secret)) return null;
    try {
      final bytes = Totp.decodeBase32(secret);
      final code = _type == TotpType.hotp
          ? Totp.generateCounter(
              secret: bytes,
              counter: int.tryParse(_counterCtrl.text.trim()) ?? 0,
              digits: _digits,
              algorithm: _algorithm,
            )
          : Totp.generate(
              secret: bytes,
              timeSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              period: int.tryParse(_periodCtrl.text.trim()) ?? 30,
              digits: _digits,
              algorithm: _algorithm,
            );
      return Totp.formatCode(code, _digits);
    } catch (_) {
      return null;
    }
  }
}

class _EnumField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;

  const _EnumField({
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          items: [
            for (final item in items)
              DropdownMenuItem(value: item, child: Text(labelOf(item))),
          ],
          onChanged: (selected) {
            if (selected != null) onChanged(selected);
          },
        ),
      ),
    );
  }
}
