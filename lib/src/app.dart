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
import 'widgets/check_in_flow.dart';
import 'widgets/review_dialog.dart';

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
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFDCE3EF)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
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
  CheckInStep _currentStep = CheckInStep.identify;
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
      _profileReadinessMessage == null &&
      _hasSubmissionEndpoint &&
      _hasSubmissionSecret &&
      !_hasPendingSecurityConfirmations;

  String? get _profileReadinessMessage {
    final ownerName = _ownerNameController.text.trim();
    final ownerEmail = _ownerEmailController.text.trim();
    final endpointName = _endpointNameController.text.trim();

    if (ownerName.isEmpty) {
      return 'Enter the employee name before continuing.';
    }

    if (ownerEmail.isEmpty) {
      return 'Enter the employee email before continuing.';
    }

    if (!_emailPattern.hasMatch(ownerEmail)) {
      return 'Enter a valid employee email address.';
    }

    if (endpointName.isEmpty) {
      return 'Enter the endpoint name before continuing.';
    }

    return null;
  }

  String? get _submissionReadinessMessage {
    final profileMessage = _profileReadinessMessage;
    if (profileMessage != null) {
      return profileMessage;
    }

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

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    _ownerNameController.addListener(_onProfileChanged);
    _ownerEmailController.addListener(_onProfileChanged);
    _endpointNameController.addListener(_onProfileChanged);
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
    _ownerNameController.removeListener(_onProfileChanged);
    _ownerEmailController.removeListener(_onProfileChanged);
    _endpointNameController.removeListener(_onProfileChanged);
    _ownerNameController.dispose();
    _ownerEmailController.dispose();
    _endpointNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onProfileChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
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

      if (!mounted) {
        return;
      }

      _ownerNameController.text = storedProfile.ownerName;
      _ownerEmailController.text = storedProfile.ownerEmail;
      _endpointNameController.text = storedProfile.endpointName.isNotEmpty
          ? storedProfile.endpointName
          : report.device.endpointName;

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

  bool _validateProfileForAction() {
    final profileMessage = _profileReadinessMessage;
    final formValid = _formKey.currentState?.validate() ?? true;
    if (profileMessage == null && formValid) {
      return true;
    }

    setState(() {
      _currentStep = CheckInStep.identify;
    });
    _showMessage(profileMessage ?? 'Complete the owner and endpoint details.');
    return false;
  }

  void _goToStep(CheckInStep step) {
    setState(() {
      _currentStep = step;
    });
  }

  void _continueFromProfile() {
    if (!_validateProfileForAction()) {
      return;
    }

    _goToStep(CheckInStep.scan);
  }

  void _continueFromScan() {
    if (_report == null) {
      _showMessage('No inspection data is available yet.');
      return;
    }

    _goToStep(CheckInStep.review);
  }

  void _continueFromReview() {
    if (_hasPendingSecurityConfirmations) {
      _showMessage('Confirm every manual-review item before continuing.');
      return;
    }

    _goToStep(CheckInStep.submit);
  }

  Future<void> _submit() async {
    if (_report == null) {
      _showMessage('No inspection data is available yet.');
      return;
    }

    if (!_validateProfileForAction()) {
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
        _currentStep = CheckInStep.submit;
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
        actions: [
          IconButton(
            tooltip: 'Submission destination',
            onPressed: _openEndpointSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: GuidedCheckInContent(
            currentStep: _currentStep,
            onStepSelected: _goToStep,
            report: _report,
            checks: _checks,
            isLoading: _isLoading,
            loadError: _loadError,
            hasSubmissionEndpoint: _hasSubmissionEndpoint,
            submissionLabel: _submissionEndpointLabel(_submissionEndpoint),
            onConfigureEndpoint: _openEndpointSettings,
            ownerNameController: _ownerNameController,
            ownerEmailController: _ownerEmailController,
            endpointNameController: _endpointNameController,
            notesController: _notesController,
            onRefresh: _load,
            onContinueProfile: _continueFromProfile,
            onContinueScan: _continueFromScan,
            onContinueReview: _continueFromReview,
            onSubmit: (_isSubmitting || _isLoading || _report == null)
                ? null
                : _submit,
            canSubmit: _canSubmitReport,
            readinessMessage: _submissionReadinessMessage,
            profileReadinessMessage: _profileReadinessMessage,
            isSubmitting: _isSubmitting,
            onReviewedStatusChanged: _onReviewedStatusChanged,
          ),
        ),
      ),
    );
  }
}
