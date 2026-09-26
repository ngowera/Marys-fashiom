import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marysfashion/main.dart';

void main() {
  setUp(() {
    Api.token = '';
    ShopMemory.readOverride = () async => null;
    ShopMemory.writeOverride = (_) async {};
    Api.client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'products': [
            {
              'id': 'D01',
              'name': 'Terracotta dress',
              'category': 'Dresses',
              'price': 28500,
              'description': 'A lovely dress',
              'image': 'dress.jpg',
              'variants': {'M / Terracotta': 2},
              'active': 1,
            },
          ],
        }),
        200,
      ),
    );
  });
  testWidgets('Women is default and Men shows its four categories', (t) async {
    await t.pumpWidget(const MarysFashionApp());
    await t.pumpAndSettle();

    final woman = t.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Women'),
    );
    expect(woman.selected, isTrue);
    expect(find.widgetWithText(ChoiceChip, 'Outfit'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Topwear'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Bottomwear'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Footwear'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Dresses'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Shoes'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Bags'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Accessories'), findsOneWidget);

    await t.tap(find.widgetWithText(ChoiceChip, 'Men'));
    await t.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, 'Suit'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Topwear'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Bottomwear'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Shoes'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Dresses'), findsNothing);
  });

  testWidgets('Website refreshes published products without reopening', (
    t,
  ) async {
    var loads = 0;
    Api.client = MockClient((request) async {
      loads++;
      return http.Response(
        jsonEncode({
          'products': [
            {
              'id': 'NEW',
              'name': loads == 1 ? 'Original dress' : 'Newly published dress',
              'category': 'Dresses',
              'price': 20000,
              'description': 'Cotton',
              'image': 'dress.jpg',
              'variants': {'M / Red': loads},
              'active': 1,
            },
          ],
        }),
        200,
      );
    });
    await t.pumpWidget(const MarysFashionApp());
    await t.pumpAndSettle();
    expect(find.text('Original dress'), findsOneWidget);
    await t.pump(const Duration(seconds: 15));
    await t.pumpAndSettle();
    expect(find.text('Newly published dress'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    final before = loads;
    await t.pump(const Duration(seconds: 30));
    expect(loads, before);
  });

  testWidgets('Inventory sign-in loads fresh staff stock', (t) async {
    var staffLoads = 0;
    Api.client = MockClient((request) async {
      if (request.url.path.endsWith('/login')) {
        return http.Response('{"token":"staff-session"}', 200);
      }
      if (request.url.path.endsWith('/admin')) {
        staffLoads++;
        expect(request.headers['Authorization'], 'Bearer staff-session');
      }
      return http.Response('{"products":[]}', 200);
    });
    await t.pumpWidget(const MarysFashionApp(inventory: true));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'staff@example.com');
    await t.enterText(find.byType(TextField).last, 'test-password');
    await t.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
    await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await t.pumpAndSettle();
    expect(staffLoads, 1);
    expect(find.text('Add product'), findsOneWidget);
    await t.pump(const Duration(seconds: 15));
    await t.pumpAndSettle();
    expect(staffLoads, 2);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Reports switch between real month, six-month and yearly data', (
    t,
  ) async {
    Map<String, dynamic> period(String start, List<int> sales) => {
      'start': start,
      'end': '2026-09-30',
      'net_item_sales': sales.fold<int>(0, (a, b) => a + b),
      'gross_margin': 12000,
      'completed_orders': 3,
      'units_sold': 5,
      'average_order_value': 10000,
      'returns_value': 0,
      'margin_rate': 40,
      'comparison_percent': 12.5,
      'estimated_cost_lines': 0,
      'top_products': [
        {'id': 'D01', 'name': 'Best dress', 'units': 3, 'sales': 20000},
      ],
      'buckets': [
        for (var i = 0; i < sales.length; i++)
          {
            'label': '${i + 1}',
            'sales': sales[i],
            'margin': sales[i] ~/ 2,
            'orders': 1,
          },
      ],
    };
    final data = <String, dynamic>{
      'reports': {
        'month': period('2026-09-01', [10000, 20000]),
        'six_months': period('2026-04-01', [5000, 15000, 20000]),
        'year': period('2025-10-01', [10000, 20000, 30000]),
      },
      'business_health': {
        'stock_cost_value': 40000,
        'stock_retail_value': 75000,
        'low_stock_variants': 1,
        'order_statuses': {'Placed': 2, 'Completed': 3},
      },
      'low_stock': [
        {'name': 'Dress', 'product': 'D01', 'variant': 'M / Red', 'qty': 1},
      ],
    };
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ReportsPanel(data: data)),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Sales progress'), findsOneWidget);
    expect(find.byType(SalesTrendChart), findsOneWidget);
    expect(find.text('Best dress'), findsOneWidget);
    expect(find.text('12.5% up vs previous period'), findsOneWidget);
    await t.tap(find.text('6 months'));
    await t.pumpAndSettle();
    expect(find.textContaining('2026-04-01'), findsOneWidget);
    await t.tap(find.text('1 year'));
    await t.pumpAndSettle();
    expect(find.textContaining('2025-10-01'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Reports do not invent a graph when there are no sales', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReportsPanel(
              data: {
                'reports': {
                  'month': {
                    'start': '2026-09-01',
                    'end': '2026-09-30',
                    'net_item_sales': 0,
                    'gross_margin': 0,
                    'completed_orders': 0,
                    'units_sold': 0,
                    'average_order_value': 0,
                    'returns_value': 0,
                    'margin_rate': 0,
                    'comparison_percent': null,
                    'buckets': [
                      {'label': '1', 'sales': 0, 'margin': 0, 'orders': 0},
                    ],
                  },
                },
                'business_health': {},
                'low_stock': [],
              },
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('No completed sales'), findsOneWidget);
    expect(find.byType(SalesTrendChart), findsNothing);
  });

  for (final width in [320.0, 390.0, 1280.0]) {
    testWidgets('Browse, select size and add to bag at width $width', (
      t,
    ) async {
      t.view.physicalSize = Size(width, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(const MarysFashionApp());
      await t.pumpAndSettle();

      expect(
        t.getCenter(find.byTooltip('Shopping cart')).dx,
        lessThan(t.getCenter(find.byTooltip('Favourites')).dx),
      );
      await t.ensureVisible(find.byTooltip('Save Terracotta dress'));
      await t.tap(find.byTooltip('Save Terracotta dress'));
      await t.pumpAndSettle();
      final heart = t.widget<Icon>(
        find.descendant(
          of: find.byTooltip('Save Terracotta dress'),
          matching: find.byType(Icon),
        ),
      );
      expect(heart.icon, Icons.favorite);
      expect(heart.color, Colors.red);
      expect(find.byTooltip('Add Terracotta dress to cart'), findsOneWidget);
      await t.ensureVisible(find.text('Terracotta dress'));
      await t.tap(find.text('Terracotta dress'));
      await t.pumpAndSettle();
      expect(find.text('Customer reviews'), findsOneWidget);
      expect(find.text('Sign in and review'), findsOneWidget);
      expect(find.textContaining('24 verified reviews'), findsNothing);
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Choose an option'),
            )
            .onPressed,
        isNull,
      );
      await t.ensureVisible(find.text('M / Terracotta  (2)'));
      await t.tap(find.text('M / Terracotta  (2)'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Add to cart'));
      await t.tap(find.text('Add to cart'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Shopping cart'));
      await t.pumpAndSettle();
      expect(find.text('Subtotal  MWK 28,500'), findsOneWidget);
    });
  }
  testWidgets('Inventory requires staff sign in', (t) async {
    await t.pumpWidget(const MarysFashionApp(inventory: true));
    await t.pumpAndSettle();
    expect(find.text('Staff password'), findsOneWidget);
    expect(find.text('Add product'), findsNothing);
  });
  testWidgets('Checkout reviews express total before submission', (t) async {
    Map<String, dynamic>? submitted;
    var completed = false;
    Api.client = MockClient((r) async {
      submitted = jsonDecode(r.body);
      return http.Response(jsonEncode({'id': 'TEST', 'total': 21000}), 201);
    });
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog(
                context: c,
                builder: (_) => CheckoutFlow(
                  lines: [
                    {
                      'id': 'SALE',
                      'name': 'Sale dress',
                      'variant': 'M / Red',
                      'qty': 1,
                      'price': 15000,
                    },
                  ],
                  checkoutKey: 'test-checkout-reference',
                  onComplete: (_) => completed = true,
                ),
              ),
              child: const Text('Start'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Start'));
    await t.pumpAndSettle();
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    expect(find.text('Required'), findsNWidgets(3));
    await t.enterText(find.byType(TextFormField).at(0), 'Mary Test');
    await t.enterText(find.byType(TextFormField).at(1), '0991234567');
    await t.enterText(find.byType(TextFormField).at(2), 'Blantyre');
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    expect(find.text('PayChangu'), findsOneWidget);
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    await t.tap(find.text('Express'));
    await t.pumpAndSettle();
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    expect(find.text('Total: MWK 21,000'), findsOneWidget);
    await t.tap(find.text('Place order'));
    await t.pumpAndSettle();
    expect(completed, isTrue);
    expect(submitted?['expected_total'], 21000);
    expect(submitted?['delivery'], 'Express');
  });
  testWidgets('Product editor and comparison fit a phone', (t) async {
    t.view.physicalSize = const Size(390, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final p = <String, dynamic>{
      'id': 'D01',
      'name': 'Dress',
      'category': 'Dresses',
      'price': 15000,
      'regular_price': 20000,
      'sale_price': 15000,
      'cost': 8000,
      'description': 'Cotton dress',
      'image': 'dress.jpg',
      'images': ['dress.jpg'],
      'variants': {'M / Red': 2},
      'active': 1,
    };
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProductEditor(product: p)),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Upload photos'), findsOneWidget);
    await t.ensureVisible(find.text('Sale price (MWK)'));
    await t.pumpAndSettle();
    expect(
      t.widget<Text>(find.text('MWK 20,000')).style?.decoration,
      TextDecoration.lineThrough,
    );
    await t.ensureVisible(find.text('Colour'));
    await t.pumpAndSettle();
    expect(find.text('Red'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComparisonView(products: [p, p], onChoose: (_) {}),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Choose this piece'), findsNWidgets(2));
    expect(t.takeException(), isNull);
  });
  testWidgets('Saved favourites survive reopening the shop', (t) async {
    String? memory;
    ShopMemory.readOverride = () async => memory;
    ShopMemory.writeOverride = (v) async {
      memory = v;
    };
    await t.pumpWidget(const MarysFashionApp());
    await t.pumpAndSettle();
    await t.ensureVisible(find.byTooltip('Save Terracotta dress'));
    await t.tap(find.byTooltip('Save Terracotta dress'));
    await t.pumpAndSettle();
    expect(jsonDecode(memory!)['saved'], ['D01']);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    await t.pumpWidget(const MarysFashionApp());
    await t.pumpAndSettle();
    await t.ensureVisible(find.byTooltip('Save Terracotta dress'));
    final heart = t.widget<Icon>(
      find.descendant(
        of: find.byTooltip('Save Terracotta dress'),
        matching: find.byType(Icon),
      ),
    );
    expect(heart.color, Colors.red);
  });
  testWidgets('Supplier form validates and sends its record', (t) async {
    t.view.physicalSize = const Size(390, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    Map<String, dynamic>? sent;
    Api.client = MockClient((r) async {
      sent = jsonDecode(r.body);
      return http.Response('{"ok":true}', 200);
    });
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog(
                context: c,
                builder: (_) => const StaffOperationDialog(
                  kind: 'Supplier',
                  products: [],
                  suppliers: [],
                  orders: [],
                ),
              ),
              child: const Text('Start'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Start'));
    await t.pumpAndSettle();
    await t.tap(find.text('Save record'));
    await t.pumpAndSettle();
    expect(find.text('Required'), findsNWidgets(2));
    await t.enterText(find.byType(TextFormField).at(0), 'Mary supplier');
    await t.enterText(find.byType(TextFormField).at(1), '0991234567');
    await t.tap(find.text('Save record'));
    await t.pumpAndSettle();
    expect(sent?['name'], 'Mary supplier');
    expect(sent?['contact'], '0991234567');
    expect(t.takeException(), isNull);
  });
  testWidgets('Book journey: category and search to itemised confirmation', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final product = {
      'id': 'D01',
      'name': 'Terracotta dress',
      'category': 'Dresses',
      'price': 28500,
      'description': 'Cotton maxi',
      'image': 'dress.jpg',
      'variants': {'M / Terracotta': 2},
      'active': 1,
    };
    Map<String, dynamic>? submitted;
    Api.client = MockClient((r) async {
      if (r.url.path.endsWith('/orders')) {
        submitted = jsonDecode(r.body);
        return http.Response(
          jsonEncode({
            'id': 'TEST-ORDER',
            'token': 'private-test-code',
            'total': 34500,
            'items': submitted!['items'],
            'status': 'Placed',
          }),
          201,
        );
      }
      return http.Response(
        jsonEncode({
          'products': [product],
        }),
        200,
      );
    });
    await t.pumpWidget(const MarysFashionApp());
    await t.pumpAndSettle();
    final category = find.widgetWithText(ChoiceChip, 'Dresses');
    await t.ensureVisible(category);
    await t.tap(category);
    await t.pumpAndSettle();
    final search = find.byType(TextField).first;
    await t.ensureVisible(search);
    await t.enterText(search, 'Terracotta');
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Terracotta dress'));
    await t.tap(find.text('Terracotta dress'));
    await t.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(EnhancedProductDetails),
        matching: find.text('Compare'),
      ),
      findsOneWidget,
    );
    await t.ensureVisible(find.text('M / Terracotta  (2)'));
    await t.ensureVisible(find.text('M / Terracotta  (2)'));
    await t.tap(find.text('M / Terracotta  (2)'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Add to cart'));
    await t.tap(find.text('Add to cart'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Shopping cart'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Continue to checkout'));
    await t.tap(find.text('Continue to checkout'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(0), 'Mary Test');
    await t.enterText(find.byType(TextFormField).at(1), '0991234567');
    await t.enterText(find.byType(TextFormField).at(2), 'Blantyre');
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    expect(find.text('PayChangu'), findsOneWidget);
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Express'));
    await t.tap(find.text('Express'));
    await t.pumpAndSettle();
    expect(
      find.textContaining('difference from standard delivery is MWK 3,000'),
      findsOneWidget,
    );
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    expect(find.text('Total: MWK 34,500'), findsOneWidget);
    await t.tap(find.text('Place order'));
    await t.pumpAndSettle();
    expect(find.text('Your order is confirmed'), findsOneWidget);
    expect(
      find.textContaining('No online payment has been taken'),
      findsOneWidget,
    );
    expect(find.text('private-test-code'), findsOneWidget);
    expect(find.textContaining('M / Terracotta · MWK 28,500'), findsOneWidget);
    expect(submitted?['delivery'], 'Express');
    expect(t.takeException(), isNull);
  });
  test('Full report includes items, fee and payment status', () {
    final report = orderReport({
      'id': 'TEST',
      'token': 'PRIVATE',
      'total': 15000,
      'delivery': 'Pickup',
      'delivery_fee': 0,
      'items': [
        {'name': 'Dress', 'variant': 'M / Red', 'qty': 1, 'price': 15000},
      ],
    });
    expect(report, contains('M / Red'));
    expect(report, contains('Due on collection / delivery'));
    expect(report, contains('Total: MWK 15,000'));
  });
  for (final changed in ['price', 'stock']) {
    testWidgets('Cart refresh blocks changed $changed before checkout', (
      t,
    ) async {
      var loads = 0;
      final item = {
        'id': 'D01',
        'name': 'Terracotta dress',
        'category': 'Dresses',
        'price': 28500,
        'image': 'dress.jpg',
        'variant': 'M / Terracotta',
        'qty': 1,
      };
      ShopMemory.readOverride = () async => jsonEncode({
        'items': [item],
        'saved': [],
        'checkout_key': '',
      });
      Api.client = MockClient((r) async {
        loads++;
        return http.Response(
          jsonEncode({
            'products': [
              {
                ...item,
                'description': 'Cotton',
                'price': loads > 1 && changed == 'price' ? 30000 : 28500,
                'variants': {
                  'M / Terracotta': loads > 1 && changed == 'stock' ? 0 : 2,
                },
                'active': 1,
              },
            ],
          }),
          200,
        );
      });
      await t.pumpWidget(const MarysFashionApp());
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Shopping cart'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Continue to checkout'));
      await t.tap(find.text('Continue to checkout'));
      await t.pumpAndSettle();
      expect(find.byType(CheckoutFlow), findsNothing);
      expect(
        find.textContaining(
          changed == 'price'
              ? 'A price changed'
              : 'this size or quantity is unavailable',
        ),
        findsOneWidget,
      );
    });
  }
}
