import 'package:flutter/material.dart';

class ProfileFormCard extends StatelessWidget {
  const ProfileFormCard({
    super.key,
    required this.ownerNameController,
    required this.ownerEmailController,
    required this.endpointNameController,
    required this.notesController,
    required this.compact,
    required this.onRefresh,
    required this.onSubmit,
    required this.canSubmit,
    required this.submissionHint,
    required this.isSubmitting,
  });

  final TextEditingController ownerNameController;
  final TextEditingController ownerEmailController;
  final TextEditingController endpointNameController;
  final TextEditingController notesController;
  final bool compact;
  final VoidCallback? onRefresh;
  final VoidCallback? onSubmit;
  final bool canSubmit;
  final String? submissionHint;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget buildField({
      required TextEditingController controller,
      required String label,
      TextInputType? keyboardType,
      String? Function(String?)? validator,
      int maxLines = 1,
    }) {
      return TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        minLines: 1,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          isDense: compact,
          contentPadding: compact
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
              : null,
        ),
      );
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Owner and record',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (compact) ...[
              Row(
                children: [
                  Expanded(
                    child: buildField(
                      controller: ownerNameController,
                      label: 'Owner name',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: buildField(
                      controller: ownerEmailController,
                      label: 'Owner email',
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) {
                          return 'Required';
                        }
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email)) {
                          return 'Invalid email';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: buildField(
                      controller: endpointNameController,
                      label: 'Endpoint name',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: buildField(
                      controller: notesController,
                      label: 'Notes',
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ] else ...[
              buildField(
                controller: ownerNameController,
                label: 'Owner name',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter the owner name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              buildField(
                controller: ownerEmailController,
                label: 'Owner email',
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) {
                    return 'Enter the owner email.';
                  }
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              buildField(
                controller: endpointNameController,
                label: 'Endpoint name',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter the endpoint name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              buildField(
                controller: notesController,
                label: 'Notes (optional)',
                maxLines: 3,
              ),
            ],
            if (compact) const Spacer() else const SizedBox(height: 16),
            if (submissionHint != null) ...[
              Text(
                submissionHint!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onSubmit,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_outlined),
                  label: Text(
                    canSubmit ? 'Review & submit' : 'Review check-in',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
