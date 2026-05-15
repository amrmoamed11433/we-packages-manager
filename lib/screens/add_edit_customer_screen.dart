import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../models/customer_model.dart';
import '../providers/app_provider.dart';
import '../utils/validators.dart';

class AddEditCustomerScreen extends StatefulWidget {
  const AddEditCustomerScreen({
    super.key,
    required this.groupId,
    this.customerId,
  });

  final String groupId;
  final String? customerId;

  @override
  State<AddEditCustomerScreen> createState() => _AddEditCustomerScreenState();
}

class _AddEditCustomerScreenState extends State<AddEditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _gigabytesController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  Customer? _editingCustomer;
  bool _isPaid = false;
  bool _isSaving = false;

  bool get _isEditing => widget.customerId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCustomer());
  }

  void _loadCustomer() {
    if (!_isEditing) {
      return;
    }
    final provider = context.read<AppProvider>();
    final groupCustomers = provider.activeCustomersForGroup(widget.groupId);
    for (final customer in groupCustomers) {
      if (customer.id == widget.customerId) {
        _editingCustomer = customer;
        _nameController.text = customer.name;
        _phoneController.text = customer.phone;
        _gigabytesController.text = _numberText(customer.gigabytes);
        _priceController.text = _numberText(customer.price);
        _notesController.text = customer.notes;
        _isPaid = customer.isPaid;
        setState(() {});
        return;
      }
    }
  }

  String _numberText(double value) {
    return value.truncateToDouble() == value
        ? value.toInt().toString()
        : value.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _gigabytesController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editCustomer : l10n.addCustomer),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _TextFieldLabel(label: l10n.customerName),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(hintText: l10n.nameHint),
                validator: (value) => Validators.requiredText(
                  value,
                  l10n.requiredField,
                ),
              ),
              const SizedBox(height: 16),
              _TextFieldLabel(label: l10n.phoneNumber),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(hintText: l10n.phoneHint),
                validator: (value) => Validators.requiredText(
                  value,
                  l10n.requiredField,
                ),
              ),
              const SizedBox(height: 16),
              _TextFieldLabel(label: l10n.gigabytes),
              TextFormField(
                controller: _gigabytesController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(hintText: l10n.gigabytesHint),
                validator: (value) => Validators.positiveNumber(
                  value,
                  l10n.requiredField,
                  l10n.invalidNumber,
                  l10n.mustBeGreaterThanZero,
                ),
              ),
              const SizedBox(height: 16),
              _TextFieldLabel(label: l10n.price),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(hintText: l10n.priceHint),
                validator: (value) => Validators.nonNegativeNumber(
                  value,
                  l10n.requiredField,
                  l10n.invalidNumber,
                  l10n.mustBeZeroOrMore,
                ),
              ),
              const SizedBox(height: 16),
              _TextFieldLabel(label: l10n.notesOptional),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(hintText: l10n.notes),
              ),
              const SizedBox(height: 20),
              _TextFieldLabel(label: l10n.paymentStatus),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.paid),
                    icon: const Icon(Icons.check_circle_rounded),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text(l10n.unpaid),
                    icon: const Icon(Icons.pending_rounded),
                  ),
                ],
                selected: {_isPaid},
                onSelectionChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() => _isPaid = value.first);
                },
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) {
      _showSnack(l10n.invalidFormTitle);
      return;
    }

    final provider = context.read<AppProvider>();
    if (!_isEditing && !provider.canAddCustomer(widget.groupId)) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.groupFullTitle),
          content: Text(l10n.groupFullMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final gigabytes = Validators.parseLocalizedDouble(_gigabytesController.text)!;
    final price = Validators.parseLocalizedDouble(_priceController.text)!;

    if (_isEditing && _editingCustomer != null) {
      await provider.updateCustomer(
        _editingCustomer!.copyWith(
          name: _nameController.text,
          phone: _phoneController.text,
          gigabytes: gigabytes,
          price: price,
          isPaid: _isPaid,
          lastPaidDate: _isPaid ? _editingCustomer!.lastPaidDate : null,
          notes: _notesController.text,
        ),
      );
    } else {
      await provider.addCustomer(
        groupId: widget.groupId,
        name: _nameController.text,
        phone: _phoneController.text,
        gigabytes: gigabytes,
        price: price,
        isPaid: _isPaid,
        notes: _notesController.text,
      );
    }

    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);
    _showSnack(l10n.customerSaved);
    Navigator.of(context).pop();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TextFieldLabel extends StatelessWidget {
  const _TextFieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF374151),
            ),
      ),
    );
  }
}
