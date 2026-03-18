import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_config.dart';
import 'endpoint_config_screen.dart';
import 'inspector/endpoint_inspector.dart';
import 'models.dart';
import 'storage.dart';
import 'submission/submission_service.dart';
import 'widgets/check_card.dart';

const _brandBlue = Color(0xFF081847);
const _brandMist = Color(0xFFF3F6FC);

class EndpointSecurityApp extends StatelessWidget {
  const EndpointSecurityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.windowTitle,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _brandBlue,
        scaffoldBackgroundColor: _brandMist,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const CheckInScreen(),
    );
  }
}

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ownerNameController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  final _endpointNameController = TextEditingController();
  final _notesController = TextEditingController();
  final _inspector = EndpointInspector();
  final _storedProfileRepository = StoredProfileRepository();
  final _endpointSettingsRepository = EndpointSettingsRepository();
  final _submissionService = SubmissionService();

  EndpointInspectionReport? _report;
  List<SecurityCheckResult> _checks = const [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;
  String _submissionEndpoint = AppConfig.submissionEndpoint.trim();

  bool get _hasSubmissionEndpoint => _submissionEndpoint.trim().isNotEmpty;

  bool get _hasBuiltInSubmissionEndpoint =>
      AppConfig.submissionEndpoint.trim().isNotEmpty;

  bool get _hasPendingSecurityConfirmations =>
      _checks.any((check) => check.hasPendingConfirmation);

  bool get _canSubmitReport =>
      _hasSubmissionEndpoint && !_hasPendingSecurityConfirmations;

  String? get _submissionReadinessMessage {
    if (!_hasSubmissionEndpoint) {
      return 'Add a submission destination before sending this report.';
    }

    if (_hasPendingSecurityConfirmations) {
      return 'Confirm every manual-review item before submitting.';
    }

    return null;
  }

  bool get _supportsDesktopLayout {
    final platform = _report?.device.platform;
    return platform == 'macOS' || platform == 'Windows' || platform == 'Linux';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _ownerEmailController.dispose();
    _endpointNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final storedProfile = await _storedProfileRepository.load();
      final storedSubmissionEndpoint =
          await _endpointSettingsRepository.loadSubmissionEndpoint();
      final report = await _inspector.inspect();

      _ownerNameController.text = storedProfile.ownerName;
      _ownerEmailController.text = storedProfile.ownerEmail;
      _endpointNameController.text = storedProfile.endpointName.isNotEmpty
          ? storedProfile.endpointName
          : report.device.endpointName;

      if (!mounted) {
        return;
      }

      setState(() {
        _submissionEndpoint = storedSubmissionEndpoint.isNotEmpty
            ? storedSubmissionEndpoint
            : AppConfig.submissionEndpoint.trim();
        _report = report;
        _checks = report.checks;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = '$error';
      });
    }
  }

  Future<void> _openEndpointSettings() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => EndpointConfigScreen(
          currentEndpoint: _submissionEndpoint.trim(),
          bakedInEndpoint: AppConfig.submissionEndpoint.trim(),
        ),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    await _endpointSettingsRepository.saveSubmissionEndpoint(result);
    final saved = result.trim();

    setState(() {
      _submissionEndpoint =
          saved.isNotEmpty ? saved : AppConfig.submissionEndpoint.trim();
    });

    if (_submissionEndpoint.trim().isEmpty) {
      _showMessage('Submission destination cleared.');
      return;
    }

    if (saved.isEmpty && _hasBuiltInSubmissionEndpoint) {
      _showMessage('Using the default submission destination from this build.');
      return;
    }

    _showMessage('Submission destination saved.');
  }

  Future<void> _submit() async {
    if (_report == null) {
      _showMessage('No inspection data is available yet.');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final submission = EndpointSubmission(
      organization: AppConfig.organizationName,
      ownerName: _ownerNameController.text.trim(),
      ownerEmail: _ownerEmailController.text.trim(),
      endpointName: _endpointNameController.text.trim(),
      notes: _notesController.text.trim(),
      report: _report!.copyWith(checks: _checks),
      submittedAt: DateTime.now().toUtc(),
    );

    final action = await showDialog<_ReviewAction>(
      context: context,
      builder: (context) => _ReviewDialog(
        submission: submission,
        canSubmit: _canSubmitReport,
        hasSubmissionEndpoint: _hasSubmissionEndpoint,
        destinationLabel: _submissionEndpointLabel(_submissionEndpoint),
        readinessMessage: _submissionReadinessMessage,
      ),
    );

    if (action == null || !mounted) {
      return;
    }

    await _storedProfileRepository.save(
      StoredProfile(
        ownerName: _ownerNameController.text.trim(),
        ownerEmail: _ownerEmailController.text.trim(),
        endpointName: _endpointNameController.text.trim(),
      ),
    );

    if (action == _ReviewAction.copyJson) {
      await Clipboard.setData(
        ClipboardData(
          text: const JsonEncoder.withIndent('  ').convert(submission.toJson()),
        ),
      );
      _showMessage('The submission payload was copied to the clipboard.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _submissionService.submit(
        submission,
        submissionEndpoint: _submissionEndpoint.trim(),
      );

      if (!mounted) {
        return;
      }

      _showMessage('Report submitted successfully.');
      setState(() {
        _isSubmitting = false;
      });
    } on SubmissionException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });
      await _showSubmissionFailure(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });
      await _showSubmissionFailure('Could not submit the report: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showSubmissionFailure(String message) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submission failed'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The report was not sent. Please send this message to the engineering channel on Slack.',
                ),
                const SizedBox(height: 16),
                SelectableText(message),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message));
              if (!mounted) {
                return;
              }
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(content: Text('Failure details copied.')),
                );
            },
            child: const Text('Copy details'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  bool _shouldUseDesktopLayout(BoxConstraints constraints) {
    return _supportsDesktopLayout &&
        constraints.maxWidth >= 1180 &&
        constraints.maxHeight >= 780;
  }

  String _submissionEndpointLabel(String endpoint) {
    final trimmed = endpoint.trim();
    if (trimmed.isEmpty) {
      return 'Not configured';
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return trimmed;
    }

    final path = uri.path == '/' ? '' : uri.path;
    final host = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    return '${uri.scheme}://$host$path';
  }

  String _submissionStatusCopy() {
    if (_hasSubmissionEndpoint) {
      return 'Reports will be sent to ${_submissionEndpointLabel(_submissionEndpoint)}.';
    }

    return 'This app does not yet know where to send check-ins. Open configuration and paste the Helixiora submission URL.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const _BrandTitle(),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (_shouldUseDesktopLayout(constraints)) {
                return _DesktopContent(
                  report: _report,
                  checks: _checks,
                  isLoading: _isLoading,
                  loadError: _loadError,
                  hasSubmissionEndpoint: _hasSubmissionEndpoint,
                  submissionLabel:
                      _submissionEndpointLabel(_submissionEndpoint),
                  onConfigureEndpoint: _openEndpointSettings,
                  ownerNameController: _ownerNameController,
                  ownerEmailController: _ownerEmailController,
                  endpointNameController: _endpointNameController,
                  notesController: _notesController,
                  onRefresh: _isLoading ? null : _load,
                  onSubmit: (_isSubmitting || _isLoading || _report == null)
                      ? null
                      : _submit,
                  canSubmit: _canSubmitReport,
                  submissionHint: _submissionReadinessMessage,
                  isSubmitting: _isSubmitting,
                  onReviewedStatusChanged: (index, status) {
                    setState(() {
                      _checks = List<SecurityCheckResult>.from(_checks)
                        ..[index] =
                            _checks[index].copyWith(reviewedStatus: status);
                    });
                  },
                );
              }

              return RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Collect a Helixiora endpoint protection snapshot for ${AppConfig.organizationName}.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Employees can review everything before it is submitted. Desktop platforms try automatic checks; mobile platforms fall back to manual review where the OS blocks inspection.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    const _BrandHero(),
                    const SizedBox(height: 16),
                    if (_isLoading) const LinearProgressIndicator(),
                    if (_loadError != null) ...[
                      _ErrorCard(message: _loadError!),
                      const SizedBox(height: 16),
                    ],
                    _SubmissionEndpointCard(
                      configured: _hasSubmissionEndpoint,
                      summary: _submissionStatusCopy(),
                      endpointLabel: _submissionEndpointLabel(
                        _submissionEndpoint,
                      ),
                      onConfigure: _openEndpointSettings,
                    ),
                    const SizedBox(height: 16),
                    if (_report != null) _DeviceOverview(report: _report!),
                    const SizedBox(height: 16),
                    _ProfileFormCard(
                      ownerNameController: _ownerNameController,
                      ownerEmailController: _ownerEmailController,
                      endpointNameController: _endpointNameController,
                      notesController: _notesController,
                      compact: false,
                      onRefresh: _isLoading ? null : _load,
                      onSubmit: (_isSubmitting || _isLoading || _report == null)
                          ? null
                          : _submit,
                      canSubmit: _canSubmitReport,
                      submissionHint: _submissionReadinessMessage,
                      isSubmitting: _isSubmitting,
                    ),
                    const SizedBox(height: 16),
                    ..._checks.asMap().entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SecurityCheckCard(
                              check: entry.value,
                              onReviewedStatusChanged: (status) {
                                setState(() {
                                  _checks =
                                      List<SecurityCheckResult>.from(_checks)
                                        ..[entry.key] = entry.value.copyWith(
                                          reviewedStatus: status,
                                        );
                                });
                              },
                            ),
                          ),
                        ),
                    const SizedBox(height: 8),
                    const _VersionFooter(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DesktopContent extends StatelessWidget {
  const _DesktopContent({
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
            _ErrorCard(message: loadError!),
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
                  child: _ProfileFormCard(
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
          const _VersionFooter(compact: true),
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
                    color: _brandBlue,
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
                          color: _brandBlue,
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

class _SubmissionEndpointCard extends StatelessWidget {
  const _SubmissionEndpointCard({
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

class _ProfileFormCard extends StatelessWidget {
  const _ProfileFormCard({
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

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const columns = 2;
        final rows = (checks.length / columns).ceil();
        final tileWidth = (constraints.maxWidth - spacing) / columns;
        final tileHeight =
            (constraints.maxHeight - ((rows - 1) * spacing)) / rows;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: checks.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: tileWidth / tileHeight,
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
      },
    );
  }
}

class _DeviceOverview extends StatelessWidget {
  const _DeviceOverview({required this.report});

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

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}

enum _ReviewAction { submit, copyJson }

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Image.asset(
          'assets/branding/helixiora_icon_dark_blue.png',
          width: 34,
          height: 34,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Helixiora',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: _brandBlue,
              ),
            ),
            Text(
              'Endpoint Security Check-In',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BrandHero extends StatelessWidget {
  const _BrandHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0C1D54),
            Color(0xFF081847),
          ],
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child:
                  Image.asset('assets/branding/helixiora_icon_dark_blue.png'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Helixiora Endpoint Security',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Employees can review the collected endpoint posture before anything is submitted.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
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

class _VersionFooter extends StatelessWidget {
  const _VersionFooter({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.sell_outlined,
            size: compact ? 16 : 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              'Version ${AppConfig.displayVersion}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewDialog extends StatelessWidget {
  const _ReviewDialog({
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
          onPressed: () => Navigator.of(context).pop(_ReviewAction.copyJson),
          child: const Text('Copy JSON'),
        ),
        if (canSubmit)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_ReviewAction.submit),
            child: const Text('Submit'),
          ),
      ],
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
