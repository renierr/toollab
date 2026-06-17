import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/qr_code/qr_content_type.dart';

/// Dynamic input form whose fields adapt to the selected [QrContentType].
/// Owns its text controllers and reports the canonical QR payload string
/// upward via [onPayloadChanged] on every edit.
class QrCreateForm extends StatefulWidget {
  final QrContentType type;
  final ValueChanged<String> onPayloadChanged;

  const QrCreateForm({
    super.key,
    required this.type,
    required this.onPayloadChanged,
  });

  @override
  State<QrCreateForm> createState() => _QrCreateFormState();
}

class _QrCreateFormState extends State<QrCreateForm> with DisposeCleanup {
  final _text = TextEditingController();
  final _url = TextEditingController();
  final _wifiSsid = TextEditingController();
  final _wifiPwd = TextEditingController();
  final _emailAddr = TextEditingController();
  final _emailSubject = TextEditingController();
  final _emailBody = TextEditingController();
  final _phone = TextEditingController();
  final _smsNumber = TextEditingController();
  final _smsMessage = TextEditingController();
  final _geoLat = TextEditingController();
  final _geoLng = TextEditingController();
  final _vcName = TextEditingController();
  final _vcPhone = TextEditingController();
  final _vcEmail = TextEditingController();
  final _vcOrg = TextEditingController();
  final _vcUrl = TextEditingController();

  QrWifiEncryption _wifiEncryption = QrWifiEncryption.wpa;
  bool _wifiHidden = false;

  List<TextEditingController> get _all => [
    _text,
    _url,
    _wifiSsid,
    _wifiPwd,
    _emailAddr,
    _emailSubject,
    _emailBody,
    _phone,
    _smsNumber,
    _smsMessage,
    _geoLat,
    _geoLng,
    _vcName,
    _vcPhone,
    _vcEmail,
    _vcOrg,
    _vcUrl,
  ];

  @override
  void initState() {
    super.initState();
    for (final c in _all) {
      c.addListener(_emit);
      onDispose(() {
        c.removeListener(_emit);
        c.dispose();
      });
    }
  }

  @override
  void didUpdateWidget(QrCreateForm old) {
    super.didUpdateWidget(old);
    if (old.type != widget.type) _emit();
  }

  void _emit() {
    widget.onPayloadChanged(_buildPayload());
  }

  String _buildPayload() {
    switch (widget.type) {
      case QrContentType.text:
        return QrPayloadBuilder.text(_text.text);
      case QrContentType.url:
        return QrPayloadBuilder.url(_url.text);
      case QrContentType.wifi:
        return QrPayloadBuilder.wifi(
          ssid: _wifiSsid.text,
          password: _wifiPwd.text,
          encryption: _wifiEncryption,
          hidden: _wifiHidden,
        );
      case QrContentType.email:
        return QrPayloadBuilder.email(
          address: _emailAddr.text,
          subject: _emailSubject.text,
          body: _emailBody.text,
        );
      case QrContentType.phone:
        return QrPayloadBuilder.phone(_phone.text);
      case QrContentType.sms:
        return QrPayloadBuilder.sms(
          number: _smsNumber.text,
          message: _smsMessage.text,
        );
      case QrContentType.geo:
        return QrPayloadBuilder.geo(
          latitude: _geoLat.text,
          longitude: _geoLng.text,
        );
      case QrContentType.vcard:
        return QrPayloadBuilder.vcard(
          name: _vcName.text,
          phone: _vcPhone.text,
          email: _vcEmail.text,
          organization: _vcOrg.text,
          url: _vcUrl.text,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _fieldsFor(l10n),
    );
  }

  List<Widget> _fieldsFor(AppLocalizations l10n) {
    switch (widget.type) {
      case QrContentType.text:
        return [
          _Field(
            controller: _text,
            label: l10n.qrFieldText,
            icon: Icons.notes_outlined,
            maxLines: 4,
          ),
        ];
      case QrContentType.url:
        return [
          _Field(
            controller: _url,
            label: l10n.qrFieldUrl,
            icon: Icons.link_outlined,
            keyboardType: TextInputType.url,
          ),
        ];
      case QrContentType.wifi:
        return [
          _Field(
            controller: _wifiSsid,
            label: l10n.qrFieldSsid,
            icon: Icons.wifi_outlined,
          ),
          if (_wifiEncryption != QrWifiEncryption.none)
            _Field(
              controller: _wifiPwd,
              label: l10n.qrFieldPassword,
              icon: Icons.password_outlined,
              obscure: true,
            ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: DropdownButtonFormField<QrWifiEncryption>(
              initialValue: _wifiEncryption,
              decoration: InputDecoration(
                labelText: l10n.qrFieldEncryption,
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: QrWifiEncryption.wpa,
                  child: Text(l10n.qrEncWpa),
                ),
                DropdownMenuItem(
                  value: QrWifiEncryption.wep,
                  child: Text(l10n.qrEncWep),
                ),
                DropdownMenuItem(
                  value: QrWifiEncryption.none,
                  child: Text(l10n.qrEncNone),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _wifiEncryption = v);
                _emit();
              },
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.qrFieldHidden),
            value: _wifiHidden,
            onChanged: (v) {
              setState(() => _wifiHidden = v);
              _emit();
            },
          ),
        ];
      case QrContentType.email:
        return [
          _Field(
            controller: _emailAddr,
            label: l10n.qrFieldEmail,
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
          ),
          _Field(
            controller: _emailSubject,
            label: l10n.qrFieldSubject,
            icon: Icons.subject_outlined,
          ),
          _Field(
            controller: _emailBody,
            label: l10n.qrFieldBody,
            icon: Icons.notes_outlined,
            maxLines: 3,
          ),
        ];
      case QrContentType.phone:
        return [
          _Field(
            controller: _phone,
            label: l10n.qrFieldPhone,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
        ];
      case QrContentType.sms:
        return [
          _Field(
            controller: _smsNumber,
            label: l10n.qrFieldPhone,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          _Field(
            controller: _smsMessage,
            label: l10n.qrFieldMessage,
            icon: Icons.sms_outlined,
            maxLines: 3,
          ),
        ];
      case QrContentType.geo:
        return [
          _Field(
            controller: _geoLat,
            label: l10n.qrFieldLatitude,
            icon: Icons.place_outlined,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
          ),
          _Field(
            controller: _geoLng,
            label: l10n.qrFieldLongitude,
            icon: Icons.place_outlined,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
          ),
        ];
      case QrContentType.vcard:
        return [
          _Field(
            controller: _vcName,
            label: l10n.qrFieldName,
            icon: Icons.person_outline,
          ),
          _Field(
            controller: _vcOrg,
            label: l10n.qrFieldOrganization,
            icon: Icons.business_outlined,
          ),
          _Field(
            controller: _vcPhone,
            label: l10n.qrFieldPhone,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          _Field(
            controller: _vcEmail,
            label: l10n.qrFieldEmail,
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
          ),
          _Field(
            controller: _vcUrl,
            label: l10n.qrFieldUrl,
            icon: Icons.link_outlined,
            keyboardType: TextInputType.url,
          ),
        ];
    }
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final bool obscure;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.obscure = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        maxLines: obscure ? 1 : maxLines,
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
