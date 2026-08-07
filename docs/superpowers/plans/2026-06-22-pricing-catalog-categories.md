# Pricing Catalog Categories Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let staff tag each managed service item with a free-form category and filter the billing item picker by category.

**Architecture:** Add an optional `category` string to the existing `CatalogItem` model (and its `pricing_catalog_items` table, Supabase + Drift). The catalog manager sheet gains a category field with suggestions drawn from existing categories. The billing picker (`showPickLineItemSheet`) gains category filter chips at the top. The chosen category is **catalog-only** — `LineItem`, order serialization, and Supabase order payloads are untouched.

**Tech Stack:** Flutter + Riverpod, Drift (local schema), Supabase Postgres (live reads/writes for catalog).

## Global Constraints

- **Catalog-only scope:** Do NOT modify `LineItem` (`lib/src/orders/pricing/line_item.dart`), order serialization, or Supabase order payloads. Category lives only on `CatalogItem`.
- **Category is free-form and optional:** trimmed; empty/whitespace normalizes to `null`. No fixed list, no separate table.
- **Tests run one file at a time** on this Windows host: `flutter test <single_path>` (never pass multiple paths — it hangs at loading).
- **UGX/amount/active/sortOrder behavior is unchanged** — only `category` is added.
- Existing widget keys must be preserved so current tests keep passing.

---

## Context

The pricing catalog (`pricing_catalog_items`) is a flat list of priced service items (blanket, duvet, jacket…) staff pick from at billing. Today the picker shows every active item in one undifferentiated `ListTile` list ([pricing_section.dart:112-151](../../lib/src/orders/pricing/pricing_section.dart#L112)). As the catalog grows this gets long and hard to scan. Per POS/catalog UX best practice (single-level categories aligned to staff mental models, surfaced above the list), we let staff tag items with a category and filter the picker by it. Free-form text keeps the management surface minimal; chips keep billing fast.

## File Structure

- `lib/src/pricing/catalog_item.dart` — add `category` field + serialization (Task 1)
- `lib/src/pricing/pricing_catalog_screen.dart` — category input w/ suggestions + list display (Task 2)
- `lib/src/orders/pricing/pricing_section.dart` — category filter chips in the picker (Task 3)
- `supabase/migrations/0026_pricing_catalog_item_category.sql` — new DB column (Task 4)
- `lib/src/data/tables/pricing_catalog_items_table.dart` + `lib/src/data/app_database.dart` + regenerated `app_database.g.dart` — Drift parity (Task 4)

---

### Task 1: Add `category` to the CatalogItem model

**Files:**
- Modify: `lib/src/pricing/catalog_item.dart`
- Test: `test/pricing/pricing_catalog_test.dart`

**Interfaces:**
- Produces: `CatalogItem({..., String? category})` with `final String? category;`, normalized (trimmed, empty→null); `category` read in `fromSupabase` (`r['category'] as String?`), written in `toSupabase` (`'category': category`); `copyWith({Object? category})` that supports clearing to null; `category` included in `==`/`hashCode`/`toString`.

- [ ] **Step 1: Write the failing tests** — append to `test/pricing/pricing_catalog_test.dart` inside the `group('CatalogItem', ...)`:

```dart
    test('reads and writes category', () {
      final c = CatalogItem(
          id: 'c1', name: 'Suit', amountUgx: 12000, category: 'Dry Cleaning');
      expect(c.category, 'Dry Cleaning');
      expect(c.toSupabase()['category'], 'Dry Cleaning');
      expect(CatalogItem.fromSupabase(c.toSupabase()), c);
    });

    test('category degrades to null when absent', () {
      final c = CatalogItem.fromSupabase({
        'id': 'c1',
        'name': 'Duvet',
        'amount_ugx': 10000,
      });
      expect(c.category, isNull);
    });

    test('blank category normalizes to null and trims', () {
      expect(CatalogItem(id: 'c1', name: 'X', amountUgx: 1, category: '   ')
          .category, isNull);
      expect(CatalogItem(id: 'c1', name: 'X', amountUgx: 1, category: ' Wash ')
          .category, 'Wash');
    });

    test('copyWith can set and clear category', () {
      final base = CatalogItem(id: 'c1', name: 'X', amountUgx: 1);
      expect(base.copyWith(category: 'Ironing').category, 'Ironing');
      final tagged = CatalogItem(
          id: 'c1', name: 'X', amountUgx: 1, category: 'Ironing');
      expect(tagged.copyWith(category: null).category, isNull);
      expect(tagged.copyWith(name: 'Y').category, 'Ironing'); // untouched
    });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/pricing/pricing_catalog_test.dart`
Expected: FAIL — `category` is not a named parameter / getter undefined.

- [ ] **Step 3: Implement the model change** in `lib/src/pricing/catalog_item.dart`.

Add a private sentinel above the class body and update the constructor, fields, factory, `toSupabase`, `copyWith`, `==`, `hashCode`, `toString`:

```dart
class CatalogItem {
  CatalogItem({
    required this.id,
    required String name,
    required this.amountUgx,
    this.active = true,
    this.sortOrder = 0,
    String? category,
  })  : name = name.trim(),
        category = (category != null && category.trim().isNotEmpty)
            ? category.trim()
            : null {
    if (this.name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    if (amountUgx < 0) {
      throw ArgumentError.value(amountUgx, 'amountUgx', 'must be >= 0');
    }
  }

  static const Object _unset = Object();

  final String id;
  final String name;
  final int amountUgx;
  final bool active;
  final int sortOrder;

  /// Optional free-form grouping (e.g. "Dry Cleaning"); null = uncategorised.
  final String? category;

  factory CatalogItem.fromSupabase(Map<String, dynamic> r) => CatalogItem(
        id: r['id'] as String,
        name: r['name'] as String,
        amountUgx: (r['amount_ugx'] as num).toInt(),
        active: (r['active'] as bool?) ?? true,
        sortOrder: (r['sort_order'] as num?)?.toInt() ?? 0,
        category: r['category'] as String?,
      );

  Map<String, dynamic> toSupabase() => {
        'id': id,
        'name': name,
        'amount_ugx': amountUgx,
        'active': active,
        'sort_order': sortOrder,
        'category': category,
      };

  CatalogItem copyWith({
    String? name,
    int? amountUgx,
    bool? active,
    int? sortOrder,
    Object? category = _unset,
  }) =>
      CatalogItem(
        id: id,
        name: name ?? this.name,
        amountUgx: amountUgx ?? this.amountUgx,
        active: active ?? this.active,
        sortOrder: sortOrder ?? this.sortOrder,
        category:
            identical(category, _unset) ? this.category : category as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is CatalogItem &&
      other.id == id &&
      other.name == name &&
      other.amountUgx == amountUgx &&
      other.active == active &&
      other.sortOrder == sortOrder &&
      other.category == category;

  @override
  int get hashCode =>
      Object.hash(id, name, amountUgx, active, sortOrder, category);

  @override
  String toString() =>
      'CatalogItem($id, $name, $amountUgx, active: $active, sort: $sortOrder, '
      'category: $category)';
}
```

Keep the existing doc comment block at the top of the file.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/pricing/pricing_catalog_test.dart`
Expected: PASS (all existing + 4 new tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/pricing/catalog_item.dart test/pricing/pricing_catalog_test.dart
git commit -m "feat(pricing): add optional category to CatalogItem"
```

---

### Task 2: Category input + display in the catalog manager

**Files:**
- Modify: `lib/src/pricing/pricing_catalog_screen.dart`
- Test: `test/pricing/pricing_catalog_screen_test.dart`

**Interfaces:**
- Consumes: `CatalogItem.category` from Task 1.
- Produces: a `Key('catalog_category')` text field in the add/edit sheet; tappable suggestion chips `Key('catalog_category_suggestion_<name>')` built from existing items' distinct categories; saved `CatalogItem` carries `category`; list `ListTile` subtitle shows the category (and "Retired" when inactive).

- [ ] **Step 1: Write the failing tests** — add to `test/pricing/pricing_catalog_screen_test.dart`:

```dart
  testWidgets('shows category in the list subtitle', (tester) async {
    await tester.pumpWidget(screen(
      items: [
        CatalogItem(
            id: 'c1', name: 'Suit', amountUgx: 12000, category: 'Dry Cleaning'),
      ],
      onSave: (_) {},
    ));
    await tester.pumpAndSettle();
    expect(find.text('Dry Cleaning'), findsOneWidget);
  });

  testWidgets('adds an item with a category', (tester) async {
    CatalogItem? saved;
    await tester.pumpWidget(screen(
      items: const [],
      onSave: (item) => saved = item,
      newId: 'gen-1',
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog_add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('catalog_name')), 'Suit');
    await tester.enterText(find.byKey(const Key('catalog_amount')), '12000');
    await tester.enterText(
        find.byKey(const Key('catalog_category')), 'Dry Cleaning');
    await tester.tap(find.byKey(const Key('catalog_save')));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.category, 'Dry Cleaning');
  });

  testWidgets('tapping a suggestion fills the category field', (tester) async {
    CatalogItem? saved;
    await tester.pumpWidget(screen(
      items: [
        CatalogItem(
            id: 'c1', name: 'Suit', amountUgx: 12000, category: 'Dry Cleaning'),
      ],
      onSave: (item) => saved = item,
      newId: 'gen-2',
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog_add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('catalog_name')), 'Coat');
    await tester.enterText(find.byKey(const Key('catalog_amount')), '9000');
    await tester.tap(find
        .byKey(const Key('catalog_category_suggestion_Dry Cleaning')));
    await tester.tap(find.byKey(const Key('catalog_save')));
    await tester.pumpAndSettle();
    expect(saved!.category, 'Dry Cleaning');
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/pricing/pricing_catalog_screen_test.dart`
Expected: FAIL — `catalog_category` key not found / category not saved.

- [ ] **Step 3: Implement the screen changes** in `lib/src/pricing/pricing_catalog_screen.dart`.

3a. Compute distinct existing categories and pass them to the sheet. In `_showItemSheet`:

```dart
  Future<_SheetResult?> _showItemSheet({CatalogItem? existing}) {
    final categories = _items
        .map((e) => e.category)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    return showModalBottomSheet<_SheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _CatalogItemSheet(existing: existing, categories: categories),
    );
  }
```

3b. Pass `category` through on add and edit:

```dart
  Future<void> _addItem() async {
    final result = await _showItemSheet();
    if (result == null) return;
    final nextSort =
        _items.fold<int>(0, (m, e) => math.max(m, e.sortOrder)) + 1;
    await _saveAndReload(CatalogItem(
      id: widget.idGenerator(),
      name: result.name,
      amountUgx: result.amountUgx,
      sortOrder: nextSort,
      category: result.category,
    ));
  }

  Future<void> _editItem(CatalogItem item) async {
    final result = await _showItemSheet(existing: item);
    if (result == null) return;
    await _saveAndReload(item.copyWith(
      name: result.name,
      amountUgx: result.amountUgx,
      active: result.active,
      category: result.category,
    ));
  }
```

3c. Show category in the list subtitle. Replace the `ListTile` subtitle expression in `itemBuilder`:

```dart
                          return ListTile(
                            key: Key('catalog_item_$i'),
                            title: Text(item.name),
                            subtitle: _subtitle(item),
                            trailing: Text(formatUgx(item.amountUgx)),
                            enabled: true,
                            onTap: () => _editItem(item),
                          );
```

And add this helper method to `_PricingCatalogScreenState`:

```dart
  Widget? _subtitle(CatalogItem item) {
    final parts = <String>[
      if (item.category != null) item.category!,
      if (!item.active) 'Retired',
    ];
    return parts.isEmpty ? null : Text(parts.join(' · '));
  }
```

3d. Extend `_SheetResult`:

```dart
class _SheetResult {
  const _SheetResult(this.name, this.amountUgx, this.active, this.category);
  final String name;
  final int amountUgx;
  final bool active;
  final String? category;
}
```

3e. Update `_CatalogItemSheet` to take categories, hold a category controller, render suggestion chips + the field, and return the category. Replace the widget + state:

```dart
class _CatalogItemSheet extends StatefulWidget {
  const _CatalogItemSheet({this.existing, this.categories = const []});
  final CatalogItem? existing;
  final List<String> categories;

  @override
  State<_CatalogItemSheet> createState() => _CatalogItemSheetState();
}

class _CatalogItemSheetState extends State<_CatalogItemSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _categoryController;
  late bool _active;
  String? _nameError;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _amountController = TextEditingController(
        text: widget.existing == null
            ? ''
            : widget.existing!.amountUgx.toString());
    _categoryController =
        TextEditingController(text: widget.existing?.category ?? '');
    _active = widget.existing?.active ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final amount = int.tryParse(_amountController.text.trim());
    final nextNameError = name.isEmpty ? 'Enter an item name' : null;
    final nextAmountError =
        (amount == null || amount < 0) ? 'Enter a valid amount' : null;
    if (nextNameError != null || nextAmountError != null) {
      setState(() {
        _nameError = nextNameError;
        _amountError = nextAmountError;
      });
      return;
    }
    final category = _categoryController.text.trim();
    Navigator.pop(
      context,
      _SheetResult(name, amount!, _active, category.isEmpty ? null : category),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('catalog_name'),
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Item (e.g. Blanket)',
              errorText: _nameError,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('catalog_amount'),
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Amount (UGX)',
              errorText: _amountError,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('catalog_category'),
            controller: _categoryController,
            decoration: const InputDecoration(
              labelText: 'Category (optional, e.g. Dry Cleaning)',
            ),
          ),
          if (widget.categories.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final c in widget.categories)
                  ActionChip(
                    key: Key('catalog_category_suggestion_$c'),
                    label: Text(c),
                    onPressed: () => _categoryController.text = c,
                  ),
              ],
            ),
          ],
          if (isEdit) ...[
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              key: const Key('catalog_active'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: const Text('Off retires it from the picker'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            key: const Key('catalog_save'),
            onPressed: _submit,
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/pricing/pricing_catalog_screen_test.dart`
Expected: PASS (existing + 3 new tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/pricing/pricing_catalog_screen.dart test/pricing/pricing_catalog_screen_test.dart
git commit -m "feat(pricing): tag catalog items with a category"
```

---

### Task 3: Category filter chips in the billing item picker

**Files:**
- Modify: `lib/src/orders/pricing/pricing_section.dart` (the `_PickLineItemSheet` widget, ~lines 112-151)
- Test: `test/orders/pricing/pricing_section_test.dart`

**Interfaces:**
- Consumes: `CatalogItem.category` from Task 1.
- Produces: filter chips at the top of `showPickLineItemSheet` — `Key('pick_category_all')` plus `Key('pick_category_<name>')` per distinct category and `Key('pick_category_other')` when uncategorised items exist; tapping a chip filters the listed `pick_catalog_item_$i` tiles (index over the filtered list). "All" is selected by default. The "Custom item" tile and the empty-catalog fallback are unchanged.

- [ ] **Step 1: Write the failing tests** — add to `test/orders/pricing/pricing_section_test.dart`. First add the missing import at the top of the file (it currently imports only `line_item.dart` and `pricing_section.dart`):

```dart
import 'package:amuwak_staff/src/pricing/catalog_item.dart';
```

Then add these test cases inside `main()`:

```dart
  testWidgets('filters picker items by category chip', (tester) async {
    final catalog = [
      CatalogItem(
          id: 'c1', name: 'Suit', amountUgx: 12000, category: 'Dry Cleaning'),
      CatalogItem(id: 'c2', name: 'Blanket', amountUgx: 8000, category: 'Bulky'),
      CatalogItem(id: 'c3', name: 'Plain', amountUgx: 0), // uncategorised
    ];
    LineItem? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async =>
                picked = await showPickLineItemSheet(context, catalog),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // All shown by default.
    expect(find.text('Suit'), findsOneWidget);
    expect(find.text('Blanket'), findsOneWidget);
    expect(find.text('Plain'), findsOneWidget);

    // Filter to Dry Cleaning.
    await tester.tap(find.byKey(const Key('pick_category_Dry Cleaning')));
    await tester.pumpAndSettle();
    expect(find.text('Suit'), findsOneWidget);
    expect(find.text('Blanket'), findsNothing);
    expect(find.text('Plain'), findsNothing);

    // Uncategorised via the Other chip.
    await tester.tap(find.byKey(const Key('pick_category_other')));
    await tester.pumpAndSettle();
    expect(find.text('Plain'), findsOneWidget);
    expect(find.text('Suit'), findsNothing);

    // Picking still returns a LineItem with name + amount.
    await tester.tap(find.text('Plain'));
    await tester.pumpAndSettle();
    expect(picked, isNotNull);
    expect(picked!.name, 'Plain');
    expect(picked!.amountUgx, 0);
  });

  testWidgets('no category chips when nothing is categorised', (tester) async {
    final catalog = [
      CatalogItem(id: 'c1', name: 'Plain', amountUgx: 1000),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showPickLineItemSheet(context, catalog),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pick_category_all')), findsNothing);
    expect(find.text('Plain'), findsOneWidget);
  });
```

Adapt the harness/imports to match the existing test file (it already imports `CatalogItem`, `LineItem`, and `showPickLineItemSheet`).

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/orders/pricing/pricing_section_test.dart`
Expected: FAIL — `pick_category_*` keys not found.

- [ ] **Step 3: Implement the picker change** in `lib/src/orders/pricing/pricing_section.dart`. Convert `_PickLineItemSheet` to a stateful widget that derives categories, shows a chip row only when at least one item is categorised, and filters the list:

```dart
class _PickLineItemSheet extends StatefulWidget {
  const _PickLineItemSheet({required this.catalog});

  final List<CatalogItem> catalog;

  @override
  State<_PickLineItemSheet> createState() => _PickLineItemSheetState();
}

class _PickLineItemSheetState extends State<_PickLineItemSheet> {
  // null = "All". The sentinel _other filters to uncategorised items.
  static const String _all = ' all';
  static const String _other = ' other';
  String _selected = _all;

  List<String> get _categories {
    final set = widget.catalog
        .map((e) => e.category)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    return set;
  }

  bool get _hasUncategorised =>
      widget.catalog.any((e) => e.category == null);

  List<CatalogItem> get _filtered {
    if (_selected == _all) return widget.catalog;
    if (_selected == _other) {
      return widget.catalog.where((e) => e.category == null).toList();
    }
    return widget.catalog.where((e) => e.category == _selected).toList();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categories;
    final showChips = categories.isNotEmpty;
    final filtered = _filtered;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          if (showChips)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Wrap(
                spacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    key: const Key('pick_category_all'),
                    label: const Text('All'),
                    selected: _selected == _all,
                    onSelected: (_) => setState(() => _selected = _all),
                  ),
                  for (final c in categories)
                    ChoiceChip(
                      key: Key('pick_category_$c'),
                      label: Text(c),
                      selected: _selected == c,
                      onSelected: (_) => setState(() => _selected = c),
                    ),
                  if (_hasUncategorised)
                    ChoiceChip(
                      key: const Key('pick_category_other'),
                      label: const Text('Other'),
                      selected: _selected == _other,
                      onSelected: (_) => setState(() => _selected = _other),
                    ),
                ],
              ),
            ),
          for (var i = 0; i < filtered.length; i++)
            ListTile(
              key: Key('pick_catalog_item_$i'),
              title: Text(filtered[i].name),
              trailing: Text(formatUgx(filtered[i].amountUgx)),
              onTap: () => Navigator.pop(
                context,
                LineItem(
                    name: filtered[i].name, amountUgx: filtered[i].amountUgx),
              ),
            ),
          const Divider(height: 1),
          ListTile(
            key: const Key('pick_custom_item'),
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Custom item'),
            onTap: () async {
              final item = await showAddLineItemSheet(context);
              if (item != null && context.mounted) {
                Navigator.pop(context, item);
              }
            },
          ),
        ],
      ),
    );
  }
}
```

Leave `showPickLineItemSheet` itself unchanged (it still short-circuits to `showAddLineItemSheet` when the catalog is empty and constructs `_PickLineItemSheet`).

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/orders/pricing/pricing_section_test.dart`
Expected: PASS (existing picker tests + 2 new tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/orders/pricing/pricing_section.dart test/orders/pricing/pricing_section_test.dart
git commit -m "feat(pricing): filter billing item picker by category"
```

---

### Task 4: Persist category — Supabase migration + Drift schema parity

**Files:**
- Create: `supabase/migrations/0026_pricing_catalog_item_category.sql`
- Modify: `lib/src/data/tables/pricing_catalog_items_table.dart`
- Modify: `lib/src/data/app_database.dart` (schemaVersion + migration step)
- Regenerate: `lib/src/data/app_database.g.dart` (via build_runner)
- Test: `test/app_database_test.dart` (smoke — schema opens/migrates)

**Interfaces:**
- Consumes: `CatalogItem.toSupabase()` now writes a `category` key (Task 1), so the Supabase column must exist for upserts to succeed.
- Produces: `pricing_catalog_items.category` (nullable text) in both Postgres and the Drift schema (version 5).

- [ ] **Step 1: Write the Supabase migration** `supabase/migrations/0026_pricing_catalog_item_category.sql`:

```sql
-- 0026_pricing_catalog_item_category.sql
-- Adds an optional free-form category to managed service items so staff can
-- group the billing picker (e.g. "Dry Cleaning", "Bulky"). Nullable = no
-- category; existing rows backfill to NULL and behave exactly as before.
ALTER TABLE pricing_catalog_items
  ADD COLUMN category text;
```

- [ ] **Step 2: Add the Drift column** in `lib/src/data/tables/pricing_catalog_items_table.dart` (inside `PricingCatalogItems`, after `sortOrder`):

```dart
  TextColumn     get category  => text().nullable()();
```

- [ ] **Step 3: Bump the schema version and add the migration step** in `lib/src/data/app_database.dart`.

Change `int get schemaVersion => 4;` to `5`, and add this branch at the end of the `onUpgrade` step list (after the `if (from < 4)` block):

```dart
          if (from < 5) {
            await m.addColumn(pricingCatalogItems, pricingCatalogItems.category);
          }
```

- [ ] **Step 4: Regenerate the Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: regenerates `lib/src/data/app_database.g.dart` with the new `category` column; exit 0.

- [ ] **Step 5: Run the database test to verify schema parity**

Run: `flutter test test/app_database_test.dart`
Expected: PASS (schema opens, migrations apply cleanly).

- [ ] **Step 6: Apply the Supabase migration**

Run (network — disable sandbox if it hangs): `supabase db push`
Expected: `0026_pricing_catalog_item_category.sql` applied. If `supabase` CLI is unavailable, run the `ALTER TABLE` from Step 1 in the Supabase SQL editor. This is required before category saves work against live data.

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/0026_pricing_catalog_item_category.sql lib/src/data/tables/pricing_catalog_items_table.dart lib/src/data/app_database.dart lib/src/data/app_database.g.dart
git commit -m "feat(pricing): persist catalog item category (supabase + drift v5)"
```

---

## Verification (end-to-end)

1. **Repository round-trip:** `flutter test test/pricing/pricing_catalog_repository_test.dart` — confirms `toSupabase`/`fromSupabase` (now incl. category) still round-trip through the repo fakes.
2. **Full pricing suite, one file at a time:**
   - `flutter test test/pricing/pricing_catalog_test.dart`
   - `flutter test test/pricing/pricing_catalog_screen_test.dart`
   - `flutter test test/orders/pricing/pricing_section_test.dart`
   - `flutter test test/app_database_test.dart`
3. **Manual smoke (run the app):** Account → Pricing settings → Manage service items → add "Suit" with category "Dry Cleaning"; confirm the subtitle shows the category and the suggestion chip appears when adding a second item. Then start a pickup → Add item → confirm category chips appear, filtering works, "All"/"Other" behave, and picking an item still adds the correct line item.
4. **Static checks:** `flutter analyze lib/src/pricing lib/src/orders/pricing lib/src/data` — expect no new warnings.

## Notes / Risks

- The Supabase column (Task 4 Step 6) must be live before the catalog screen can save categories; until then `toSupabase()` sending `category` would be rejected by Postgres. Sequence Task 4's DB push before relying on the feature in production.
- `copyWith`'s `Object? category = _unset` sentinel preserves existing callers (none pass category) while allowing explicit `null` to clear — don't replace it with `String? category` or clearing breaks.
- Scope guard: re-confirm no edits leaked into `lib/src/orders/pricing/line_item.dart`, order serialization, or `supabase_payloads` — category is catalog-only.
