import 'package:amuwak_core/amuwak_core.dart';
import 'package:amuwak_core/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/customer_session.dart';

/// The customer's account tab: their contact details (read-only for v1) and a
/// sign-out action. Editing a profile is a later increment; the router's auth
/// redirect sends the user back to /login the moment [AuthService.signOut]
/// clears the session.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = ref.watch(currentCustomerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: customer.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text("Couldn't load your profile")),
        data: (c) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _ProfileCard(customer: c),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              onPressed: () => ref.read(authServiceProvider).signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.customer});

  final Customer? customer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = customer?.name ?? 'Your account';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: const Icon(Icons.person_outline, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(name, style: theme.textTheme.titleLarge),
              ),
            ],
          ),
          if (customer != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _DetailRow(icon: Icons.phone_outlined, value: customer!.phone),
            if (customer!.email != null && customer!.email!.isNotEmpty)
              _DetailRow(icon: Icons.email_outlined, value: customer!.email!),
            if (customer!.address != null && customer!.address!.isNotEmpty)
              _DetailRow(icon: Icons.place_outlined, value: customer!.address!),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.secondaryText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
