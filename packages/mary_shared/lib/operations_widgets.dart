part of 'mary_shared.dart';

class ShopMemory {
  static Future<String?> Function()? readOverride;
  static Future<void> Function(String)? writeOverride;
  static Future<String?> read() =>
      readOverride?.call() ??
      SharedPreferencesAsync().getString('marysfashion.cart');
  static Future<void> write(String value) =>
      writeOverride?.call(value) ??
      SharedPreferencesAsync().setString('marysfashion.cart', value);
}

class OperationsPanel extends StatelessWidget {
  final Map<String, dynamic> data;
  final List<dynamic> products, orders;
  final Future<void> Function() reload;
  const OperationsPanel({
    super.key,
    required this.data,
    required this.products,
    required this.orders,
    required this.reload,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Receive deliveries, record stock losses and manage returns.',
        style: TextStyle(fontSize: 18),
      ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final kind in [
            'Supplier',
            'Receive',
            'Damaged',
            'Return',
            'Collection',
          ])
            OutlinedButton(
              onPressed: () async {
                final changed = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => StaffOperationDialog(
                    kind: kind,
                    products: products,
                    suppliers: data['suppliers'] ?? [],
                    orders: orders,
                  ),
                );
                if (changed == true) await reload();
              },
              child: Text(
                {
                  'Supplier': 'Add supplier',
                  'Receive': 'Receive stock',
                  'Damaged': 'Record damaged stock',
                  'Return': 'Record customer return',
                  'Collection': 'Record payment collected',
                }[kind]!,
              ),
            ),
        ],
      ),
      const SizedBox(height: 26),
      const Text('Suppliers', style: TextStyle(fontSize: 24)),
      if ((data['suppliers'] ?? []).isEmpty)
        const Text('Add your supplier before receiving a delivery.'),
      for (final s in data['suppliers'] ?? [])
        Card(
          child: ListTile(
            title: Text(s['name']),
            subtitle: Text('${s['contact']}\n${s['notes']}'),
          ),
        ),
      const SizedBox(height: 24),
      const Text('Customer returns', style: TextStyle(fontSize: 24)),
      const Text(
        'Recording a return does not transfer a refund. Agree eligibility with the customer and handle refunds separately.',
      ),
      for (final r in data['returns'] ?? [])
        Card(
          child: ListTile(
            title: Text('${r['order_id']} · ${r['qty']} × ${r['product']}'),
            subtitle: Text(
              '${r['variant']} · ${r['reason']}\n${r['restock'] == 1 ? 'Returned to stock' : 'Not returned to saleable stock'}\nRefund: ${r['refund_status']} · ${money(r['amount'])}',
            ),
          ),
        ),
    ],
  );
}

class StaffOperationDialog extends StatefulWidget {
  final String kind;
  final List<dynamic> products, suppliers, orders;
  const StaffOperationDialog({
    super.key,
    required this.kind,
    required this.products,
    required this.suppliers,
    required this.orders,
  });
  @override
  State<StaffOperationDialog> createState() => _StaffOperationDialogState();
}

class _StaffOperationDialogState extends State<StaffOperationDialog> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      contact = TextEditingController(),
      notes = TextEditingController(),
      quantity = TextEditingController(text: '1'),
      reference = TextEditingController(),
      reason = TextEditingController();
  final keyValue = List.generate(
    24,
    (_) => Random.secure().nextInt(16).toRadixString(16),
  ).join();
  String? productId, variant, supplierId, orderId;
  bool restock = false, busy = false;
  String error = '';
  @override
  void dispose() {
    for (final c in [name, contact, notes, quantity, reference, reason]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget input(
    TextEditingController c,
    String label, {
    bool number = false,
    bool required = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: c,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (required && (v == null || v.trim().isEmpty)) return 'Required';
        if (number && (int.tryParse(v ?? '') ?? 0) < 1) {
          return 'Enter a positive whole number';
        }
        return null;
      },
    ),
  );
  Widget select(
    String label,
    String? value,
    Map<String, String> choices,
    ValueChanged<String?> change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label:$value:${choices.keys.join()}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: choices.entries
          .map(
            (e) => DropdownMenuItem(
              value: e.key,
              child: Text(e.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: busy ? null : change,
      validator: (v) => v == null ? 'Choose an option' : null,
    ),
  );
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final kind = widget.kind;
      final path = {
        'Supplier': 'supplier',
        'Receive': 'stock-event',
        'Damaged': 'stock-event',
        'Return': 'return',
        'Collection': 'collection',
      }[kind]!;
      await Api.call(path, {
        'key': keyValue,
        'kind': kind,
        'name': name.text,
        'contact': contact.text,
        'notes': notes.text,
        'product': productId,
        'variant': variant,
        'supplier': supplierId,
        'order_id': orderId,
        'qty': int.tryParse(quantity.text),
        'reference': reference.text,
        'reason': reason.text,
        'restock': restock,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final orderList = widget.orders
        .where(
          (o) => kind == 'Return'
              ? o['status'] == 'Completed'
              : o['status'] == 'Completed',
        )
        .toList();
    final order = orderList.where((o) => o['id'] == orderId).firstOrNull;
    final selected = widget.products
        .where((p) => p['id'] == productId)
        .firstOrNull;
    final returnLines = <String, dynamic>{
      for (final l in order?['items'] ?? []) '${l['id']}|${l['variant']}': l,
    };
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: Text(
          {
            'Supplier': 'Add supplier',
            'Receive': 'Receive stock',
            'Damaged': 'Record damaged stock',
            'Return': 'Record customer return',
            'Collection': 'Record payment collected',
          }[kind]!,
        ),
        content: SizedBox(
          width: 560,
          height: MediaQuery.sizeOf(context).height * .65,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (kind == 'Supplier') ...[
                    input(name, 'Supplier name'),
                    input(contact, 'Contact / phone'),
                    input(notes, 'Notes', required: false),
                  ] else ...[
                    if (kind == 'Return' || kind == 'Collection') ...[
                      if (orderList.isEmpty)
                        const Text('No eligible orders yet.'),
                      select(
                        'Order',
                        orderId,
                        {
                          for (final o in orderList)
                            o['id']: '${o['id']} · ${o['customer']}',
                        },
                        (v) => setState(() {
                          orderId = v;
                          productId = null;
                          variant = null;
                        }),
                      ),
                    ],
                    if (kind == 'Return') ...[
                      select(
                        'Returned item',
                        productId == null ? null : '$productId|$variant',
                        {
                          for (final e in returnLines.entries)
                            e.key: '${e.value['name']} · ${e.value['variant']}',
                        },
                        (v) => setState(() {
                          productId = returnLines[v]['id'];
                          variant = returnLines[v]['variant'];
                        }),
                      ),
                      input(quantity, 'Quantity', number: true),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: restock,
                        onChanged: (v) => setState(() => restock = v),
                        title: const Text('Item is suitable for resale'),
                        subtitle: const Text(
                          'Only enable after checking its condition.',
                        ),
                      ),
                      input(reason, 'Reason for return'),
                      const Text(
                        'This records the return and refund amount owed. It does not send money.',
                      ),
                    ] else if (kind == 'Collection') ...[
                      if (order != null)
                        Text('Full order amount: ${money(order['total'])}'),
                      input(reference, 'Receipt / collection reference'),
                      const Text(
                        'Record only money already received. This action does not charge the customer.',
                      ),
                    ] else ...[
                      select(
                        'Product',
                        productId,
                        {
                          for (final p in widget.products)
                            p['id']: '${p['name']} · ${p['id']}',
                        },
                        (v) => setState(() {
                          productId = v;
                          variant = null;
                        }),
                      ),
                      select('Size / colour', variant, {
                        for (final e
                            in (selected?['variants'] as Map? ?? {}).entries)
                          e.key: '${e.key} · ${e.value} available',
                      }, (v) => setState(() => variant = v)),
                      if (kind == 'Receive')
                        select('Supplier', supplierId, {
                          for (final s in widget.suppliers) s['id']: s['name'],
                        }, (v) => setState(() => supplierId = v)),
                      input(quantity, 'Quantity', number: true),
                      input(
                        reference,
                        kind == 'Receive'
                            ? 'Delivery note / invoice reference'
                            : 'Stock adjustment reference',
                      ),
                      input(reason, 'Reason / notes'),
                    ],
                  ],
                  if (error.isNotEmpty)
                    Text(error, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: busy ? null : save,
            child: Text(busy ? 'Saving…' : 'Save record'),
          ),
        ],
      ),
    );
  }
}

class ReportsPanel extends StatefulWidget {
  final Map<String, dynamic> data;
  const ReportsPanel({super.key, required this.data});

  @override
  State<ReportsPanel> createState() => _ReportsPanelState();
}

class _ReportsPanelState extends State<ReportsPanel> {
  String period = 'month';

  Map<String, dynamic> get report {
    final reports = widget.data['reports'] as Map? ?? {};
    return Map<String, dynamic>.from(
      (reports[period] as Map?) ?? widget.data['report'] as Map? ?? {},
    );
  }

  Widget metric(String name, String value, IconData icon, {Color? colour}) =>
      SizedBox(
        width: 220,
        child: Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: colour ?? green),
                const SizedBox(height: 12),
                Text(name, style: const TextStyle(color: Color(0xff697469))),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colour ?? ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  String reportText() {
    final labels = {
      'daily': 'Daily',
      'seven_days': '7-day',
      'month': 'Monthly',
      'six_months': 'Six-month',
      'year': 'One-year',
    };
    return '''Mary Inventory — ${labels[period]} report
${report['start'] ?? ''} to ${report['end'] ?? ''}
Net item sales: ${money(report['net_item_sales'] ?? 0)}
Gross margin: ${money(report['gross_margin'] ?? 0)}
Completed orders: ${report['completed_orders'] ?? 0}
Units sold: ${report['units_sold'] ?? 0}
Average order value: ${money(report['average_order_value'] ?? 0)}
Returns: ${money(report['returns_value'] ?? 0)}''';
  }

  @override
  Widget build(BuildContext context) {
    final r = report;
    final points = (r['buckets'] as List? ?? [])
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
    final health = widget.data['business_health'] as Map? ?? {};
    final comparison = r['comparison_percent'] as num?;
    final improving = comparison != null && comparison > 0;
    final falling = comparison != null && comparison < 0;
    final completed = r['completed_orders'] ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'daily', label: Text('Daily')),
                ButtonSegment(value: 'seven_days', label: Text('7 days')),
                ButtonSegment(value: 'month', label: Text('Monthly')),
                ButtonSegment(value: 'six_months', label: Text('6 months')),
              ],
              selected: {period},
              onSelectionChanged: (value) =>
                  setState(() => period = value.first),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: reportText()));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report summary copied')),
                  );
                }
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy report'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '${r['start'] ?? ''} to ${r['end'] ?? ''} · completed orders',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'Item sales exclude delivery fees. Gross margin is before delivery costs, shop expenses and taxes; it is not net profit.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            metric(
              'Net item sales',
              money(r['net_item_sales'] ?? 0),
              Icons.payments_outlined,
            ),
            metric(
              'Gross margin',
              money(r['gross_margin'] ?? 0),
              Icons.trending_up,
            ),
            metric(
              'Completed orders',
              '$completed',
              Icons.shopping_bag_outlined,
            ),
            metric(
              'Units sold',
              '${r['units_sold'] ?? 0}',
              Icons.checkroom_outlined,
            ),
            metric(
              'Average order',
              money(r['average_order_value'] ?? 0),
              Icons.receipt_long_outlined,
            ),
            metric(
              'Returns',
              money(r['returns_value'] ?? 0),
              Icons.keyboard_return,
              colour: (r['returns_value'] ?? 0) > 0 ? Colors.deepOrange : green,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Sales progress',
                      style: TextStyle(fontSize: 24),
                    ),
                    Chip(
                      avatar: Icon(
                        improving
                            ? Icons.arrow_upward
                            : falling
                            ? Icons.arrow_downward
                            : Icons.remove,
                        size: 18,
                        color: improving
                            ? green
                            : falling
                            ? Colors.deepOrange
                            : ink,
                      ),
                      label: Text(
                        comparison == null
                            ? 'No earlier-period sales to compare'
                            : '${comparison.abs().toStringAsFixed(1)}% ${improving
                                  ? 'up'
                                  : falling
                                  ? 'down'
                                  : 'unchanged'} vs previous period',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (points.every((p) => (p['sales'] as num? ?? 0) == 0))
                  const SizedBox(
                    height: 220,
                    child: Center(
                      child: Text(
                        'No completed sales in this period yet. The graph will appear as real sales are completed.',
                      ),
                    ),
                  )
                else
                    SalesTrendChart(points: points),
              ],
            ),
          ),
        ),
        if ((r['estimated_cost_lines'] ?? 0) > 0)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Some older orders use current product costs because their original cost was not recorded.',
            ),
          ),
        const SizedBox(height: 24),
        const Text('Business health', style: TextStyle(fontSize: 24)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            metric(
              'Stock at cost',
              money(health['stock_cost_value'] ?? 0),
              Icons.inventory_2_outlined,
            ),
            metric(
              'Potential stock sales',
              money(health['stock_retail_value'] ?? 0),
              Icons.storefront_outlined,
            ),
            metric('Margin rate', '${r['margin_rate'] ?? 0}%', Icons.percent),
            metric(
              'Low-stock options',
              '${health['low_stock_variants'] ?? 0}',
              Icons.warning_amber_rounded,
              colour: (health['low_stock_variants'] ?? 0) > 0
                  ? Colors.deepOrange
                  : green,
            ),
          ],
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _ReportList(
                title: 'Best sellers',
                empty: 'No completed product sales in this period.',
                children: [
                  for (final product in r['top_products'] ?? [])
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.star_outline),
                      title: Text(product['name']),
                      subtitle: Text('${product['units']} units sold'),
                      trailing: Text(money(product['sales'])),
                    ),
                ],
              ),
              _ReportList(
                title: 'Order pipeline',
                empty: 'No orders recorded yet.',
                children: [
                  for (final entry
                      in (health['order_statuses'] as Map? ?? {}).entries)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        entry.key == 'Completed'
                            ? Icons.check_circle_outline
                            : entry.key == 'Cancelled'
                            ? Icons.cancel_outlined
                            : Icons.pending_actions,
                      ),
                      title: Text(entry.key.toString()),
                      trailing: Text('${entry.value}'),
                    ),
                ],
              ),
            ];
            return constraints.maxWidth >= 850
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 16),
                      Expanded(child: cards[1]),
                    ],
                  )
                : Column(children: cards);
          },
        ),
        const SizedBox(height: 24),
        const Text('Low-stock alerts', style: TextStyle(fontSize: 24)),
        if ((widget.data['low_stock'] ?? []).isEmpty)
          const Text('No low-stock sizes.'),
        for (final p in widget.data['low_stock'] ?? [])
          Card(
            child: ListTile(
              leading: const Icon(Icons.warning_amber_rounded),
              title: Text(p['name']),
              subtitle: Text('${p['product']} · ${p['variant']}'),
              trailing: Text('${p['qty']} left'),
            ),
          ),
      ],
    );
  }
}

class _ReportList extends StatelessWidget {
  final String title, empty;
  final List<Widget> children;
  const _ReportList({
    required this.title,
    required this.empty,
    required this.children,
  });
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (children.isEmpty)
            Padding(padding: const EdgeInsets.all(12), child: Text(empty))
          else
            ...children,
        ],
      ),
    ),
  );
}

class SalesTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> points;
  const SalesTrendChart({super.key, required this.points});
  @override
  Widget build(BuildContext context) {
    final sales = points.map((p) => (p['sales'] as num).toDouble()).toList();
    final labelStep = max(1, (points.length / 6).ceil());
    final maximum = sales.isEmpty ? 0.0 : sales.reduce(max);
    return Semantics(
      label:
          'Sales line graph. ${points.map((p) => '${p['label']}: ${money(p['sales'])}').join(', ')}',
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const RotatedBox(
                quarterTurns: 3,
                child: Center(child: Text('Revenue (MWK)', style: TextStyle(fontSize: 11, color: Color(0xff697469)))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    SizedBox(
                      height: 260,
                      width: double.infinity,
                      child: CustomPaint(painter: _SalesLinePainter(sales: sales)),
                    ),
                    Positioned(
                      left: 8,
                      top: 4,
                      child: Text(money(maximum), style: const TextStyle(fontSize: 10, color: Color(0xff697469))),
                    ),
                    Positioned(
                      left: 8,
                      bottom: 4,
                      child: const Text('MWK 0', style: TextStyle(fontSize: 10, color: Color(0xff697469))),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < points.length; i++)
                if (i == 0 || i == points.length - 1 || i % labelStep == 0)
                  Text(
                    points[i]['label'].toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xff697469),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SalesLinePainter extends CustomPainter {
  final List<double> sales;
  const _SalesLinePainter({required this.sales});
  @override
  void paint(Canvas canvas, Size size) {
    const padding = 18.0;
    final width = size.width - padding * 2, height = size.height - padding * 2;
    final minimum = min(0.0, sales.reduce(min));
    final maximum = max(0.0, sales.reduce(max));
    final range = maximum - minimum == 0 ? 1.0 : maximum - minimum;
    final grid = Paint()
      ..color = const Color(0xffe1e5dc)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = padding + height * i / 4;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        grid,
      );
    }
    final path = Path();
    final line = Paint()
      ..color = green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..shader = LinearGradient(
        colors: [green.withValues(alpha: .22), green.withValues(alpha: .01)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, padding, size.width, height));
    final offsets = <Offset>[];
    for (var i = 0; i < sales.length; i++) {
      final x =
          padding +
          (sales.length == 1 ? width / 2 : width * i / (sales.length - 1));
      final y = padding + height - ((sales[i] - minimum) / range * height);
      offsets.add(Offset(x, y));
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    final zeroY = padding + height - ((0 - minimum) / range * height);
    final area = Path.from(path)
      ..lineTo(offsets.last.dx, zeroY)
      ..lineTo(offsets.first.dx, zeroY)
      ..close();
    canvas.drawPath(area, fill);
    canvas.drawPath(path, line);
    final dot = Paint()..color = green;
    for (final point in offsets) canvas.drawCircle(point, 3.5, dot);
  }

  @override
  bool shouldRepaint(covariant _SalesLinePainter oldDelegate) =>
      oldDelegate.sales != sales;
}
