import 'package:flutter/material.dart';

class SubmissionEndpointCard extends StatelessWidget {
  const SubmissionEndpointCard({
    super.key,
    required this.configured,
    required this.summary,
    required this.endpointLabel,
    required this.onConfigure,
  });

  final bool configured;
  final String summary;
  final String endpointLabel;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: configured
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.34)
          : theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  configured
                      ? Icons.cloud_done_outlined
                      : Icons.link_off_outlined,
                  color: configured
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    configured
                        ? 'Submission destination ready'
                        : 'Submission destination missing',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onConfigure,
                  child: const Text('Configure'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              summary,
              style: theme.textTheme.bodyMedium,
              maxLines: null,
              overflow: TextOverflow.visible,
            ),
            if (configured) ...[
              const SizedBox(height: 8),
              SelectableText(
                endpointLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 3,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
