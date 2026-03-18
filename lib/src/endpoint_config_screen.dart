import 'package:flutter/material.dart';

class EndpointConfigScreen extends StatefulWidget {
  const EndpointConfigScreen({
    super.key,
    required this.currentEndpoint,
    required this.bakedInEndpoint,
  });

  final String currentEndpoint;
  final String bakedInEndpoint;

  @override
  State<EndpointConfigScreen> createState() => _EndpointConfigScreenState();
}

class _EndpointConfigScreenState extends State<EndpointConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  bool get _hasBakedInEndpoint => widget.bakedInEndpoint.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentEndpoint);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(_controller.text.trim());
  }

  String? _validateEndpoint(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Enter a full http or https URL.';
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Enter a valid http or https URL.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submission destination'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Paste the webhook or form endpoint that should receive device check-ins.',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Example: a Google Apps Script web app URL, an internal HTTPS webhook, or another endpoint that accepts JSON POST requests.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              if (_hasBakedInEndpoint)
                Card(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Build default',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        SelectableText(widget.bakedInEndpoint),
                        const SizedBox(height: 10),
                        Text(
                          'Use this if Helixiora distributed the app with a preconfigured destination.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_hasBakedInEndpoint) const SizedBox(height: 16),
              TextFormField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Submission endpoint URL',
                  hintText: 'https://example.internal/check-in',
                ),
                keyboardType: TextInputType.url,
                validator: _validateEndpoint,
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save destination'),
              ),
              if (_hasBakedInEndpoint) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(''),
                  child: const Text('Use build default'),
                ),
              ],
              if (!_hasBakedInEndpoint) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(''),
                  child: const Text('Clear destination'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
