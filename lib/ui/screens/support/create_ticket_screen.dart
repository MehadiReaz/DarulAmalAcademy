import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/ticket_provider.dart';
import '../../widgets/app_button.dart';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  String _priority = 'medium';
  String _category = 'other';

  // `SupportTicket::PRIORITIES` on the backend is ['low','medium','high'].
  // The request validator also permits 'urgent', but the model constant
  // does not — so 'urgent' is left out rather than offering a value that
  // may be rejected once the two are reconciled.
  static const _priorities = ['low', 'medium', 'high'];

  // Mirrors `SupportTicket::CATEGORIES`.
  static const _categories = <String, String>{
    'teacher_issue': 'Teacher',
    'payment_issue': 'Payment',
    'zoom_issue': 'Class / Zoom',
    'admission': 'Admission',
    'other': 'Other',
  };

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final provider = context.read<TicketProvider>();
    final ticket = await provider.createTicket(
      subject: _subjectController.text.trim(),
      message: _messageController.text.trim(),
      priority: _priority,
      category: _category,
    );

    if (!mounted) return;

    if (ticket != null) {
      // Grab the messenger BEFORE popping — this context is about to die.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Ticket submitted')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.submitError ?? 'Could not submit ticket'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TicketProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('New Ticket')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
            children: [
              TextFormField(
                controller: _subjectController,
                maxLength: 255,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  hintText: 'e.g. Cannot join today\'s class',
                  counterText: '',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please add a subject'
                    : null,
              ),
              const SizedBox(height: 16),
              const _FieldLabel('Category'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: _categories.entries.map((entry) {
                  final selected = _category == entry.key;
                  return ChoiceChip(
                    label: Text(entry.value),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _category = entry.key),
                    backgroundColor: AppColors.surface,
                    selectedColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.line),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? const Color(0xFF231600)
                          : AppColors.muted,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              const _FieldLabel('Priority'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 9,
                children: _priorities.map((p) {
                  final selected = _priority == p;
                  return ChoiceChip(
                    label: Text(p[0].toUpperCase() + p.substring(1)),
                    selected: selected,
                    onSelected: (_) => setState(() => _priority = p),
                    backgroundColor: AppColors.surface,
                    selectedColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.line),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? const Color(0xFF231600)
                          : AppColors.muted,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _messageController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'Describe the problem in detail…',
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please describe the issue'
                    : null,
              ),
              if (provider.submitError != null) ...[
                const SizedBox(height: 12),
                Text(
                  provider.submitError!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 26),
              AppButton(
                label: 'Submit Ticket',
                loading: provider.submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
