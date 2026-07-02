import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_config.dart';
import 'branding.dart';
import 'endpoint_config_screen.dart';
import 'inspector/endpoint_inspector.dart';
import 'models.dart';
import 'storage.dart';
import 'submission/submission_service.dart';
import 'widgets/brand_widgets.dart';
import 'widgets/check_card.dart';
import 'widgets/desktop_content.dart';
import 'widgets/device_overview.dart';
import 'widgets/error_card.dart';
import 'widgets/profile_form_card.dart';
import 'widgets/review_dialog.dart';
import 'widgets/submission_endpoint_card.dart';
import 'widgets/version_footer.dart';

class EndpointSecurityApp extends StatelessWidget {
  const EndpointSecurityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.windowTitle,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: brandBlue,
        scaffoldBackgroundColor: brandMist,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const CheckInScreen(),
    );
  }
}

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({
    super.key,
    this.inspector,
    this.submissionService,
    this.profileRepository,
    this.settingsRepository,
  });

  final EndpointInspector? inspector;
  final SubmissionService? submissionService;
  final StoredProfileRepository? profileRepository;
  final EndpointSettingsRepository? settingsRepository;

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ownerNameController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  final _endpointNameController = TextEditingController();
  final _notesController = TextEditingController();
  late final EndpointInspector _inspector;
  late final StoredProfileRepository _storedProfileRepository;
  late final EndpointSettingsRepository _endpointSettingsRepository;
  late final SubmissionService _submissionService;

  EndpointInspectionReport? _report;
  List<SecurityCheckResult> _checks = const [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;
  String _submissionEndpoint = AppConfig.submissionEndpoint.trim();

  bool get _hasSubmissionEndpoint => _submissionEndpoint.isNotEmpty;

  bool get _hasSubmissionSecret => AppConfig.submissionSecret.trim().isNotEmpty;

  bool get _hasBuiltInSubmissionEndpoint =>
      AppConfig.submissionEndpoint.trim().isNotEmpty;

  bool get _hasPendingSecurityConfirmations =>
      _checks.any((check) => check.hasPendingConfirmation);

  bool get _canSubmitReport =>
      _hasSubmissionEndpoint &&
      _hasSubmissionSecret &&
      !_hasPendingSecurityConfirmations;

  String? get _submissionReadinessMessage {
    if (!_hasSubmissionEndpoint) {
      return 'Add a submission destination before sending this report.';
    }

    if (!_hasSubmissionSecret) {
      return 'This build is missing its submission signing secret.';
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
    _inspector = widget.inspector ?? EndpointInspector();
    _storedProfileRepository =
        widget.profileRepository ?? StoredProfileRepository();
    _endpointSettingsRepository =
        widget.settingsRepository ?? EndpointSettingsRepository();
    _submissionService = widget.submissionService ?? SubmissionService();
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
          currentEndpoint: _submissionEndpoint,
          bakedInEndpoint: AppConfig.submissionEndpoint.trim(),
        ),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    await _endpointSettingsRepository.saveSubmissionEndpoint(result);
    final saved = result.trim();

    if (!mounted) {
      return;
    }

    setState(() {
      _submissionEndpoint =
          saved.isNotEmpty ? saved : AppConfig.submissionEndpoint.trim();
    });

    if (_submissionEndpoint.isEmpty) {
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

    final action = await showDialog<ReviewAction>(
      context: context,
      builder: (context) => ReviewDialog(
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

    if (action == ReviewAction.copyJson) {
      final payload = _hasSubmissionSecret
          ? _submissionService.signedEnvelope(
              submission,
              signingSecret: AppConfig.submissionSecret,
            )
          : submission.toJson();
      await Clipboard.setData(
        ClipboardData(
          text: const JsonEncoder.withIndent('  ').convert(payload),
        ),
      );
      if (!mounted) {
        return;
      }
      _showMessage('The submission payload was copied to the clipboard.');
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _submissionService.submit(
        submission,
        submissionEndpoint: _submissionEndpoint,
        signingSecret: AppConfig.submissionSecret,
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

  void _onReviewedStatusChanged(int index, CheckStatus status) {
    setState(() {
      _checks = List<SecurityCheckResult>.from(_checks)
        ..[index] = _checks[index].copyWith(reviewedStatus: status);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const BrandTitle(),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (_shouldUseDesktopLayout(constraints)) {
                return DesktopContent(
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
                  onReviewedStatusChanged: _onReviewedStatusChanged,
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
                    const BrandHero(),
                    const SizedBox(height: 16),
                    if (_isLoading) const LinearProgressIndicator(),
                    if (_loadError != null) ...[
                      ErrorCard(message: _loadError!),
                      const SizedBox(height: 16),
                    ],
                    SubmissionEndpointCard(
                      configured: _hasSubmissionEndpoint,
                      summary: _submissionStatusCopy(),
                      endpointLabel: _submissionEndpointLabel(
                        _submissionEndpoint,
                      ),
                      onConfigure: _openEndpointSettings,
                    ),
                    const SizedBox(height: 16),
                    if (_report != null) DeviceOverview(report: _report!),
                    const SizedBox(height: 16),
                    ProfileFormCard(
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
                                _onReviewedStatusChanged(entry.key, status);
                              },
                            ),
                          ),
                        ),
                    const SizedBox(height: 8),
                    const VersionFooter(),
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
