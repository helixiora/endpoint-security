import 'package:flutter/material.dart';

import '../models.dart';

enum ReviewAction { submit, copyJson }

class ReviewDialog extends StatelessWidget {
  const ReviewDialog({
    super.key,
    required this.submission,
    required this.canSubmit,
    required this.hasSubmissionEndpoint,
    required this.destinationLabel,
    required this.readinessMessage,
  });

  final EndpointSubmission submission;
  final bool canSubmit;
  final bool hasSubmissionEndpoint;
  final String destinationLabel;
  final String? readinessMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checks = submission.report.checks;

    return AlertDialog(
      title: const Text('Review submission'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${submission.ownerName} • ${submission.ownerEmail}',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Endpoint: ${submission.endpointName}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Destination: ${hasSubmissionEndpoint ? destinationLabel : 'not configured'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${submission.report.device.platform} • ${submission.report.device.deviceModel}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${submission.report.device.deviceIdentifierLabel}: ${submission.report.device.deviceIdentifier}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (readinessMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  readinessMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ...checks.map(
                (check) {
                  final confirmationSuffix = check.requiresUserConfirmation
                      ? (check.hasPendingConfirmation
                          ? ' (confirmation required)'
                          : ' (employee confirmed)')
                      : '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      '${check.label}: ${check.effectiveStatus.label}$confirmationSuffix',
                    ),
                  );
                },
              ),
              if (submission.notes.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Notes',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(submission.notes),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(ReviewAction.copyJson),
          child: const Text('Copy JSON'),
        ),
        if (canSubmit)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ReviewAction.submit),
            child: const Text('Submit'),
          ),
      ],
    );
  }
}
