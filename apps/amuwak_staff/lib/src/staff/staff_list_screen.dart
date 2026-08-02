import 'package:amuwak_core/amuwak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dashboard/dashboard_header_content.dart'; // roleLabel
import '../data/app_database.dart';
import 'reset_staff_mfa_service.dart';

/// Managers-only list of staff, whose one action is clearing a lost
/// authenticator. RLS already allows this read: `staff_self_read` (migration
/// 0007) lets a manager select every staff row.
///
/// It deliberately does NOT show whether each person has two-factor on. Factor
/// status is admin-only data, so displaying it would mean a second privileged
/// endpoint for something cosmetic. The reset is idempotent instead and reports
/// what it actually did.
///
/// Dependencies arrive as parameters rather than through providers, matching
/// [InviteStaffScreen], so the widget test never touches Supabase.
class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({
    super.key,
    required this.staff,
    required this.onReset,
    required this.currentStaffId,
  });

  final Stream<List<StaffData>> staff;
  final ResetStaffMfaFn onReset;

  /// Used to hide the reset action on the manager's own row. The server refuses
  /// a self-reset anyway; hiding it avoids walking them into a certain error.
  final String currentStaffId;

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  Future<void> _confirmAndReset(StaffData member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset two-factor?'),
        content: Text(
          '${member.displayName} will be signed out everywhere and will sign '
          'in with just their password, then set up a new authenticator.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset two-factor'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final cleared = await widget.onReset(staffId: member.id);
      messenger.showSnackBar(SnackBar(
        content: Text(cleared == 0
            ? '${member.displayName} had no two-factor set up.'
            : 'Cleared two-factor for ${member.displayName}.'),
      ));
    } on ResetMfaFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not reset their two-factor. Please try again.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff')),
      body: StreamBuilder<List<StaffData>>(
        stream: widget.staff,
        builder: (context, snapshot) {
          final members = snapshot.data;
          if (members == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: members.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final member = members[i];
              final isSelf = member.id == widget.currentStaffId;
              return AppCard(
                onTap: isSelf ? null : () => _confirmAndReset(member),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.displayName),
                          Text(
                            roleLabel(member.role) ?? member.role,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (!isSelf) const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
