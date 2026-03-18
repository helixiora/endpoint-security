import 'package:flutter/material.dart';

import '../models.dart';

class SecurityCheckCard extends StatelessWidget {
  const SecurityCheckCard({
    super.key,
    required this.check,
    required this.onReviewedStatusChanged,
    this.compact = false,
  });

  final SecurityCheckResult check;
  final ValueChanged<CheckStatus> onReviewedStatusChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = _reviewHint(check);
    final feedback = _securityFeedback(check);
    final padding = compact ? 14.0 : 16.0;
    final statusLabel = check.requiresUserConfirmation
        ? 'Current status: ${check.effectiveStatus.label}'
        : 'Detected: ${check.detectedStatus.label}';

    return Card(
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    check.label,
                    style: compact
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.titleMedium,
                  ),
                ),
                _DetectionBadge(check: check),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              check.summary,
              maxLines: compact ? 4 : null,
              overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
            ),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(
                hint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: compact ? 3 : null,
                overflow:
                    compact ? TextOverflow.ellipsis : TextOverflow.visible,
              ),
            ],
            const SizedBox(height: 12),
            Text(
              statusLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  feedback.icon,
                  size: compact ? 17 : 18,
                  color: feedback.color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feedback.label,
                    maxLines: compact ? 2 : null,
                    overflow:
                        compact ? TextOverflow.ellipsis : TextOverflow.visible,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: feedback.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (check.requiresUserConfirmation) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<CheckStatus>(
                key: ValueKey('${check.id}:${check.reviewedStatus.wireValue}'),
                initialValue: check.reviewedStatus,
                isDense: compact,
                decoration: InputDecoration(
                  labelText: 'Employee confirmation',
                  border: const OutlineInputBorder(),
                  contentPadding: compact
                      ? const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        )
                      : null,
                ),
                items: _confirmationStatuses
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(_confirmationLabel(status)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    onReviewedStatusChanged(value);
                  }
                },
              ),
            ],
            if (!compact &&
                check.details != null &&
                check.details!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text(
                    'More context',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        check.details!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String? _reviewHint(SecurityCheckResult check) {
  return switch (check.detectedStatus) {
    CheckStatus.manualReview =>
      'The app could not verify this setting automatically. Confirm the correct value below.',
    CheckStatus.unknown =>
      'The app found incomplete or conflicting information. Confirm the correct value below.',
    CheckStatus.notApplicable =>
      'This check is usually informational only for this device type.',
    _ => null,
  };
}

const _confirmationStatuses = [
  CheckStatus.manualReview,
  CheckStatus.enabled,
  CheckStatus.disabled,
  CheckStatus.unknown,
];

String _confirmationLabel(CheckStatus status) {
  return switch (status) {
    CheckStatus.manualReview => 'Select status',
    _ => status.label,
  };
}

_ReviewFeedback _securityFeedback(SecurityCheckResult check) {
  if (check.isSecure) {
    return const _ReviewFeedback(
      icon: Icons.check_circle_rounded,
      color: Color(0xFF1F7A41),
      label: 'Compliant and secure.',
    );
  }

  if (check.isInsecure) {
    return const _ReviewFeedback(
      icon: Icons.cancel_rounded,
      color: Color(0xFFC23A36),
      label: 'Not compliant. This protection is off or missing.',
    );
  }

  if (check.isInformational) {
    return const _ReviewFeedback(
      icon: Icons.info_outlined,
      color: Color(0xFF5F6368),
      label: 'Informational only for this device.',
    );
  }

  if (check.hasPendingConfirmation) {
    return const _ReviewFeedback(
      icon: Icons.pending_outlined,
      color: Color(0xFF9A6A00),
      label: 'Needs employee confirmation.',
    );
  }

  return const _ReviewFeedback(
    icon: Icons.help_outline_rounded,
    color: Color(0xFF9A6A00),
    label: 'Status could not be verified yet.',
  );
}

class _ReviewFeedback {
  const _ReviewFeedback({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;
}

class _DetectionBadge extends StatelessWidget {
  const _DetectionBadge({required this.check});

  final SecurityCheckResult check;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = switch (check.detectedStatus) {
      CheckStatus.manualReview => 'Review',
      CheckStatus.notApplicable => 'Info',
      _ => check.detectedAutomatically ? 'Automatic' : 'Manual',
    };
    final color = check.detectedAutomatically
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = check.detectedAutomatically
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
