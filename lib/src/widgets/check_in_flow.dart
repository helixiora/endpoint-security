import 'package:flutter/material.dart';

import '../app_config.dart';
import '../branding.dart';
import '../models.dart';
import 'check_card.dart';
import 'device_overview.dart';
import 'error_card.dart';
import 'profile_form_card.dart';
import 'version_footer.dart';

enum CheckInStep {
  identify,
  scan,
  review,
  submit,
}

extension CheckInStepX on CheckInStep {
  String get label => switch (this) {
        CheckInStep.identify => 'Identify',
        CheckInStep.scan => 'Scan',
        CheckInStep.review => 'Review',
        CheckInStep.submit => 'Submit',
      };

  String get title => switch (this) {
        CheckInStep.identify => 'Confirm who owns this endpoint',
        CheckInStep.scan => 'Review the collected snapshot',
        CheckInStep.review => 'Confirm anything unresolved',
        CheckInStep.submit => 'Send the check-in',
      };
}

class GuidedCheckInContent extends StatelessWidget {
  const GuidedCheckInContent({
    super.key,
    required this.currentStep,
    required this.onStepSelected,
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
    required this.onContinueProfile,
    required this.onContinueScan,
    required this.onContinueReview,
    required this.onSubmit,
    required this.canSubmit,
    required this.readinessMessage,
    required this.profileReadinessMessage,
    required this.isSubmitting,
    required this.onReviewedStatusChanged,
  });

  final CheckInStep currentStep;
  final ValueChanged<CheckInStep> onStepSelected;
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
  final Future<void> Function() onRefresh;
  final VoidCallback onContinueProfile;
  final VoidCallback onContinueScan;
  final VoidCallback onContinueReview;
  final VoidCallback? onSubmit;
  final bool canSubmit;
  final String? readinessMessage;
  final String? profileReadinessMessage;
  final bool isSubmitting;
  final void Function(int index, CheckStatus status) onReviewedStatusChanged;

  List<SecurityCheckResult> get _pendingChecks =>
      checks.where((check) => check.hasPendingConfirmation).toList();

  List<SecurityCheckResult> get _attentionChecks =>
      checks.where((check) => check.isInsecure).toList();

  int get _readyCount => checks.where((check) => check.isSecure).length;

  bool get _profileComplete => profileReadinessMessage == null;

  bool get _scanComplete => report != null && checks.isNotEmpty;

  bool get _reviewComplete => _scanComplete && _pendingChecks.isEmpty;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(wide ? 24 : 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - (wide ? 48 : 32),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CheckInHeader(
                    pendingCount: _pendingChecks.length,
                    attentionCount: _attentionChecks.length,
                    readyCount: _readyCount,
                    isLoading: isLoading,
                  ),
                  if (isLoading) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                  if (loadError != null) ...[
                    const SizedBox(height: 12),
                    ErrorCard(message: loadError!),
                  ],
                  const SizedBox(height: 16),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 284,
                          child: _StepRail(
                            currentStep: currentStep,
                            onStepSelected: onStepSelected,
                            profileComplete: _profileComplete,
                            scanComplete: _scanComplete,
                            reviewComplete: _reviewComplete,
                            canSubmit: canSubmit,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(child: _buildCurrentStep(context)),
                      ],
                    )
                  else ...[
                    _StepRail(
                      currentStep: currentStep,
                      onStepSelected: onStepSelected,
                      profileComplete: _profileComplete,
                      scanComplete: _scanComplete,
                      reviewComplete: _reviewComplete,
                      canSubmit: canSubmit,
                      compact: true,
                    ),
                    const SizedBox(height: 14),
                    _buildCurrentStep(context),
                  ],
                  const SizedBox(height: 18),
                  const VersionFooter(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    return switch (currentStep) {
      CheckInStep.identify => _IdentifyStep(
          ownerNameController: ownerNameController,
          ownerEmailController: ownerEmailController,
          endpointNameController: endpointNameController,
          notesController: notesController,
          hasSubmissionEndpoint: hasSubmissionEndpoint,
          submissionLabel: submissionLabel,
          onConfigureEndpoint: onConfigureEndpoint,
          onContinue: onContinueProfile,
          profileReadinessMessage: profileReadinessMessage,
        ),
      CheckInStep.scan => _ScanStep(
          report: report,
          checks: checks,
          readyCount: _readyCount,
          pendingCount: _pendingChecks.length,
          attentionCount: _attentionChecks.length,
          isLoading: isLoading,
          onRefresh: onRefresh,
          onContinue: onContinueScan,
        ),
      CheckInStep.review => _ReviewStep(
          checks: checks,
          pendingChecks: _pendingChecks,
          attentionChecks: _attentionChecks,
          onContinue: onContinueReview,
          onReviewedStatusChanged: onReviewedStatusChanged,
        ),
      CheckInStep.submit => _SubmitStep(
          checks: checks,
          readyCount: _readyCount,
          pendingCount: _pendingChecks.length,
          attentionCount: _attentionChecks.length,
          hasSubmissionEndpoint: hasSubmissionEndpoint,
          submissionLabel: submissionLabel,
          readinessMessage: readinessMessage,
          isSubmitting: isSubmitting,
          canSubmit: canSubmit,
          onConfigureEndpoint: onConfigureEndpoint,
          onSubmit: onSubmit,
          onBackToReview: () => onStepSelected(CheckInStep.review),
        ),
    };
  }
}

class _CheckInHeader extends StatelessWidget {
  const _CheckInHeader({
    required this.pendingCount,
    required this.attentionCount,
    required this.readyCount,
    required this.isLoading,
  });

  final int pendingCount;
  final int attentionCount;
  final int readyCount;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textWidth =
            constraints.maxWidth < 640 ? constraints.maxWidth - 56 : 520.0;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Wrap(
            spacing: 18,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: brandBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.asset(
                      'assets/branding/helixiora_icon_dark_blue.png',
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: textWidth < 180 ? 180 : textWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Complete endpoint check-in',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: brandBlue,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Confirm the owner, review the scan, then submit the attestation.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              _HeaderMetric(
                icon: Icons.check_circle_rounded,
                label: 'Ready',
                value: isLoading ? '-' : '$readyCount',
                color: const Color(0xFF1F7A41),
              ),
              _HeaderMetric(
                icon: Icons.pending_actions_rounded,
                label: 'Need input',
                value: isLoading ? '-' : '$pendingCount',
                color: const Color(0xFF9A6A00),
              ),
              _HeaderMetric(
                icon: Icons.error_rounded,
                label: 'Attention',
                value: isLoading ? '-' : '$attentionCount',
                color: const Color(0xFFC23A36),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRail extends StatelessWidget {
  const _StepRail({
    required this.currentStep,
    required this.onStepSelected,
    required this.profileComplete,
    required this.scanComplete,
    required this.reviewComplete,
    required this.canSubmit,
    this.compact = false,
  });

  final CheckInStep currentStep;
  final ValueChanged<CheckInStep> onStepSelected;
  final bool profileComplete;
  final bool scanComplete;
  final bool reviewComplete;
  final bool canSubmit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final items = [
      _StepState(
        step: CheckInStep.identify,
        complete: profileComplete,
        helper: profileComplete ? 'Owner details ready' : 'Name and email',
      ),
      _StepState(
        step: CheckInStep.scan,
        complete: scanComplete,
        helper: scanComplete ? 'Snapshot collected' : 'Collect device data',
      ),
      _StepState(
        step: CheckInStep.review,
        complete: reviewComplete,
        helper: reviewComplete ? 'Checks confirmed' : 'Resolve open items',
      ),
      _StepState(
        step: CheckInStep.submit,
        complete: canSubmit,
        helper: canSubmit ? 'Ready to send' : 'Final review',
      ),
    ];

    if (compact) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) {
          return _StepButton(
            state: item,
            selected: item.step == currentStep,
            compact: true,
            onTap: () => onStepSelected(item.step),
          );
        }).toList(),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: items.map((item) {
          return _StepButton(
            state: item,
            selected: item.step == currentStep,
            onTap: () => onStepSelected(item.step),
          );
        }).toList(),
      ),
    );
  }
}

class _StepState {
  const _StepState({
    required this.step,
    required this.complete,
    required this.helper,
  });

  final CheckInStep step;
  final bool complete;
  final String helper;
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.state,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final _StepState state;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? brandBlue : theme.colorScheme.onSurfaceVariant;
    final background = selected
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.36)
        : Colors.transparent;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 8 : 11,
          ),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Icon(
                state.complete
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: state.complete ? const Color(0xFF1F7A41) : color,
                size: 20,
              ),
              const SizedBox(width: 9),
              if (compact)
                Text(
                  state.step.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                )
              else
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.step.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.helper,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageHeader extends StatelessWidget {
  const _StageHeader({
    required this.step,
    required this.description,
  });

  final CheckInStep step;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: brandBlue,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _IdentifyStep extends StatelessWidget {
  const _IdentifyStep({
    required this.ownerNameController,
    required this.ownerEmailController,
    required this.endpointNameController,
    required this.notesController,
    required this.hasSubmissionEndpoint,
    required this.submissionLabel,
    required this.onConfigureEndpoint,
    required this.onContinue,
    required this.profileReadinessMessage,
  });

  final TextEditingController ownerNameController;
  final TextEditingController ownerEmailController;
  final TextEditingController endpointNameController;
  final TextEditingController notesController;
  final bool hasSubmissionEndpoint;
  final String submissionLabel;
  final VoidCallback onConfigureEndpoint;
  final VoidCallback onContinue;
  final String? profileReadinessMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StageHeader(
          step: CheckInStep.identify,
          description:
              'Use the employee and endpoint name that should appear in the security record.',
        ),
        const SizedBox(height: 14),
        ProfileFormCard(
          ownerNameController: ownerNameController,
          ownerEmailController: ownerEmailController,
          endpointNameController: endpointNameController,
          notesController: notesController,
          compact: false,
          onRefresh: null,
          onSubmit: onContinue,
          canSubmit: true,
          submissionHint: profileReadinessMessage,
          isSubmitting: false,
          description:
              'The detected endpoint name is pre-filled. Correct it if employees know this device by another name.',
          submitLabel: 'Continue to scan',
          submitIcon: Icons.arrow_forward_rounded,
          showRefreshAction: false,
        ),
        const SizedBox(height: 14),
        _DestinationBanner(
          configured: hasSubmissionEndpoint,
          endpointLabel: submissionLabel,
          onConfigure: onConfigureEndpoint,
        ),
      ],
    );
  }
}

class _ScanStep extends StatelessWidget {
  const _ScanStep({
    required this.report,
    required this.checks,
    required this.readyCount,
    required this.pendingCount,
    required this.attentionCount,
    required this.isLoading,
    required this.onRefresh,
    required this.onContinue,
  });

  final EndpointInspectionReport? report;
  final List<SecurityCheckResult> checks;
  final int readyCount;
  final int pendingCount;
  final int attentionCount;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StageHeader(
          step: CheckInStep.scan,
          description:
              'Automatic checks are inputs for the employee attestation. Review the snapshot before confirming the unresolved items.',
        ),
        const SizedBox(height: 14),
        _ScanSummaryCard(
          readyCount: readyCount,
          pendingCount: pendingCount,
          attentionCount: attentionCount,
          totalCount: checks.length,
        ),
        if (report != null) ...[
          const SizedBox(height: 14),
          DeviceOverview(report: report!),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: isLoading ? null : onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh scan'),
            ),
            FilledButton.icon(
              onPressed: report == null ? null : onContinue,
              icon: const Icon(Icons.rule_rounded),
              label: Text(
                pendingCount > 0
                    ? 'Review $pendingCount open item${pendingCount == 1 ? '' : 's'}'
                    : 'Review checks',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.checks,
    required this.pendingChecks,
    required this.attentionChecks,
    required this.onContinue,
    required this.onReviewedStatusChanged,
  });

  final List<SecurityCheckResult> checks;
  final List<SecurityCheckResult> pendingChecks;
  final List<SecurityCheckResult> attentionChecks;
  final VoidCallback onContinue;
  final void Function(int index, CheckStatus status) onReviewedStatusChanged;

  @override
  Widget build(BuildContext context) {
    final pendingIds = pendingChecks.map((check) => check.id).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StageHeader(
          step: CheckInStep.review,
          description:
              'Resolve the checks the app could not verify. If a protection is off, mark it honestly and add context in the notes field.',
        ),
        const SizedBox(height: 14),
        if (pendingChecks.isEmpty)
          _CompletionBanner(
            icon: Icons.check_circle_rounded,
            title: 'All required confirmations are complete',
            message: attentionChecks.isEmpty
                ? 'The check-in is ready for final review.'
                : 'Some protections still need attention, but the attestation can capture that state.',
            color: const Color(0xFF1F7A41),
          )
        else
          _CompletionBanner(
            icon: Icons.pending_actions_rounded,
            title:
                '${pendingChecks.length} item${pendingChecks.length == 1 ? '' : 's'} need employee input',
            message:
                'Use the controls on each card to confirm whether the protection is enabled or disabled.',
            color: const Color(0xFF9A6A00),
          ),
        const SizedBox(height: 14),
        ...checks.asMap().entries.map((entry) {
          final check = entry.value;
          final emphasize = pendingIds.contains(check.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Opacity(
              opacity: pendingChecks.isNotEmpty && !emphasize ? 0.78 : 1,
              child: SecurityCheckCard(
                check: check,
                onReviewedStatusChanged: (status) {
                  onReviewedStatusChanged(entry.key, status);
                },
              ),
            ),
          );
        }),
        FilledButton.icon(
          onPressed: pendingChecks.isEmpty ? onContinue : null,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: Text(
            pendingChecks.isEmpty
                ? 'Continue to submit'
                : 'Complete ${pendingChecks.length} confirmation${pendingChecks.length == 1 ? '' : 's'}',
          ),
        ),
      ],
    );
  }
}

class _SubmitStep extends StatelessWidget {
  const _SubmitStep({
    required this.checks,
    required this.readyCount,
    required this.pendingCount,
    required this.attentionCount,
    required this.hasSubmissionEndpoint,
    required this.submissionLabel,
    required this.readinessMessage,
    required this.isSubmitting,
    required this.canSubmit,
    required this.onConfigureEndpoint,
    required this.onSubmit,
    required this.onBackToReview,
  });

  final List<SecurityCheckResult> checks;
  final int readyCount;
  final int pendingCount;
  final int attentionCount;
  final bool hasSubmissionEndpoint;
  final String submissionLabel;
  final String? readinessMessage;
  final bool isSubmitting;
  final bool canSubmit;
  final VoidCallback onConfigureEndpoint;
  final VoidCallback? onSubmit;
  final VoidCallback onBackToReview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StageHeader(
          step: CheckInStep.submit,
          description:
              'Review the destination and summary before sending the signed check-in envelope.',
        ),
        const SizedBox(height: 14),
        _SubmissionSummaryCard(
          totalCount: checks.length,
          readyCount: readyCount,
          pendingCount: pendingCount,
          attentionCount: attentionCount,
          hasSubmissionEndpoint: hasSubmissionEndpoint,
          submissionLabel: submissionLabel,
          readinessMessage: readinessMessage,
          onConfigureEndpoint: onConfigureEndpoint,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onBackToReview,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to review'),
            ),
            FilledButton.icon(
              onPressed: onSubmit,
              icon: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_outlined),
              label: Text(canSubmit ? 'Review and submit' : 'Review check-in'),
            ),
          ],
        ),
      ],
    );
  }
}

class _DestinationBanner extends StatelessWidget {
  const _DestinationBanner({
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
    final color =
        configured ? const Color(0xFF1F7A41) : const Color(0xFFC23A36);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            configured ? Icons.cloud_done_outlined : Icons.link_off_outlined,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  configured
                      ? 'Submission destination ready'
                      : 'Submission destination missing',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  configured
                      ? endpointLabel
                      : 'Configure this build before employees can send check-ins directly.',
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
            child: Text(configured ? 'Change' : 'Configure'),
          ),
        ],
      ),
    );
  }
}

class _ScanSummaryCard extends StatelessWidget {
  const _ScanSummaryCard({
    required this.readyCount,
    required this.pendingCount,
    required this.attentionCount,
    required this.totalCount,
  });

  final int readyCount;
  final int pendingCount;
  final int attentionCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _SummaryTile(
              label: 'Checks collected',
              value: '$totalCount',
              icon: Icons.inventory_2_outlined,
              color: brandBlue,
            ),
            _SummaryTile(
              label: 'Ready',
              value: '$readyCount',
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF1F7A41),
            ),
            _SummaryTile(
              label: 'Need input',
              value: '$pendingCount',
              icon: Icons.pending_actions_rounded,
              color: const Color(0xFF9A6A00),
            ),
            _SummaryTile(
              label: 'Attention',
              value: '$attentionCount',
              icon: Icons.error_rounded,
              color: const Color(0xFFC23A36),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 146),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
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

class _CompletionBanner extends StatelessWidget {
  const _CompletionBanner({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmissionSummaryCard extends StatelessWidget {
  const _SubmissionSummaryCard({
    required this.totalCount,
    required this.readyCount,
    required this.pendingCount,
    required this.attentionCount,
    required this.hasSubmissionEndpoint,
    required this.submissionLabel,
    required this.readinessMessage,
    required this.onConfigureEndpoint,
  });

  final int totalCount;
  final int readyCount;
  final int pendingCount;
  final int attentionCount;
  final bool hasSubmissionEndpoint;
  final String submissionLabel;
  final String? readinessMessage;
  final VoidCallback onConfigureEndpoint;

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
              '${AppConfig.organizationName} endpoint attestation',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniPill(label: '$totalCount checks'),
                _MiniPill(label: '$readyCount ready'),
                if (attentionCount > 0)
                  _MiniPill(label: '$attentionCount need attention'),
                if (pendingCount > 0)
                  _MiniPill(label: '$pendingCount need confirmation'),
              ],
            ),
            const SizedBox(height: 14),
            _DestinationBanner(
              configured: hasSubmissionEndpoint,
              endpointLabel: submissionLabel,
              onConfigure: onConfigureEndpoint,
            ),
            if (readinessMessage != null) ...[
              const SizedBox(height: 14),
              _CompletionBanner(
                icon: Icons.info_outline_rounded,
                title: 'One more thing before direct submit',
                message: readinessMessage!,
                color: const Color(0xFF9A6A00),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
