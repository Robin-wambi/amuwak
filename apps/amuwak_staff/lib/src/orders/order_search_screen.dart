import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:amuwak_core/amuwak_core.dart';
import '../sync/repository_providers.dart';
import 'order.dart';
import 'order_list_extensions.dart';
import 'proof/barcode_reader.dart';
import 'widgets/barcode_search_scan_screen.dart';
import 'widgets/order_card_list.dart';

/// Lets a rider find one known order fast: live text filtering over the
/// orders stream (by code, customer name, phone, or address), with a
/// browsable "active orders" zero-state when the field is empty.
///
/// [onOrderTap] is the dashboard's order-details opener (it carries the
/// session check + repository wiring), so this screen never re-implements
/// navigation into [OrderDetailsScreen]. [cameraViewBuilder] backs the
/// barcode scan-to-search action.
class OrderSearchScreen extends ConsumerStatefulWidget {
  const OrderSearchScreen({
    super.key,
    required this.onOrderTap,
    required this.cameraViewBuilder,
    this.onEditOrder,
    this.onDeleteOrder,
    this.onAdvanceOrderStatus,
  });

  final void Function(LaundryOrder order) onOrderTap;
  final CameraViewBuilder cameraViewBuilder;

  /// Optional per-card CRUD actions, wired by the dashboard. Null = tap-only.
  final void Function(LaundryOrder order)? onEditOrder;
  final void Function(LaundryOrder order)? onDeleteOrder;
  final void Function(LaundryOrder order)? onAdvanceOrderStatus;

  @override
  ConsumerState<OrderSearchScreen> createState() => _OrderSearchScreenState();
}

class _OrderSearchScreenState extends ConsumerState<OrderSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// Debounced filter query. Lags the raw field text by [_debounceDuration] so
  /// the list isn't refiltered on every keystroke (the clear button keys off
  /// the controller text directly, so it stays immediate).
  String _query = '';
  Timer? _debounce;
  static const _debounceDuration = Duration(milliseconds: 300);

  // Memoized last filter result, so per-keystroke rebuilds (which run with an
  // unchanged [_query] until the debounce fires) don't re-scan the whole list.
  String? _cachedQuery;
  List<LaundryOrder>? _cachedFor;
  List<LaundryOrder>? _cachedMatches;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      if (mounted) setState(() => _query = value.trim());
    });
    // Rebuild now so the clear (X) button reflects the field text immediately,
    // without waiting for the debounce window.
    setState(() {});
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _query = '');
    _focusNode.requestFocus();
  }

  Future<void> _openScanner() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => BarcodeSearchScanScreen(
          cameraViewBuilder: widget.cameraViewBuilder,
        ),
      ),
    );
    if (code == null || !mounted) return;
    _debounce?.cancel();
    _controller.text = code;
    setState(() => _query = code.trim());
  }

  List<LaundryOrder> _matchesFor(List<LaundryOrder> orders, String query) {
    if (query == _cachedQuery && identical(orders, _cachedFor)) {
      return _cachedMatches!;
    }
    final matches = orders.searchBy(query);
    _cachedQuery = query;
    _cachedFor = orders;
    _cachedMatches = matches;
    return matches;
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersStreamProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onQueryChanged,
          decoration: InputDecoration(
            hintText: 'Search by code, name, phone…',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Clear',
                    onPressed: _clear,
                  ),
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan order tag',
            onPressed: _openScanner,
          ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyState(
          icon: Icons.error_outline_rounded,
          headline: "Couldn't load orders",
          subtitle: 'Please try again.',
        ),
        data: _buildBody,
      ),
    );
  }

  Widget _buildBody(List<LaundryOrder> orders) {
    final query = _query.trim();

    if (query.isEmpty) {
      final active = orders
          .where((o) => o.status != OrderStatus.completed)
          .toList(growable: false);
      if (active.isEmpty) {
        return const EmptyState(
          icon: Icons.inbox_outlined,
          headline: 'No active orders',
          subtitle: 'Search to find any order by code, name, phone, or address.',
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xs),
            child: Text('Active orders',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: OrderCardList(
              orders: active,
              onOrderTap: widget.onOrderTap,
              onEditOrder: widget.onEditOrder,
              onDeleteOrder: widget.onDeleteOrder,
              onAdvanceOrderStatus: widget.onAdvanceOrderStatus,
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            ),
          ),
        ],
      );
    }

    final matches = _matchesFor(orders, query);
    if (matches.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        headline: 'No orders found',
        subtitle: 'Nothing matches "$query".',
      );
    }
    return OrderCardList(
      orders: matches,
      onOrderTap: widget.onOrderTap,
      onEditOrder: widget.onEditOrder,
      onDeleteOrder: widget.onDeleteOrder,
      onAdvanceOrderStatus: widget.onAdvanceOrderStatus,
    );
  }
}
