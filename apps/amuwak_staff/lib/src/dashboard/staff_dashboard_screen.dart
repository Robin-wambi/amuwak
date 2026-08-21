import 'dart:convert' as convert;
import 'dart:developer' as developer;

import 'package:amuwak_core/amuwak_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../auth/mfa_enrolment_screen.dart';
import '../auth/sign_out_provider.dart';
import 'business_glance.dart';
import '../customers/customer_form_screen.dart';
import '../customers/customer_import_screen.dart';
import '../customers/customers_list_screen.dart';
import '../data/app_database.dart' show Customer;
import '../expenses/expenses_list_screen.dart';
import 'current_staff_provider.dart';
import 'dashboard_header_content.dart';
import '../notifications/notification_summary.dart';
import '../notifications/notifications_screen.dart';
import '../expenses/expense.dart';
import '../expenses/expense_entry_screen.dart';
import '../orders/customer_photo_url.dart';
import '../orders/geo_services.dart';
import '../orders/new_pickup_result.dart';
import '../orders/new_pickup_screen.dart';
import '../orders/order.dart';
import '../orders/edit_order_screen.dart';
import '../orders/order_details_screen.dart';
import '../orders/order_filter.dart';
import '../orders/order_filter_screen.dart';
import '../orders/order_list_extensions.dart';
import '../orders/order_search_screen.dart';
import '../orders/widgets/order_card_list.dart';
import '../orders/proof/barcode_reader.dart';
import '../orders/proof/pickup_capture_screen.dart';
import '../orders/proof/proof_photo_storage.dart';
import '../reports/daily_report_screen.dart';
import '../reports/items_breakdown_screen.dart';
import '../pricing/catalog_item.dart';
import '../pricing/pricing_providers.dart';
import '../pricing/pricing_settings.dart';
import '../pricing/pricing_settings_screen.dart';
import '../pricing/pricing_catalog_screen.dart';
import '../staff/invite_staff_screen.dart';
import '../staff/staff_list_screen.dart';
import '../printing/printing_providers.dart';
import '../sync/repository_providers.dart';
// Phase 5 (offline UX): re-add these to surface pending/dead-letter state.
// import '../shared/widgets/sync_status_banner.dart';
// import '../sync/sync_errors_provider.dart';
// import '../sync/sync_errors_screen.dart';

typedef RetrieveLostPhotoFn = Future<bool> Function();

/// Optional injectable for tests: lets a test pump the dashboard, tap the
/// sign-out menu item, and observe the call WITHOUT having to override every
/// transitive Riverpod provider that `signOutAndReset` would resolve through.
typedef SignOutFn = Future<void> Function(WidgetRef ref);

/// Optional injectable for tests: opens the New Pickup form and returns its
/// result, so a test can drive the post-pickup handoff (poll the stream → open
/// PickupCaptureScreen) without having to complete the whole pickup form. The
/// default builds and pushes the real [NewPickupScreen].
typedef OpenNewPickupFn = Future<NewPickupResult?> Function(
  BuildContext context, {
  required PricingSettings settings,
  required String staffId,
});

class StaffDashboardScreen extends ConsumerStatefulWidget {
  const StaffDashboardScreen({
    super.key,
    this.retrieveLostPhoto,
    this.signOut,
    this.openNewPickup,
  });

  // On Android the OS may kill MainActivity while the camera is open, dropping
  // the photo bytes silently. We check on startup so the rider knows to retry
  // instead of believing the capture succeeded. iOS is a no-op (empty response).
  final RetrieveLostPhotoFn? retrieveLostPhoto;

  /// Test seam — defaults to the real `signOutAndReset(...)` flow wired
  /// through the auth + orchestrator + database providers.
  final SignOutFn? signOut;

  /// Test seam — defaults to building + pushing the real [NewPickupScreen].
  final OpenNewPickupFn? openNewPickup;

  @override
  ConsumerState<StaffDashboardScreen> createState() =>
      _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends ConsumerState<StaffDashboardScreen> {
  int _selectedTabIndex = 0;

  // Backend deferred per SPEC-000: photos live in memory only. Swap for
  // `createDefaultProofPhotoStorage()` once the upload endpoint is available.
  final ProofPhotoStorage _photoStorage = InMemoryProofPhotoStorage();
  final ImagePicker _imagePicker = ImagePicker();
  final CameraViewBuilder _cameraViewBuilder = mobileScannerCameraViewBuilder();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final retriever = widget.retrieveLostPhoto ?? _defaultRetrieveLostPhoto;
      final lost = await retriever();
      if (!mounted || !lost) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your last photo capture was interrupted. Please retry.',
          ),
        ),
      );
    });
  }

  Future<bool> _defaultRetrieveLostPhoto() async {
    try {
      final response = await _imagePicker.retrieveLostData();
      if (response.isEmpty) return false;
      return response.file != null ||
          (response.files?.isNotEmpty ?? false) ||
          response.exception != null;
    } catch (e, st) {
      developer.log('Lost-photo retrieval failed.',
          name: 'StaffDashboard', error: e, stackTrace: st);
      return false;
    }
  }

  Future<List<int>?> _pickPhoto() async {
    final XFile? file = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (file == null) return null;
    return file.readAsBytes();
  }

  /// Confirms intent, then either runs the injected `signOut` callback (test
  /// seam) or wires `signOutAndReset` through the real orchestrator / db / auth
  /// providers. On success there is NO manual navigation: clearing the auth
  /// session makes the root [AuthGate] rebuild to the login screen on its own.
  /// Pushing LoginScreen here used to strand the user — it removed AuthGate from
  /// the tree, and the login form no longer self-navigates, so a later sign-in
  /// had nothing to route it to the dashboard. On failure, surface a SnackBar —
  /// leaving them on a half-cleared dashboard would be worse.
  Future<void> _onSignOutPressed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Sign out of this device? You will need to sign in again to '
          'continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final signOut = widget.signOut ?? _defaultSignOut;
      await signOut(ref);
    } catch (e, st) {
      developer.log('Sign-out failed.',
          name: 'StaffDashboard', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not sign out. Please try again.'),
        ),
      );
      return;
    }
    // No navigation here — AuthGate routes to LoginScreen once the session clears.
  }

  /// Production wiring: [signOutAndResetFromRef] resolves the auth service,
  /// sync orchestrator, and local database from Riverpod and hands them to
  /// `signOutAndReset`, which stops the sync engine and truncates the local
  /// cache before revoking the session. Shared with the MFA challenge screen
  /// so both sign-out controls tear the same things down.
  Future<void> _defaultSignOut(WidgetRef ref) => signOutAndResetFromRef(ref);

  Future<void> _handleNewPickup() async {
    final staffId = ref.read(currentUserIdProvider);
    if (staffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired — please sign in again.'),
        ),
      );
      return;
    }
    final PricingSettings settings;
    try {
      settings = ref.read(pricingSettingsProvider).valueOrNull ??
          await ref.read(pricingSettingsRepositoryProvider).fetch();
    } catch (e, st) {
      developer.log('Pricing settings fetch failed.',
          name: 'StaffDashboard', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pricing settings missing — contact admin.'),
        ),
      );
      return;
    }
    if (!mounted) return;
    final opener = widget.openNewPickup;
    final NewPickupResult? result;
    if (opener != null) {
      result = await opener(context, settings: settings, staffId: staffId);
    } else {
      result = await Navigator.of(context).push<NewPickupResult>(
        MaterialPageRoute(
          builder: (_) => NewPickupScreen(
            customersRepo: ref.read(customersRepositoryProvider),
            ordersRepo: ref.read(ordersRepositoryProvider),
            actorStaffId: staffId,
            clock: DateTime.now,
            orderIdGenerator: defaultUuidV7,
            customerIdGenerator: defaultUuidV7,
            geolocate: createDefaultGeolocate(),
            reverseGeocode: createDefaultReverseGeocode(),
            defaultRatePerKgUgx: settings.defaultRatePerKgUgx,
            minRatePctOfDefault: settings.minRatePctOfDefault,
            isManager: ref.read(currentRoleProvider) == 'manager',
            deliveryFeeUgx: settings.deliveryFeeUgx,
            expressFlatUgx: settings.expressFlatUgx,
            expressPct: settings.expressPct,
          ),
        ),
      );
    }
    if (result == null || !mounted) return;
    if (!result.startPickupNow) return;
    // createPickup commits the order to the local Drift DB synchronously before
    // returning, and ordersStreamProvider watches Drift — so the new order is
    // normally in the snapshot on the first iteration. Poll defensively anyway:
    // the Drift watch → Riverpod rebuild hop is async, so the freshly-written
    // row may not have propagated into ordersStreamProvider's value on the very
    // first read. Without this, the new pickup would land on the dashboard
    // instead of PickupCaptureScreen if the rebuild hadn't fired yet. The window
    // (20 × 100ms = 2s) is generous slack for that local hop; beyond it we fall
    // back to the "open from the list" hint below.
    // TODO(phase-5): local reads make this synchronous — read the order directly
    // after createPickup returns instead of polling. See the plan doc.
    LaundryOrder? newOrder;
    for (var attempt = 0; attempt < 20; attempt++) {
      final orders = ref.read(ordersStreamProvider).valueOrNull ?? const [];
      for (final o in orders) {
        if (o.orderId == result.orderId) {
          newOrder = o;
          break;
        }
      }
      if (newOrder != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }
    if (!mounted) return;
    if (newOrder == null) {
      // The order was written but the stream hadn't re-emitted within the
      // poll window (slow device / heavy load). Don't strand the rider on a
      // silent dead-end — the order exists; point them at the list.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order created — open it from the list to start pickup.'),
        ),
      );
      return;
    }
    final catalogItems = await _loadCatalogItems();
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PickupCaptureScreen(
          order: newOrder!,
          photoStorage: _photoStorage,
          pickPhoto: _pickPhoto,
          ordersRepo: ref.read(ordersRepositoryProvider),
          proofEventsRepo: ref.read(proofEventsRepositoryProvider),
          actorStaffId: staffId,
          labelPrinter: ref.read(labelPrinterProvider),
          printerStore: ref.read(printerStoreProvider),
          catalogItems: catalogItems,
          customerPhotoUrl: ref.read(customerPhotoUrlResolverProvider),
        ),
      ),
    );
  }

  Future<void> _openOrderDetails(LaundryOrder order) async {
    // Critical: actorStaffId must NEVER be empty downstream. Postgres has
    // intake_recorded_by/created_by as NOT NULL REFERENCES staff(id), so an
    // empty string would FK-fail the outbox dispatch and silently dead-letter
    // the row. Refuse to open details if the session hasn't hydrated yet
    // (cold-start race) or has expired.
    final staffId = ref.read(currentUserIdProvider);
    if (staffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired — please sign in again.'),
        ),
      );
      return;
    }
    // Warm the catalog for the "Add item" picker. Best-effort: a failed/slow
    // read just falls back to free-form line entry.
    final catalogItems = await _loadCatalogItems();
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(
          order: order,
          photoStorage: _photoStorage,
          pickPhoto: _pickPhoto,
          cameraViewBuilder: _cameraViewBuilder,
          ordersRepo: ref.read(ordersRepositoryProvider),
          proofEventsRepo: ref.read(proofEventsRepositoryProvider),
          actorStaffId: staffId,
          labelPrinter: ref.read(labelPrinterProvider),
          printerStore: ref.read(printerStoreProvider),
          catalogItems: catalogItems,
          customerPhotoUrl: ref.read(customerPhotoUrlResolverProvider),
        ),
      ),
    );
    // No-op on return — the stream picks up the write (after Task 10/11/12
    // wire writes through the repositories).
  }

  /// Opens the descriptive-fields edit form for an order. Same session guard as
  /// [_openOrderDetails]; the save is wired to `updateOrderDetails` (which can't
  /// touch pricing/status). The orders stream re-emits the edited order on save.
  Future<void> _editOrder(LaundryOrder order) async {
    final staffId = ref.read(currentUserIdProvider);
    if (staffId == null) {
      _showSessionExpired();
      return;
    }
    final repo = ref.read(ordersRepositoryProvider);
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditOrderScreen(
          order: order,
          save: (updated) =>
              repo.updateOrderDetails(updated, actorStaffId: staffId),
        ),
      ),
    );
  }

  /// Soft-deletes an order. The card already confirmed the intent; here we just
  /// run the write and surface the outcome. The stream re-emits without the
  /// order, so the card disappears on its own.
  Future<void> _deleteOrder(LaundryOrder order) async {
    final staffId = ref.read(currentUserIdProvider);
    if (staffId == null) {
      _showSessionExpired();
      return;
    }
    try {
      await ref
          .read(ordersRepositoryProvider)
          .softDelete(order.orderId, actorStaffId: staffId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              // A placeholder order has no server code yet — name the customer
              // rather than echo the raw UUID.
              order.hasServerCode
                  ? 'Order ${order.orderCode} deleted.'
                  : 'Order for ${order.customerName} deleted.',
            ),
          ),
        );
    } catch (e, st) {
      developer.log('softDelete failed for order ${order.orderId}.',
          name: 'StaffDashboard', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete — please retry.')),
      );
    }
  }

  /// Advances an order to its next status. The card only offers this for the
  /// proof-less in-progress → ready step; pickup/delivery route into Details'
  /// proof capture instead.
  Future<void> _advanceOrderStatus(LaundryOrder order) async {
    final next = order.status.nextStatus;
    if (next == null) return;
    final staffId = ref.read(currentUserIdProvider);
    if (staffId == null) {
      _showSessionExpired();
      return;
    }
    try {
      await ref
          .read(ordersRepositoryProvider)
          .updateStatus(order.orderId, next, actorStaffId: staffId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text('Order moved to ${next.label}.')),
        );
    } catch (e, st) {
      developer.log('updateStatus failed for order ${order.orderId}.',
          name: 'StaffDashboard', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update status — please retry.')),
      );
    }
  }

  void _showSessionExpired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session expired — please sign in again.')),
    );
  }

  void _openPricingSettings() {
    final staffId = ref.read(currentUserIdProvider);
    if (staffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired — please sign in again.')),
      );
      return;
    }
    final repo = ref.read(pricingSettingsRepositoryProvider);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PricingSettingsScreen(
          load: repo.fetch,
          save: ({
            required ratePerKgUgx,
            required deliveryFeeUgx,
            required expressFlatUgx,
            required expressPct,
          }) =>
              repo.updateSettings(
            ratePerKgUgx: ratePerKgUgx,
            deliveryFeeUgx: deliveryFeeUgx,
            expressFlatUgx: expressFlatUgx,
            expressPct: expressPct,
            actorStaffId: staffId,
          ),
          onManageCatalog: _openPricingCatalog,
        ),
      ),
    ).then((_) => ref.invalidate(pricingSettingsProvider));
  }

  /// Loads the active catalog for the "Add item" pickers (pickup capture +
  /// order details). Best-effort: a failed/slow read just falls back to
  /// free-form line entry. Callers must re-check `mounted` after awaiting.
  Future<List<CatalogItem>> _loadCatalogItems() async {
    return ref.read(pricingCatalogProvider).valueOrNull ??
        await ref.read(pricingCatalogProvider.future).catchError(
          (Object e, StackTrace st) {
            developer.log('Catalog load failed; using free-form entry only.',
                name: 'StaffDashboard', error: e, stackTrace: st);
            return const <CatalogItem>[];
          },
        );
  }

  /// Opens the manager-only invite form. Entry is already gated to managers in
  /// the Account tab; the Edge Function re-checks the caller's role server-side,
  /// so this is convenience gating, not the security boundary.
  void _openInviteStaff() {
    final service = ref.read(inviteStaffServiceProvider);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => InviteStaffScreen(invite: service.invite),
      ),
    );
  }

  void _openStaffList() {
    final resetService = ref.read(resetStaffMfaServiceProvider);
    final staffRepo = ref.read(staffRepositoryProvider);
    final myId = ref.read(currentUserIdProvider) ?? '';
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StaffListScreen(
          staff: staffRepo.watchAll,
          onReset: resetService.reset,
          currentStaffId: myId,
        ),
      ),
    );
  }

  void _openTwoFactor() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => MfaEnrolmentScreen(
          onCompleted: ({required enabled}) {
            Navigator.of(routeContext).pop();
            // The Account entry reads its On/Off label from this provider, so
            // it has to be re-asked or the card contradicts what just happened.
            ref.invalidate(mfaEnabledProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(enabled
                    ? 'Two-factor authentication is on.'
                    : 'Two-factor authentication is off.'),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openPricingCatalog() {
    final catalogRepo = ref.read(pricingCatalogRepositoryProvider);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PricingCatalogScreen(
          load: catalogRepo.fetchAll,
          save: catalogRepo.upsertItem,
          idGenerator: defaultUuidV7,
        ),
      ),
    ).then((_) => ref.invalidate(pricingCatalogProvider));
  }

  /// Opens the "record an expense" form. Writes go straight to Supabase; the
  /// expenses stream re-emits and the report's Net updates on its own. Mirrors
  /// the session guard in [_openPricingSettings].
  void _openAddExpense() {
    final staffId = ref.read(currentUserIdProvider);
    if (staffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired — please sign in again.')),
      );
      return;
    }
    final repo = ref.read(expensesRepositoryProvider);
    Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ExpenseEntryScreen(
          save: (expense) => repo.addExpense(expense, actorStaffId: staffId),
        ),
      ),
    );
  }

  /// Soft-deletes an expense from the Expenses tab after a confirm. The stream
  /// re-emits and the row drops off; a failure surfaces a retry SnackBar.
  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
            '${expense.category.label} — ${formatUgx(expense.amountUgx)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(expensesRepositoryProvider).softDelete(expense.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete — please retry.')),
      );
    }
  }

  /// Opens the standalone Daily Report. It lost its bottom-nav tab to Expenses,
  /// so it's reached from the Home "Report" quick action and the Account tab.
  /// A [Consumer] keeps it live off the orders/expenses streams.
  void _openReport() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Daily report',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          body: Consumer(
            builder: (context, ref, _) => DailyReportView(
              orders: ref.watch(ordersStreamProvider).valueOrNull ??
                  const <LaundryOrder>[],
              expenses: ref.watch(expensesStreamProvider).valueOrNull ??
                  const <Expense>[],
              onOpenFiltered: _openFilteredOrders,
              onOpenItems: _openItemsBreakdown,
              onAddExpense: _openAddExpense,
            ),
          ),
        ),
      ),
    );
  }

  /// Opens the add/edit customer form. Prefetches the customer list so the form
  /// can reject a phone that duplicates an existing record. [existing] edits.
  Future<void> _openCustomerForm({Customer? existing}) async {
    final repo = ref.read(customersRepositoryProvider);
    // Null settings degrade to a disabled floor and no default-rate hint: the
    // form still saves, it just can't show or enforce a floor — the same way
    // the rest of this screen treats an unloaded settings row.
    final settings = ref.read(pricingSettingsProvider).valueOrNull;
    final canEditRate = ref.read(currentRoleProvider) == 'manager';
    var existingCustomers = const <Customer>[];
    try {
      existingCustomers = await repo.getAll();
    } catch (_) {
      // Dedup is best-effort; proceed with none if the fetch fails.
    }
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(
          save: repo.upsertCustomer,
          existing: existing,
          existingCustomers: existingCustomers,
          canEditRate: canEditRate,
          defaultRatePerKgUgx: settings?.defaultRatePerKgUgx ?? 0,
          minRatePctOfDefault: settings?.minRatePctOfDefault ?? 0,
        ),
      ),
    );
  }

  /// Opens the CSV bulk-import flow, wiring the real file picker + repository.
  Future<void> _openCustomerImport() async {
    final repo = ref.read(customersRepositoryProvider);
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CustomerImportScreen(
          pickCsvText: _pickCsvText,
          loadExisting: repo.getAll,
          importCustomers: repo.importCustomers,
        ),
      ),
    );
  }

  /// Prompts for a CSV file and returns its UTF-8 text (null if cancelled).
  /// `withData` so the bytes arrive without a filesystem path (web-safe).
  Future<String?> _pickCsvText() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final bytes = result.files.first.bytes;
    if (bytes == null) return null;
    return convert.utf8.decode(bytes, allowMalformed: true);
  }

  void _openOrderSearch() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OrderSearchScreen(
          onOrderTap: _openOrderDetails,
          cameraViewBuilder: _cameraViewBuilder,
          onEditOrder: _editOrder,
          onDeleteOrder: _deleteOrder,
          onAdvanceOrderStatus: _advanceOrderStatus,
        ),
      ),
    );
  }

  /// Opens the read-only list of orders behind a tapped summary card. The
  /// session check + repository wiring live in [_openOrderDetails], which the
  /// filter screen calls on tap.
  void _openFilteredOrders(OrderFilter filter, {String? title}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OrderFilterScreen(
          filter: filter,
          onOrderTap: _openOrderDetails,
          onEditOrder: _editOrder,
          onDeleteOrder: _deleteOrder,
          onAdvanceOrderStatus: _advanceOrderStatus,
          onNewPickup: _handleNewPickup,
          title: title,
        ),
      ),
    );
  }

  /// Opens the items breakdown behind the daily report's "Items" card. Reuses
  /// [_openOrderDetails] for row taps so the session check + repository wiring
  /// live in one place.
  void _openItemsBreakdown() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ItemsBreakdownScreen(
          onOrderTap: _openOrderDetails,
          onEditOrder: _editOrder,
          onDeleteOrder: _deleteOrder,
          onAdvanceOrderStatus: _advanceOrderStatus,
        ),
      ),
    );
  }

  void _selectTab(int index) {
    setState(() {
      _selectedTabIndex = index;
    });
  }

  // ONLINE-ONLY: the SyncErrorsScreen is unreachable while offline is disabled.
  // Restore by re-adding the import and this navigation helper:
  //   void _openSyncErrors() {
  //     Navigator.of(context).push<void>(
  //       MaterialPageRoute(builder: (_) => const SyncErrorsScreen()),
  //     );
  //   }

  String get _title {
    switch (_selectedTabIndex) {
      case 1:
        return 'Orders';
      case 2:
        return 'Expenses';
      case 3:
        return 'Customers';
      case 4:
        return 'Account';
      default:
        return 'Amuwak Staff';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersStreamProvider);
    // Customer create/import/edit is gated to the roles RLS lets write the
    // customers table (in_shop, manager); a rider can still browse the list.
    final canManageCustomers =
        const {'in_shop', 'manager'}.contains(ref.watch(currentRoleProvider));
    // Badge count only: pendingPickupCount keeps the "new pickup" predicate in
    // one place (shared with the summary) while skipping the summary's sort on
    // every dashboard rebuild (e.g. tab switches).
    final newPickupCount =
        NotificationSummary.pendingPickupCount(ordersAsync.valueOrNull ?? const []);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    NotificationsScreen(onOrderTap: _openOrderDetails),
              ),
            ),
            // Badge hugs the icon (not the button's 48x48 hit-box) so the
            // count sits on the bell instead of floating in the corner.
            icon: Badge.count(
              count: newPickupCount,
              isLabelVisible: newPickupCount > 0,
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          // ONLINE-ONLY: sync-errors badge/button removed (no outbox/dead-letter
          // queue in online mode). Restore the `Consumer` that watched
          // `syncErrorCountProvider` and pushed `SyncErrorsScreen` to bring back.
        ],
      ),
      body: _DashboardTabShell(
        child: switch (_selectedTabIndex) {
          1 => ordersAsync.when(
              data: (orders) => _OrdersBody(
                orders: orders,
                onOrderTap: _openOrderDetails,
                onEditOrder: _editOrder,
                onDeleteOrder: _deleteOrder,
                onAdvanceOrderStatus: _advanceOrderStatus,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _ErrorRetry(
                onRetry: () => ref.invalidate(ordersStreamProvider),
              ),
            ),
          // Expenses tab: the ledger list. Degrade to empty while the stream
          // loads/errors so a hiccup never blanks the tab.
          2 => ExpensesListView(
              expenses: ref.watch(expensesStreamProvider).valueOrNull ??
                  const <Expense>[],
              onAddExpense: _openAddExpense,
              onDelete: _deleteExpense,
            ),
          // Customers tab: browse + search; Add / Import / tap-to-edit are gated
          // to the roles RLS lets write the customers table.
          3 => CustomersListView(
              customers: ref.watch(customersStreamProvider).valueOrNull ??
                  const <Customer>[],
              onAddCustomer: _openCustomerForm,
              onImport: _openCustomerImport,
              onCustomerTap: canManageCustomers
                  ? (customer) => _openCustomerForm(existing: customer)
                  : null,
              canManage: canManageCustomers,
            ),
          4 => _AccountTab(
              onSignOut: _onSignOutPressed,
              onOpenReport: _openReport,
              onOpenPricingSettings: _openPricingSettings,
              onInviteStaff: _openInviteStaff,
              onOpenStaff: _openStaffList,
              onOpenTwoFactor: _openTwoFactor,
              twoFactorEnabled: ref.watch(mfaEnabledProvider).valueOrNull,
              roleText:
                  roleLabel(ref.watch(currentRoleProvider)) ?? 'Operations staff',
              // Pricing writes are gated to in_shop + manager (migration 0024),
              // so drivers don't get the entry point — saving would only fail.
              canManagePricing: const {'in_shop', 'manager'}
                  .contains(ref.watch(currentRoleProvider)),
              // Only managers may write the staff table (migration 0007 RLS) and
              // the invite Edge Function rejects non-managers, so only they see
              // the entry point.
              canInviteStaff:
                  ref.watch(currentRoleProvider) == 'manager',
            ),
          // Home tab. Loading and data share one `_HomeTab` widget (orders ==
          // null means loading) so the header and quick actions stay mounted
          // across the loading→data transition instead of re-revealing. Errors
          // still take over the whole tab.
          _ => ordersAsync.hasError
              ? _ErrorRetry(
                  onRetry: () => ref.invalidate(ordersStreamProvider),
                )
              : _HomeTab(
                  orders: ordersAsync.valueOrNull,
                  onOpenFiltered: _openFilteredOrders,
                  onNewPickup: _handleNewPickup,
                  // Same RLS gate as the Customers tab: a rider cannot write
                  // `customers`, so the shortcut is withheld rather than
                  // failing at save time.
                  onAddCustomer:
                      canManageCustomers ? _openCustomerForm : null,
                  onShowReport: _openReport,
                  onCheckOrder: _openOrderSearch,
                ),
        },
      ),
      // Per-tab create action. Orders → New pickup (Home also has that quick
      // action); Expenses → Record expense (the list itself has no add control
      // once populated). Customers add via the list's own Add/Import buttons.
      floatingActionButton: switch (_selectedTabIndex) {
        1 => FloatingActionButton.extended(
            onPressed: _handleNewPickup,
            icon: const Icon(Icons.add),
            label: const Text('New pickup'),
          ),
        2 => FloatingActionButton.extended(
            onPressed: _openAddExpense,
            icon: const Icon(Icons.add),
            label: const Text('Record expense'),
          ),
        _ => null,
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Customers',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private body widgets
// ---------------------------------------------------------------------------

class _DashboardTabShell extends StatelessWidget {
  const _DashboardTabShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // ONLINE-ONLY: the SyncStatusBanner (offline/pending/sync-error indicator)
    // is removed. Restore by wrapping `child` in a Column with
    // `SyncStatusBanner(onShowErrors: ...)` above it.
    return SafeArea(child: child);
  }
}

/// The Home tab. The header and quick actions are persistent chrome: they
/// mount once (during loading, so a rider can tap straight into a new pickup)
/// and stay put when orders arrive, instead of re-revealing on the
/// loading→data swap. Only the variable middle (progress bar → Business at a
/// glance, which owns the order-count summary grid behind its own toggle)
/// reveals as it appears.
///
/// The summary cards are the entry point to the orders themselves: each is
/// tappable and opens a filtered list via [onOpenFiltered]. The full
/// assigned-orders list lives on the Orders tab, so it is intentionally NOT
/// repeated here.
///
/// [orders] is null while the stream is still loading.
class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.orders,
    required this.onOpenFiltered,
    required this.onNewPickup,
    required this.onAddCustomer,
    required this.onShowReport,
    required this.onCheckOrder,
  });

  final List<LaundryOrder>? orders;
  final void Function(OrderFilter) onOpenFiltered;
  final VoidCallback onNewPickup;

  /// Null hides the Add-customer quick action for roles RLS bars from writing
  /// the `customers` table.
  final VoidCallback? onAddCustomer;
  final VoidCallback onShowReport;
  final VoidCallback onCheckOrder;

  @override
  Widget build(BuildContext context) {
    final loading = orders == null;

    // Stagger the entrance: each content block reveals shortly after the
    // previous. The delay index is capped so long lists still appear promptly.
    var step = 0;
    Widget reveal(Widget child) {
      final cappedStep = step < 8 ? step : 8;
      step++;
      return RevealOnMount(
        delay: AppMotion.stagger * cappedStep,
        child: child,
      );
    }

    // The middle slot: a progress bar while loading. It occupies the same
    // ListView position in both states so the header above it keeps its
    // revealed state across the transition. Once orders arrive,
    // _BusinessAtAGlance renders in its place and owns the order-count
    // summary grid internally, gated by its own View all/Less toggle.
    const Widget middle = Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: LinearProgressIndicator(),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: [
        reveal(_DashboardHeader(orders: orders)),
        const SizedBox(height: AppSpacing.xl),
        if (loading)
          reveal(middle)
        else
          // No trailing SizedBox here: _BusinessAtAGlance's own internal
          // AppSpacing.xl gap sits BEFORE the summary grid (between the
          // tiles and the grid), not after it, so the widget itself never
          // ends with a spacer. The xxl gap below is the only spacing
          // needed before Quick Actions, in both toggle states.
          reveal(_BusinessAtAGlance(onOpenFiltered: onOpenFiltered)),
        const SizedBox(height: AppSpacing.xxl),
        reveal(_QuickActions(
          onNewPickup: onNewPickup,
          onAddCustomer: onAddCustomer,
          onShowReport: onShowReport,
          onCheckOrder: onCheckOrder,
        )),
      ],
    );
  }
}

class _OrdersBody extends StatefulWidget {
  const _OrdersBody({
    required this.orders,
    required this.onOrderTap,
    required this.onEditOrder,
    required this.onDeleteOrder,
    required this.onAdvanceOrderStatus,
  });

  final List<LaundryOrder> orders;
  final void Function(LaundryOrder) onOrderTap;
  final void Function(LaundryOrder) onEditOrder;
  final void Function(LaundryOrder) onDeleteOrder;
  final void Function(LaundryOrder) onAdvanceOrderStatus;

  @override
  State<_OrdersBody> createState() => _OrdersBodyState();
}

class _OrdersBodyState extends State<_OrdersBody> {
  final _searchController = TextEditingController();
  OrderFilter _filter = OrderFilter.all;
  String _query = '';

  // The status filters shown as chips — the same subsets as the Home summary
  // cards, so a chip count can never disagree with a card count.
  static const _filters = [
    OrderFilter.all,
    OrderFilter.pendingPickup,
    OrderFilter.inProgress,
    OrderFilter.readyForDelivery,
    OrderFilter.completedToday,
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Status chip narrows first, then the text query — same OrderFilter/searchBy
    // helpers the summary cards and search screen use.
    final visible = _filter.apply(widget.orders).searchBy(_query);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.sm,
          ),
          child: TextField(
            key: const Key('orders_search'),
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search orders by name, code or phone',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) {
              final f = _filters[i];
              return Center(
                child: FilterChip(
                  key: Key('orders_chip_${f.name}'),
                  label: Text('${f.label} (${f.count(widget.orders)})'),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: OrderCardList(
            orders: visible,
            onOrderTap: widget.onOrderTap,
            onEditOrder: widget.onEditOrder,
            onDeleteOrder: widget.onDeleteOrder,
            onAdvanceOrderStatus: widget.onAdvanceOrderStatus,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountTab extends StatelessWidget {
  const _AccountTab({
    required this.onSignOut,
    required this.onOpenReport,
    required this.onOpenPricingSettings,
    required this.onInviteStaff,
    required this.onOpenStaff,
    required this.onOpenTwoFactor,
    required this.twoFactorEnabled,
    required this.roleText,
    required this.canManagePricing,
    required this.canInviteStaff,
  });

  final VoidCallback onSignOut;

  /// Opens the Daily Report, which moved off the bottom nav to make room for
  /// the Expenses and Customers tabs.
  final VoidCallback onOpenReport;
  final VoidCallback onOpenPricingSettings;
  final VoidCallback onInviteStaff;

  /// Opens the managers-only staff list, whose action is clearing a lost
  /// authenticator.
  final VoidCallback onOpenStaff;

  /// Opens authenticator enrolment. Shown to every role — a driver's account
  /// can create and complete orders, so it is worth protecting too.
  final VoidCallback onOpenTwoFactor;

  /// Whether a verified factor exists, or null while that is unknown (still
  /// loading, or the lookup failed).
  final bool? twoFactorEnabled;

  /// Human label for the signed-in staff member's role, mirroring the header
  /// chip (falls back to a generic label when there's no role claim).
  final String roleText;

  /// Whether to show the Pricing settings entry. False for drivers, whose
  /// pricing writes are blocked server-side (migration 0024).
  final bool canManagePricing;

  /// Whether to show the Invite staff entry. Managers only — they alone may
  /// write the staff table (migration 0007) and pass the invite function's
  /// server-side role check.
  final bool canInviteStaff;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg2),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                child: Icon(
                  Icons.person_rounded,
                  color: colorScheme.primary,
                  size: 30,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Staff account',
                      style: textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Operations workspace',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg - 2),
        _AccountDetailRow(
          icon: Icons.badge_outlined,
          label: 'Role',
          value: roleText,
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        _AccountDetailRow(
          icon: Icons.schedule_outlined,
          label: 'Shift',
          value: 'Today',
        ),
        const SizedBox(height: AppSpacing.lg2),
        AppCard(
          onTap: onOpenReport,
          child: Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
              const Expanded(child: Text('Reports')),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg2),
        if (canManagePricing) ...[
          AppCard(
            onTap: onOpenPricingSettings,
            child: Row(
              children: [
                Icon(Icons.payments_outlined, color: colorScheme.primary),
                const SizedBox(width: AppSpacing.md),
                const Expanded(child: Text('Pricing settings')),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg2),
        ],
        // Optional for now: staff enrol at their own pace. Enforcement (aal2
        // in RLS) is a separate, deliberate step once everyone has a factor —
        // turning it on first would lock the fleet out of production.
        AppCard(
          onTap: onOpenTwoFactor,
          child: Row(
            children: [
              Icon(Icons.shield_outlined, color: colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
              const Expanded(child: Text('Two-factor authentication')),
              // Null while the status is still loading, or if it could not be
              // read at all — a status line is not worth a broken Account tab,
              // and the screen behind this card reports the truth either way.
              if (twoFactorEnabled != null)
                Text(
                  twoFactorEnabled! ? 'On' : 'Off',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg2),
        if (canInviteStaff) ...[
          AppCard(
            onTap: onOpenStaff,
            child: Row(
              children: [
                Icon(Icons.groups_outlined, color: colorScheme.primary),
                const SizedBox(width: AppSpacing.md),
                const Expanded(child: Text('Staff')),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg2),
          AppCard(
            onTap: onInviteStaff,
            child: Row(
              children: [
                Icon(Icons.person_add_alt_1_outlined,
                    color: colorScheme.primary),
                const SizedBox(width: AppSpacing.md),
                const Expanded(child: Text('Invite staff')),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg2),
        ],
        OutlinedButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}

class _AccountDetailRow extends StatelessWidget {
  const _AccountDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Could not load orders. Please try again.'),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private dashboard widgets (header, grid, cards, chips, actions)
// ---------------------------------------------------------------------------

/// The home greeting card: a time-aware, personalised greeting with the staff
/// member's first name and role, over a live status line (or today's date while
/// orders load). Sits on the animated brand gradient.
class _DashboardHeader extends ConsumerWidget {
  const _DashboardHeader({required this.orders});

  /// Null while the orders stream is still loading — the header then shows the
  /// date instead of a status line.
  final List<LaundryOrder>? orders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();

    final staff = ref.watch(currentStaffProvider).valueOrNull;
    final name = staff == null ? '' : firstName(staff.displayName);
    final greeting = greetingForHour(now.hour);
    final greetingLine = name.isEmpty ? greeting : '$greeting, $name';

    final role = roleLabel(ref.watch(currentRoleProvider));
    final secondLine = headerStatusLine(orders) ?? formatHeaderDate(now);

    return AnimatedGradientHeader(
      padding: const EdgeInsets.all(AppSpacing.lg2),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.white,
            // The brand mark is an orange rounded square; a white disc behind it
            // gives contrast against the orange header. Sized to sit fully
            // inside the circle (its corners stay within the 28px radius).
            child: Image.asset(
              'assets/branding/app_icon.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        greetingLine,
                        style: textTheme.headlineMedium?.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    if (role != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      _RoleChip(label: role),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  secondLine,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.9),
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

/// Small translucent pill showing the staff member's role beside the greeting.
class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The five tappable summary cards. Each card's count and the list it opens
/// both derive from the same [OrderFilter] (via [OrderFilter.apply]), so the
/// number on a card can never disagree with the orders behind it.
class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.orders, required this.onCardTap});

  final List<LaundryOrder> orders;
  final void Function(OrderFilter) onCardTap;

  int _count(OrderFilter filter) => filter.count(orders);

  Widget _card(OrderFilter filter, IconData icon, {bool wide = false}) {
    return _SummaryCard(
      title: filter.label,
      value: _count(filter),
      icon: icon,
      wide: wide,
      onTap: () => onCardTap(filter),
    );
  }

  // A pair of equal-width cards that also share a height: IntrinsicHeight +
  // stretch makes the shorter card grow to its row-mate, so a one-line label
  // ("Assigned") doesn't leave its card stubbier than a card whose label wraps
  // ("Pending pickup") on a narrow phone.
  Widget _row(Widget left, Widget right) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: right),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row(
          _card(OrderFilter.all, Icons.assignment_outlined),
          _card(OrderFilter.pendingPickup, Icons.local_shipping_outlined),
        ),
        const SizedBox(height: AppSpacing.md),
        _row(
          _card(OrderFilter.inProgress, Icons.timelapse_rounded),
          _card(OrderFilter.readyForDelivery, Icons.checkroom_outlined),
        ),
        const SizedBox(height: AppSpacing.md),
        _card(
          OrderFilter.completedToday,
          Icons.check_circle_outline_rounded,
          wide: true,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
    this.wide = false,
  });

  final String title;
  final int value;
  final IconData icon;
  final VoidCallback? onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      child: SizedBox(
        width: wide ? double.infinity : null,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: colorScheme.primary),
            ),
            // 1px past `md`: an optical nudge so the label sits balanced
            // against the 44px icon tile rather than crowding it.
            const SizedBox(width: AppSpacing.md + 1),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CountUpText(
                    value: value,
                    style: textTheme.headlineMedium,
                  ),
                  Text(
                    title,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Home "Business at a glance": today's collected revenue + customers added
/// today, plus the order-count summary grid behind a collapsed-by-default
/// View all/Less toggle. A [ConsumerStatefulWidget] so it self-watches the
/// orders + customers streams (Riverpod dedups the orders watch the shell
/// already holds) while also holding the toggle's local expanded state.
class _BusinessAtAGlance extends ConsumerStatefulWidget {
  const _BusinessAtAGlance({required this.onOpenFiltered});

  /// Opens a filtered order list for a tapped summary card. Forwarded
  /// straight through to [_SummaryGrid] once the grid is expanded.
  final void Function(OrderFilter) onOpenFiltered;

  @override
  ConsumerState<_BusinessAtAGlance> createState() => _BusinessAtAGlanceState();
}

class _BusinessAtAGlanceState extends ConsumerState<_BusinessAtAGlance> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final orders =
        ref.watch(ordersStreamProvider).valueOrNull ?? const <LaundryOrder>[];
    final customers =
        ref.watch(customersStreamProvider).valueOrNull ?? const <Customer>[];
    final glance =
        BusinessGlance.forToday(orders, customers, now: DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Business at a glance',
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            InkWell(
              key: const Key('glance_toggle'),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      _expanded ? 'Less' : 'View all',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _GlanceTile(
                  key: const Key('glance_revenue'),
                  icon: Icons.payments_outlined,
                  value: formatUgx(glance.revenueUgx),
                  title: "Today's revenue",
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _GlanceTile(
                  key: const Key('glance_new_customers'),
                  icon: Icons.person_add_alt_1_outlined,
                  value: '${glance.newCustomers}',
                  title: 'New customers',
                ),
              ),
            ],
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: AppSpacing.xl),
          _SummaryGrid(orders: orders, onCardTap: widget.onOpenFiltered),
        ],
      ],
    );
  }
}

class _GlanceTile extends StatelessWidget {
  const _GlanceTile({
    super.key,
    required this.icon,
    required this.value,
    required this.title,
  });

  final IconData icon;
  final String value;
  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: colorScheme.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: textTheme.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(title, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onNewPickup,
    required this.onAddCustomer,
    required this.onShowReport,
    required this.onCheckOrder,
  });

  final VoidCallback onNewPickup;

  /// Null drops the Add-customer tile (RLS-gated to in_shop/manager) and
  /// reflows the grid.
  final VoidCallback? onAddCustomer;
  final VoidCallback onShowReport;
  final VoidCallback onCheckOrder;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: AppSpacing.sm + 2);
    // Promote to a local so the null check sticks: a public field cannot be
    // type-promoted, and _ActionButton.onTap is non-nullable.
    final addCustomer = onAddCustomer;
    final actions = <Widget>[
      _ActionButton(
        label: 'New pickup',
        icon: Icons.add_location_alt_outlined,
        onTap: onNewPickup,
      ),
      if (addCustomer != null)
        _ActionButton(
          label: 'Add customer',
          icon: Icons.person_add_alt_1_outlined,
          onTap: addCustomer,
        ),
      _ActionButton(
        label: 'Check order',
        icon: Icons.search_rounded,
        onTap: onCheckOrder,
      ),
      _ActionButton(
        label: 'Report',
        icon: Icons.bar_chart_rounded,
        onTap: onShowReport,
      ),
    ];

    // Two tiles per row, built from whatever survived the role gate, so a
    // withheld action reflows the grid instead of leaving a hole in it.
    final rows = <Widget>[];
    for (var i = 0; i < actions.length; i += 2) {
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: AppSpacing.sm + 2));
      }
      final trailing = i + 1 < actions.length ? actions[i + 1] : null;
      rows.add(Row(
        children: [
          Expanded(child: actions[i]),
          gap,
          // An odd count leaves the last slot empty rather than letting the
          // final tile stretch to full width.
          Expanded(child: trailing ?? const SizedBox.shrink()),
        ],
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick actions',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        ...rows,
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.sm,
      ),
      child: Column(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

