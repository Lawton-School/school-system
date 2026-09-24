import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/school_settings_controllers.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/stitch_widgets.dart';

/// Screen 23 — School Settings.
///
/// Only fields explicitly allow-listed by `patch_school_configuration()` are
/// editable. Subscription/plan/status metadata is intentionally read-only.
class SchoolSettingsScreen extends ConsumerStatefulWidget {
  const SchoolSettingsScreen({super.key});

  @override
  ConsumerState<SchoolSettingsScreen> createState() =>
      _SchoolSettingsScreenState();
}

class _SchoolSettingsScreenState extends ConsumerState<SchoolSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _legalName = TextEditingController();
  final _registration = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address1 = TextEditingController();
  final _address2 = TextEditingController();
  final _city = TextEditingController();
  final _province = TextEditingController();
  final _countryCode = TextEditingController();
  final _timezone = TextEditingController();
  final _currency = TextEditingController();
  final _logoUrl = TextEditingController();
  final _websiteUrl = TextEditingController();

  String? _loadedSchoolId;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _legalName,
      _registration,
      _email,
      _phone,
      _address1,
      _address2,
      _city,
      _province,
      _countryCode,
      _timezone,
      _currency,
      _logoUrl,
      _websiteUrl,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _populate(Map<String, dynamic> config) {
    final id = config['id']?.toString();
    if (id == null || id == _loadedSchoolId) return;
    _loadedSchoolId = id;

    _name.text = _text(config['name']);
    _legalName.text = _text(config['legal_name']);
    _registration.text = _text(config['registration_number']);
    _email.text = _text(config['contact_email']);
    _phone.text = _text(config['contact_phone']);
    _address1.text = _text(config['address_line1']);
    _address2.text = _text(config['address_line2']);
    _city.text = _text(config['city']);
    _province.text = _text(config['province']);
    _countryCode.text = _text(config['country_code']);
    _timezone.text = _text(config['timezone']);
    _currency.text = _text(config['default_currency']);
    _logoUrl.text = _text(config['logo_url']);
    _websiteUrl.text = _text(config['website_url']);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final session = ref.read(activeSessionProvider);
    if (session == null) return;

    setState(() => _saving = true);
    try {
      final saved = await ref.read(schoolSettingsRepositoryProvider).saveProfile({
        'name': _name.text.trim(),
        'legal_name': _legalName.text.trim(),
        'registration_number': _registration.text.trim(),
        'contact_email': _email.text.trim(),
        'contact_phone': _phone.text.trim(),
        'address_line1': _address1.text.trim(),
        'address_line2': _address2.text.trim(),
        'city': _city.text.trim(),
        'province': _province.text.trim(),
        'country_code': _countryCode.text.trim(),
        'timezone': _timezone.text.trim(),
        'default_currency': _currency.text.trim(),
        'logo_url': _logoUrl.text.trim(),
        'website_url': _websiteUrl.text.trim(),
      });

      final savedName = saved['name']?.toString().trim();
      if (savedName != null && savedName.isNotEmpty) {
        await ref.read(activeSessionProvider.notifier).setActiveSession(
              ActiveSession(
                schoolId: session.schoolId,
                schoolName: savedName,
                profileId: session.profileId,
                role: session.role,
              ),
            );
      }

      _loadedSchoolId = null;
      ref.invalidate(schoolConfigurationProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('School settings saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save settings: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    final configAsync = ref.watch(schoolConfigurationProvider);
    final canEdit = session?.role == AppRoles.schoolAdmin ||
        session?.role == AppRoles.superAdmin;

    return Scaffold(
      backgroundColor: AppTheme.stitchBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ADMINISTRATION',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppTheme.primaryDark,
              ),
            ),
            Text(
              'School Settings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.stitchHeading,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reload settings',
            onPressed: () {
              _loadedSchoolId = null;
              ref.invalidate(schoolConfigurationProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (canEdit)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded, size: 17),
                label: const Text('Save'),
              ),
            ),
        ],
      ),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: 'Unable to load school settings: $error',
          onRetry: () {
            _loadedSchoolId = null;
            ref.invalidate(schoolConfigurationProvider);
          },
        ),
        data: (config) {
          _populate(config);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _SubscriptionCard(config: config),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: 'School Identity',
                  subtitle: 'Public and legal information for this school.',
                  children: [
                    _field(
                      controller: _name,
                      label: 'School Name',
                      enabled: canEdit,
                      required: true,
                    ),
                    _field(
                      controller: _legalName,
                      label: 'Legal Name',
                      enabled: canEdit,
                    ),
                    _field(
                      controller: _registration,
                      label: 'Registration Number',
                      enabled: canEdit,
                    ),
                    _ReadOnlyField(
                      label: 'Subdomain',
                      value: _text(config['subdomain']),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: 'Contact',
                  subtitle: 'Contact details used across school communication.',
                  children: [
                    _field(
                      controller: _email,
                      label: 'Contact Email',
                      enabled: canEdit,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _field(
                      controller: _phone,
                      label: 'Contact Phone',
                      enabled: canEdit,
                      keyboardType: TextInputType.phone,
                    ),
                    _field(
                      controller: _websiteUrl,
                      label: 'Website URL',
                      enabled: canEdit,
                      keyboardType: TextInputType.url,
                    ),
                    _field(
                      controller: _logoUrl,
                      label: 'Logo URL',
                      enabled: canEdit,
                      keyboardType: TextInputType.url,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: 'Address',
                  subtitle: 'Physical location and jurisdiction.',
                  children: [
                    _field(
                      controller: _address1,
                      label: 'Address Line 1',
                      enabled: canEdit,
                    ),
                    _field(
                      controller: _address2,
                      label: 'Address Line 2',
                      enabled: canEdit,
                    ),
                    _field(
                      controller: _city,
                      label: 'City',
                      enabled: canEdit,
                    ),
                    _field(
                      controller: _province,
                      label: 'Province / State',
                      enabled: canEdit,
                    ),
                    _field(
                      controller: _countryCode,
                      label: 'Country Code',
                      enabled: canEdit,
                      required: true,
                      hint: 'e.g. ZW',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  title: 'Regional Defaults',
                  subtitle: 'Backend defaults used for dates and money.',
                  children: [
                    _field(
                      controller: _timezone,
                      label: 'Timezone',
                      enabled: canEdit,
                      required: true,
                      hint: 'e.g. Africa/Harare',
                    ),
                    _field(
                      controller: _currency,
                      label: 'Default Currency',
                      enabled: canEdit,
                      required: true,
                      hint: 'e.g. USD',
                    ),
                  ],
                ),
                if (!canEdit) ...[
                  const SizedBox(height: 16),
                  const StitchCard(
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline_rounded),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your active role can view this configuration but cannot change it.',
                            style: TextStyle(color: AppTheme.stitchMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required bool enabled,
    bool required = false,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: required
          ? (value) => value == null || value.trim().isEmpty
              ? '$label is required.'
              : null
          : null,
    );
  }

  static String _text(dynamic value) => value?.toString() ?? '';
}

class _SubscriptionCard extends StatelessWidget {
  final Map<String, dynamic> config;
  const _SubscriptionCard({required this.config});

  @override
  Widget build(BuildContext context) {
    return StitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StitchSectionHeader(
            title: 'Platform Status',
            subtitle: 'Managed by the ZivoConnect platform.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StitchChip(
                label: 'School: ${config['status'] ?? 'unknown'}',
                variant: config['status'] == 'active'
                    ? StitchChipVariant.success
                    : StitchChipVariant.warn,
              ),
              StitchChip(
                label: 'Plan: ${config['plan_code'] ?? '—'}',
                variant: StitchChipVariant.neutral,
              ),
              StitchChip(
                label: 'Subscription: ${config['subscription_status'] ?? '—'}',
                variant: config['subscription_status'] == 'active'
                    ? StitchChipVariant.success
                    : StitchChipVariant.neutral,
              ),
            ],
          ),
          if (config['current_period_ends_at'] != null) ...[
            const SizedBox(height: 10),
            Text(
              'Current period ends: ${config['current_period_ends_at']}',
              style: const TextStyle(
                color: AppTheme.stitchMuted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return StitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StitchSectionHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 700) {
                return Column(
                  children: children
                      .map(
                        (child) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: child,
                        ),
                      )
                      .toList(),
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: children
                    .map(
                      (child) => SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: child,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, enabled: false),
      child: Text(value.isEmpty ? '—' : value),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 44),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
