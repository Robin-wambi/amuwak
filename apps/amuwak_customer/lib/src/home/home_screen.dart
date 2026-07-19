import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/customer_session.dart';
import '../pricing/pricing_providers.dart';

/// The customer's landing dashboard ("Discover"): a branded header, the two
/// return-time promises, and a tile per service that opens the place-order
/// wizard pre-filled. The rate shown on each tile is the live per-kg default
/// from [pricingSettingsProvider]; it degrades to a neutral hint while pricing
/// is loading or unavailable so the tiles always render.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = ref.watch(currentCustomerProvider).valueOrNull;
    final rateHint = ref.watch(pricingSettingsProvider).when(
          data: (s) => 'from ${formatUgx(s.defaultRatePerKgUgx.round())}/kg',
          loading: () => 'Tap to get an estimate',
          error: (_, __) => 'Tap to get an estimate',
        );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _Header(customerName: customer?.name),
            const SizedBox(height: AppSpacing.lg),
            const _ReturnPromises(),
            const SizedBox(height: AppSpacing.xl),
            Text('Services', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            _ServiceGrid(rateHint: rateHint),
            const SizedBox(height: AppSpacing.xl),
            Text('Quick actions',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            const _QuickActions(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.customerName});

  final String? customerName;

  @override
  Widget build(BuildContext context) {
    final greeting =
        customerName == null ? 'Welcome to Amuwak' : 'Hi, $customerName';
    return AnimatedGradientHeader(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppColors.white),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Quote, schedule & track — one calm dashboard.',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(color: AppColors.white),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Inbox',
            onPressed: () => context.go('/inbox'),
            icon: const Icon(Icons.notifications_none, color: AppColors.white),
          ),
        ],
      ),
    );
  }
}

class _ReturnPromises extends StatelessWidget {
  const _ReturnPromises();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _PromiseCard(
            eyebrow: 'STANDARD RETURN',
            title: '2–4 days',
            detail: 'Everyday laundry, cleaned and returned.',
          ),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: _PromiseCard(
            eyebrow: 'BULKY RETURN',
            title: 'Up to 7 days',
            detail: 'Duvets, curtains and other bulky items.',
          ),
        ),
      ],
    );
  }
}

class _PromiseCard extends StatelessWidget {
  const _PromiseCard({
    required this.eyebrow,
    required this.title,
    required this.detail,
  });

  final String eyebrow;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: AppColors.secondaryText)),
          const SizedBox(height: AppSpacing.xs),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(detail, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.rateHint});

  final String rateHint;

  static const _icons = <ServiceType, IconData>{
    ServiceType.washAndIron: Icons.local_laundry_service_outlined,
    ServiceType.dryCleaning: Icons.dry_cleaning_outlined,
    ServiceType.ironOnly: Icons.iron_outlined,
    ServiceType.washOnly: Icons.wash_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.35,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final service in ServiceType.values)
          _ServiceTile(
            service: service,
            icon: _icons[service]!,
            rateHint: rateHint,
          ),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.service,
    required this.icon,
    required this.rateHint,
  });

  final ServiceType service;
  final IconData icon;
  final String rateHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: () => context.go('/orders/new?service=${service.name}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.field),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(service.label, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(rateHint,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.secondaryText)),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.calendar_month_outlined,
            label: 'Schedule pickup',
            onTap: () => context.go('/orders/new'),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _ActionButton(
            icon: Icons.bolt_outlined,
            label: 'Express clean',
            onTap: () => context.go('/orders/new?express=1'),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}
