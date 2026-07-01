import 'package:flutter/material.dart';

import '../branding.dart';
import '../models.dart';
import 'check_card.dart';
import 'error_card.dart';
import 'profile_form_card.dart';
import 'version_footer.dart';

class DesktopContent extends StatelessWidget {
  const DesktopContent({
    super.key,
    required this.report,
    required this.checks,
    required this.isLoading,
    required this.loadError,
    required this.hasSubmissionEndpoint,
    required this.submissionLabel,
    required this.onConfigureEndpoint,
    required this.ownerNameController,
    required this.ownerEmailController,
    required this.endpointNameController,
    required this.notesController,
    required this.onRefresh,
    required this.onSubmit,
    required this.canSubmit,
    required this.submissionHint,
    required this.isSubmitting,
    required this.onReviewedStatusChanged,
  });

  final EndpointInspectionReport? report;
  final List<SecurityCheckResult> checks;
  final bool isLoading;
  final String? loadError;
  final bool hasSubmissionEndpoint;
  final String submissionLabel;
  final VoidCallback onConfigureEndpoint;
  final TextEditingController ownerNameController;
  final TextEditingController ownerEmailController;
  final TextEditingController endpointNameController;
  final TextEditingController notesController;
  final VoidCallback? onRefresh;
  final VoidCallback? onSubmit;
  final bool canSubmit;
  final String? submissionHint;
  final bool isSubmitting;
  final void Function(int index, CheckStatus status) onReviewedStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLoading) const LinearProgressIndicator(),
          if (loadError != null) ...[
            ErrorCard(message: loadError!),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 264,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 7,
                  child: _DesktopSummaryPanel(
                    report: report,
                    configured: hasSubmissionEndpoint,
                    submissionLabel: submissionLabel,
                    onConfigureEndpoint: onConfigureEndpoint,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: ProfileFormCard(
                    ownerNameController: ownerNameController,
                    ownerEmailController: ownerEmailController,
                    endpointNameController: endpointNameController,
                    notesController: notesController,
                    compact: true,
                    onRefresh: onRefresh,
                    onSubmit: onSubmit,
                    canSubmit: canSubmit,
                    submissionHint: submissionHint,
                    isSubmitting: isSubmitting,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _DesktopChecksGrid(
              checks: checks,
              onReviewedStatusChanged: onReviewedStatusChanged,
            ),
          ),
          const SizedBox(height: 10),
          const VersionFooter(compact: true),
        ],
      ),
    );
  }
}

class _DesktopSummaryPanel extends StatelessWidget {
  const _DesktopSummaryPanel({
    required this.report,
    required this.configured,
    required this.submissionLabel,
    required this.onConfigureEndpoint,
  });

  final EndpointInspectionReport? report;
  final bool configured;
  final String submissionLabel;
  final VoidCallback onConfigureEndpoint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: brandBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                      'assets/branding/helixiora_icon_dark_blue.png'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Helixiora Endpoint Security',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: brandBlue,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Desktop layout keeps the whole check-in visible without scrolling.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _DesktopInfoPill(
                    label: 'Platform',
                    value: report == null
                        ? 'Loading'
                        : '${report!.device.platform} ${report!.device.osVersion}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DesktopInfoPill(
                    label: 'Device',
                    value: report?.device.deviceModel ?? 'Loading',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DesktopInfoPill(
                    label: report?.device.deviceIdentifierLabel ?? 'Identifier',
                    value: report?.device.deviceIdentifier ?? 'Loading',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DesktopInfoPill(
                    label: 'Collected',
                    value: report == null
                        ? 'Pending'
                        : _formatDesktopTimestamp(report!.collectedAt),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DesktopSubmissionStrip(
              configured: configured,
              endpointLabel: submissionLabel,
              onConfigure: onConfigureEndpoint,
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopInfoPill extends StatelessWidget {
  const _DesktopInfoPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopSubmissionStrip extends StatelessWidget {
  const _DesktopSubmissionStrip({
    required this.configured,
    required this.endpointLabel,
    required this.onConfigure,
  });

  final bool configured;
  final String endpointLabel;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor =
        configured ? const Color(0xFF1F7A41) : theme.colorScheme.error;
    final statusLabel =
        configured ? 'Destination ready' : 'Destination not configured';
    final details = configured
        ? endpointLabel
        : 'Open destination settings and paste the Helixiora intake URL.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: configured
            ? const Color(0xFFEAF6EE)
            : theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: configured
              ? const Color(0xFFB9DEC3)
              : theme.colorScheme.error.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            configured ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: statusColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  statusLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onConfigure,
            child: const Text('Configure'),
          ),
        ],
      ),
    );
  }
}

class _DesktopChecksGrid extends StatelessWidget {
  const _DesktopChecksGrid({
    required this.checks,
    required this.onReviewedStatusChanged,
  });

  final List<SecurityCheckResult> checks;
  final void Function(int index, CheckStatus status) onReviewedStatusChanged;

  @override
  Widget build(BuildContext context) {
    if (checks.isEmpty) {
      return const Card(
        child: Center(
          child: Text('No checks available yet.'),
        ),
      );
    }

    const spacing = 12.0;
    const columns = 2;
    final hasManualReview = checks.any(
      (check) => check.requiresUserConfirmation,
    );
    final tileHeight = hasManualReview ? 286.0 : 232.0;

    return GridView.builder(
      physics: const ClampingScrollPhysics(),
      itemCount: checks.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        mainAxisExtent: tileHeight,
      ),
      itemBuilder: (context, index) {
        final check = checks[index];
        return SecurityCheckCard(
          check: check,
          compact: true,
          onReviewedStatusChanged: (status) {
            onReviewedStatusChanged(index, status);
          },
        );
      },
    );
  }
}

String _formatDesktopTimestamp(DateTime value) {
  final local = value.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}
