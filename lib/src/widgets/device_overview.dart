import 'package:flutter/material.dart';

import '../models.dart';

class DeviceOverview extends StatelessWidget {
  const DeviceOverview({super.key, required this.report});

  final EndpointInspectionReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Collected ${report.collectedAt.toLocal()}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${report.device.platform} • ${report.device.osVersion}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Device model: ${report.device.deviceModel}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Detected endpoint name: ${report.device.endpointName}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${report.device.deviceIdentifierLabel}: ${report.device.deviceIdentifier}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
