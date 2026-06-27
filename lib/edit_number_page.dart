import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:flag/flag.dart';
import 'custom_flag.dart';
import 'country_data.dart';
import 'models.dart';
import 'l10n.dart';
import 'main.dart' show globalSettings;

class EditNumberPage extends StatefulWidget {
  final PhoneNumberManager manager;
  final PhoneNumberItem? existingItem;

  const EditNumberPage({super.key, required this.manager, this.existingItem});

  @override
  State<EditNumberPage> createState() => _EditNumberPageState();
}

class _EditNumberPageState extends State<EditNumberPage> {
  final _formKey = GlobalKey<FormState>();
  
  late String _label;
  late TextEditingController _phoneController;
  late Country _selectedCountry;
  late int _cycleDays;
  late int _currentRemainingDays;
  late String _remindBeforeDaysStr;
  late String _remark;
  late TimeOfDay _remindTime;

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      _label = widget.existingItem!.label;
      _phoneController = TextEditingController(text: widget.existingItem!.number);
      _selectedCountry = widget.existingItem!.country;
      _cycleDays = widget.existingItem!.cycleDays;
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final exp = widget.existingItem!.expireDate;
      final expDate = DateTime(exp.year, exp.month, exp.day);
      _currentRemainingDays = expDate.difference(today).inDays;
      if (_currentRemainingDays < 0) _currentRemainingDays = 0;
      
      _remindBeforeDaysStr = widget.existingItem!.remindBeforeDays.join(', ');
      _remark = widget.existingItem!.remark;
      _remindTime = TimeOfDay(hour: widget.existingItem!.remindTimeHour, minute: widget.existingItem!.remindTimeMinute);
    } else {
      _label = '';
      _phoneController = TextEditingController();
      _selectedCountry = countriesAndRegions.first;
      _cycleDays = 180;
      _currentRemainingDays = 180;
      _remindBeforeDaysStr = '7, 3, 1';
      _remark = '';
      _remindTime = const TimeOfDay(hour: 9, minute: 0);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      List<int> parsedReminders = _remindBeforeDaysStr
          .split(',')
          .map((e) => int.tryParse(e.trim()) ?? 0)
          .where((e) => e > 0)
          .toList();
      if (parsedReminders.isEmpty) parsedReminders = [7];
      parsedReminders = parsedReminders.toSet().toList()..sort((a, b) => b.compareTo(a));

      final now = DateTime.now();
      final expireDate = now.add(Duration(days: _currentRemainingDays));

      if (widget.existingItem != null) {
        final updated = widget.existingItem!.copyWith(
          label: _label,
          number: _phoneController.text.trim(),
          country: _selectedCountry,
          expireDate: expireDate,
          cycleDays: _cycleDays,
          remindBeforeDays: parsedReminders,
          remark: _remark,
          remindTimeHour: _remindTime.hour,
          remindTimeMinute: _remindTime.minute,
        );
        widget.manager.updateItem(updated);
      } else {
        final item = PhoneNumberItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          label: _label,
          number: _phoneController.text.trim(),
          country: _selectedCountry,
          expireDate: expireDate,
          cycleDays: _cycleDays,
          remindBeforeDays: parsedReminders,
          remark: _remark,
          remindTimeHour: _remindTime.hour,
          remindTimeMinute: _remindTime.minute,
        );
        widget.manager.addItem(item);
      }
      Navigator.pop(context);
    }
  }

  void _showTimePicker(BuildContext context) {
    TimeOfDay tempTime = _remindTime;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: 320,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tr(context, 'remind_time'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _remindTime = tempTime;
                        });
                        Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(tr(context, 'save')),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: DateTime(2000, 1, 1, _remindTime.hour, _remindTime.minute),
                  onDateTimeChanged: (DateTime dateTime) {
                    tempTime = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _modernDecoration(String label, {String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      filled: true,
      fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingItem != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? tr(context, 'edit_title') : tr(context, 'add_title')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0, top: 8.0, bottom: 8.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: globalSettings.gradientIndex >= 0 ? AppGradients.presets[globalSettings.gradientIndex] : null,
                color: globalSettings.gradientIndex < 0 ? Theme.of(context).colorScheme.primary : null,
              ),
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                label: Text(tr(context, 'save'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            InkWell(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const CountryPickerModal(),
                ).then((selected) {
                  if (selected != null && selected is Country) {
                    setState(() {
                      _selectedCountry = selected;
                    });
                  }
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: _modernDecoration(tr(context, 'country')),
                child: Row(
                  children: [
                    CustomFlag(isoCode: _selectedCountry.code, height: 16, width: 24, borderRadius: 2),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_selectedCountry.name} (${_selectedCountry.dialCode})',
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.expand_more_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _phoneController,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: _modernDecoration(tr(context, 'phone'), hintText: tr(context, 'phone_hint')),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              keyboardType: TextInputType.phone,
              validator: (val) {
                if (val == null || val.trim().isEmpty) return tr(context, 'phone_empty');
                try {
                  final isoCodeStr = _selectedCountry.code;
                  final iso = IsoCode.values.firstWhere(
                    (e) => e.name == isoCodeStr,
                    orElse: () => IsoCode.CN,
                  );
                  final pn = PhoneNumber.parse(val.trim(), callerCountry: iso);
                  if (!pn.isValid(type: PhoneNumberType.mobile) && !pn.isValid(type: PhoneNumberType.fixedLine)) {
                    return tr(context, 'phone_invalid');
                  }
                } catch (e) {
                  return tr(context, 'phone_error');
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              initialValue: _label,
              decoration: _modernDecoration(tr(context, 'label'), hintText: tr(context, 'label_hint')),
              onSaved: (val) => _label = val ?? '',
              validator: (val) => val == null || val.trim().isEmpty ? tr(context, 'label_empty') : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              initialValue: _remark,
              decoration: _modernDecoration(tr(context, 'remark'), hintText: tr(context, 'remark_hint')),
              onSaved: (val) => _remark = val ?? '',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _cycleDays.toString(),
                    decoration: _modernDecoration(tr(context, 'cycle'), hintText: '180'),
                    keyboardType: TextInputType.number,
                    onSaved: (val) => _cycleDays = int.tryParse(val ?? '180') ?? 180,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return tr(context, 'required');
                      if (int.tryParse(val) == null) return tr(context, 'number_only');
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _currentRemainingDays.toString(),
                    decoration: _modernDecoration(tr(context, 'remain'), hintText: '50'),
                    keyboardType: TextInputType.number,
                    onSaved: (val) => _currentRemainingDays = int.tryParse(val ?? '180') ?? 180,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return tr(context, 'required');
                      if (int.tryParse(val) == null) return tr(context, 'number_only');
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              initialValue: _remindBeforeDaysStr,
              decoration: _modernDecoration(tr(context, 'remind_days'), hintText: '7, 3, 1'),
              onSaved: (val) => _remindBeforeDaysStr = val ?? '7',
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: () => _showTimePicker(context),
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: _modernDecoration(tr(context, 'remind_time')),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      '${_remindTime.hour.toString().padLeft(2, '0')}:${_remindTime.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 2),
                    ),
                    const Spacer(),
                    Text(
                      tr(context, 'remind_time_desc'),
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class CountryPickerModal extends StatefulWidget {
  const CountryPickerModal({super.key});

  @override
  State<CountryPickerModal> createState() => _CountryPickerModalState();
}

class _CountryPickerModalState extends State<CountryPickerModal> {
  String _searchQuery = '';
  late List<Country> _filteredList;

  @override
  void initState() {
    super.initState();
    _filteredList = countriesAndRegions;
  }

  void _filter(String query) {
    setState(() {
      _searchQuery = query.toLowerCase().trim();
      if (_searchQuery.isEmpty) {
        _filteredList = countriesAndRegions;
      } else {
        _filteredList = countriesAndRegions.where((c) {
          return c.name.toLowerCase().contains(_searchQuery) ||
                 c.code.toLowerCase().contains(_searchQuery) ||
                 c.dialCode.toLowerCase().contains(_searchQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: tr(context, 'search_country'),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              onChanged: _filter,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredList.length,
              itemBuilder: (context, index) {
                final c = _filteredList[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  leading: CustomFlag(isoCode: c.code, height: 20, width: 28, borderRadius: 3),
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  trailing: Text(c.dialCode, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                  onTap: () {
                    Navigator.pop(context, c);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
