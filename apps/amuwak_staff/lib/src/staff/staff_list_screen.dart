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

  /// A factory rather than a stream, so Retry can genuinely re-subscribe. A
  /// bare Stream cannot be re-listened to once it has errored, which would make
  /// the retry button a lie.
  final Stream<List<StaffData>> Function() staff;
  final ResetStaffMfaFn onReset;

  /// Used to hide the reset action on the manager's own row. The server refuses
  /// a self-reset anyway; hiding it avoids walking them into a certain error.
  final String currentStaffId;

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  /// Bumped by Retry. Used as the StreamBuilder's key so a new subscription is
  /// created rather than the failed one being reused.
  int _attempt = 0;

  /// Set for the whole confirm-and-reset round trip, and it disables EVERY row
  /// rather than the one tapped — one reset at a time is the only state this
  /// screen has to be honest about.
  ///
  /// Nothing on the list says a reset is running: the dialog is gone, the row
  /// looks untouched, and the request is a network round trip on whatever
  /// connection the shop has. Tapping again is the obvious thing to do, and
  /// unguarded it starts a second concurrent reset of the same person — which
  /// clears nothing, reports "had no two-factor set up" about the rider whose
  /// factor was just removed, and writes a factors_cleared = 0 row into a log
  /// that exists to record what actually happened. Same guard, and the same
  /// reasoning, as the actions on [MfaEnrolmentScreen].
  bool _busy = false;

  Future<void> _confirmAndReset(StaffData member) async {
    setState(() => _busy = true);
    try {
      await _runConfirmAndReset(member);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runConfirmAndReset(StaffData member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset two-factor?'),
        // Deliberately not "signed out everywhere": deleteFactor's cascade is
        // scoped to sessions elevated by the deleted factor, and when they have
        // no factor enrolled nothing happens to their sessions at all. The
        // runbook was softened for the same reason in 719e195.
        content: Text(
          '${member.displayName} will sign in with just their password and be '
          'asked to set up a new authenticator.',
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

    // Captured before the await to stay off `use_build_context_synchronously`,
    // and that is ALL it buys. If a sign-out or session expiry swaps the tree
    // while the round trip is open, this handle refers to a messenger with no
    // Scaffolds left under it, and showSnackBar asserts on exactly that
    // (`_scaffolds.isNotEmpty`) rather than failing quietly. Hence the
    // `mounted` re-check below — the idiom the dashboard already uses.
    final messenger = ScaffoldMessenger.of(context);

    // Decide the message first, show it once. Three separate snackbar calls
    // would each need their own guard, and the one that got forgotten would be
    // the one that fired.
    //
    // Not `final`: Dart rejects a final local assigned in both a try and its
    // catch, since the try could throw after assigning.
    String message;
    try {
      final cleared = await widget.onReset(staffId: member.id);
      message = cleared == 0
          ? '${member.displayName} had no two-factor set up.'
          : 'Cleared two-factor for ${member.displayName}.';
    } on ResetMfaFailure catch (e) {
      message = e.message;
    } catch (_) {
      message = 'Could not reset their two-factor. Please try again.';
    }
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff')),
      body: StreamBuilder<List<StaffData>>(
        key: ValueKey(_attempt),
        stream: widget.staff(),
        builder: (context, snapshot) {
          // An RLS rejection or a dropped connection leaves data null AND
          // hasError true. Without this branch the screen spins forever with no
          // message and no way out — the failure a manager on a poor network
          // actually hits.
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load staff. Please try again.'),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () => setState(() => _attempt++),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
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
                onTap: (isSelf || _busy)
                    ? null
                    : () => _confirmAndReset(member),
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
