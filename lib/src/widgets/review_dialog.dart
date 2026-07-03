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
    final passed = checks.where((check) => check.isSecure).length;
    final needsAttention = checks.where((check) => check.isInsecure).length;
    final needsInput =
        checks.where((check) => check.hasPendingConfirmation).length;
    final informational = checks.where((check) => check.isInformational).length;

    return AlertDialog(
      title: const Text('Final review'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Check-in summary',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SummaryPill(
                    icon: Icons.check_circle_rounded,
                    label: '$passed ready',
                    color: const Color(0xFF1F7A41),
                  ),
                  if (needsAttention > 0)
                    _SummaryPill(
                      icon: Icons.error_rounded,
                      label: '$needsAttention need attention',
                      color: const Color(0xFFC23A36),
                    ),
                  if (needsInput > 0)
                    _SummaryPill(
                      icon: Icons.pending_actions_rounded,
                      label: '$needsInput need confirmation',
                      color: const Color(0xFF9A6A00),
                    ),
                  if (informational > 0)
                    _SummaryPill(
                      icon: Icons.info_outline_rounded,
                      label: '$informational informational',
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
              const SizedBox(height: 16),
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
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    readinessMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Checks',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
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
            child: const Text('Submit check-in'),
          ),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.32)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
