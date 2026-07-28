import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';

import 'invite_staff_service.dart';

/// Manager-only form for inviting a new staff member. The caller (dashboard)
/// gates entry on the manager role and passes [invite], which forwards to the
/// `invite-staff` Edge Function. The inviting manager assigns the new role —
/// the form defaults to the lowest field role (driver) but a manager may pick
/// any role, including manager. The invitee never chooses their own role.
class InviteStaffScreen extends StatefulWidget {
  const InviteStaffScreen({super.key, required this.invite});

  final InviteStaffFn invite;

  @override
  State<InviteStaffScreen> createState() => _InviteStaffScreenState();
}

class _InviteStaffScreenState extends State<InviteStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();

  // Values mirror the staff.role CHECK constraint (migration 0002). Default is
  // the lowest role.
  static const _roles = <({String value, String label})>[
    (value: 'driver', label: 'Rider (driver)'),
    (value: 'in_shop', label: 'In-shop'),
    (value: 'manager', label: 'Manager'),
  ];
  String _role = 'driver';

  String? _errorMessage;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    final email = _emailController.text.trim().toLowerCase();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.invite(
        email: email,
        displayName: _displayNameController.text.trim(),
        username: _usernameController.text.trim().toLowerCase(),
        role: _role,
      );
      if (!mounted) return;
      _emailController.clear();
      _displayNameController.clear();
      _usernameController.clear();
      setState(() => _role = 'driver');
      messenger.showSnackBar(
        SnackBar(content: Text('Invitation sent to $email')),
      );
    } on InviteFailure catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      // Network errors (SocketException, etc.) thrown before the Edge Function
      // responds aren't FunctionExceptions, so they never become InviteFailure —
      // surface a generic message rather than letting them propagate uncaught.
      if (mounted) {
        setState(
          () => _errorMessage = 'Could not send the invite. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Invite staff')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'They will get an email to set a password and finish '
                  'setting up their account.',
                  style: TextStyle(fontSize: 14, color: AppColors.secondaryText),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Enter an email';
                    if (!isValidEmail(value)) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _displayNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter a display name'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter a username'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                  items: [
                    for (final r in _roles)
                      DropdownMenuItem(value: r.value, child: Text(r.label)),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _role = v ?? 'driver'),
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppRadii.field),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send invite', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
