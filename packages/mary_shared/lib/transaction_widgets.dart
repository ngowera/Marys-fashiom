part of 'mary_shared.dart';

class TransactionsPanel extends StatefulWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() reload;
  const TransactionsPanel({super.key, required this.data, required this.reload});
  @override
  State<TransactionsPanel> createState() => _TransactionsPanelState();
}

class _TransactionsPanelState extends State<TransactionsPanel> {
  String filter = 'All';
  String query = '';
  List<Map<String, dynamic>> get transactions =>
      (widget.data['transactions'] as List? ?? [])
          .map((value) => Map<String, dynamic>.from(value as Map))
          .where((value) {
            final status = value['status'].toString().toLowerCase();
            final matchesFilter =
                filter == 'All' ||
                (filter == 'Successful' && status == 'success') ||
                (filter == 'Pending' && status == 'pending') ||
                (filter == 'Failed' && status == 'failed') ||
                (filter == 'Cancelled' && value['order_status'] == 'Cancelled');
            final text =
                '${value['tx_ref']} ${value['customer']} ${value['order_id']}'
                    .toLowerCase();
            return matchesFilter && text.contains(query.toLowerCase());
          })
          .toList();
  int get totalCollected => (widget.data['transactions'] as List? ?? [])
      .where((value) => value['status'] == 'success')
      .fold(0, (sum, value) => sum + (value['amount'] as int? ?? 0));
  int count(String status) => (widget.data['transactions'] as List? ?? [])
      .where((value) => (value as Map)['status'] == status)
      .length;
  Widget metric(String label, String value, String caption) => Expanded(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xff697469))),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(
            caption,
            style: const TextStyle(fontSize: 12, color: Color(0xff8a908a)),
          ),
        ],
      ),
    ),
  );
  void showDetails(Map<String, dynamic> item) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Transaction details'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _detail('Status', item['status']),
              _detail('Amount', money(item['amount'] ?? 0)),
              _detail('Currency', item['currency'] ?? 'MWK'),
              _detail('Customer', item['customer']),
              _detail('Order', item['order_id']),
              _detail('Reference', item['tx_ref']),
              _detail('Provider reference', item['provider_reference']),
              _detail('Payment method', item['payment_method']),
              _detail('Channel', item['channel']),
              _detail('Provider', item['provider_type']),
              _detail('Mode', item['provider_mode']),
              _detail('Provider charges', money(item['provider_charges'] ?? 0)),
              _detail('Created', _transactionDateTime(item['created_at'])),
              _detail('Completed', _transactionDateTime(item['completed_at'])),
            ]),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
  Widget _detail(String label, dynamic value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 145, child: Text(label, style: const TextStyle(color: Color(0xff697469)))),
      Expanded(child: Text(value?.toString().isNotEmpty == true ? value.toString() : 'Not provided')),
    ]),
  );
  @override
  Widget build(BuildContext context) {
    final all = widget.data['transactions'] as List? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Transactions',
              style: TextStyle(fontFamily: 'BrandSerif', fontSize: 30),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Refresh transactions',
              onPressed: widget.reload,
              icon: const Icon(Icons.refresh),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final document = pw.Document();
                document.addPage(pw.MultiPage(
                  build: (_) => [
                    pw.Text('Mary Inventory - Transactions', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.Text('Total collected: ${money(totalCollected)}'),
                    pw.SizedBox(height: 12),
                    pw.Table.fromTextArray(
                      headers: const ['Reference', 'Order', 'Customer', 'Amount', 'Status', 'Method', 'Channel', 'Date'],
                      data: [
                        for (final item in widget.data['transactions'] as List? ?? [])
                          [item['tx_ref'] ?? '', item['order_id'] ?? '', item['customer'] ?? '', money(item['amount'] ?? 0), item['status'] ?? '', item['payment_method'] ?? '', item['channel'] ?? '', _transactionDateTime(item['created_at'])],
                      ],
                    ),
                  ],
                ));
                final location = await getSaveLocation(
                  suggestedName: 'mary-transactions.pdf',
                  acceptedTypeGroups: [const XTypeGroup(label: 'PDF', extensions: ['pdf'])],
                );
                if (location == null) return;
                await XFile.fromData(await document.save(), mimeType: 'application/pdf').saveTo(location.path);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transactions PDF exported')));
              },
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Export'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.white,
          child: Row(
            children: [
              metric(
                'Total collected',
                money(totalCollected),
                'Successful payments',
              ),
              metric('Transactions', '${all.length}', 'All payment attempts'),
              metric(
                'Pending payments',
                '${count('pending')}',
                'Awaiting confirmation',
              ),
              metric(
                'Failed payments',
                '${count('failed')}',
                'Unsuccessful attempts',
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Card(
          color: Colors.white,
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final item in [
                      'All',
                      'Successful',
                      'Pending',
                      'Failed',
                      'Cancelled',
                    ])
                      TextButton(
                        onPressed: () => setState(() => filter = item),
                        child: Text(
                          item,
                          style: TextStyle(
                            fontWeight: filter == item
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  onChanged: (value) => setState(() => query = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search reference, customer, or order',
                  ),
                ),
              ),
              const Divider(height: 1),
              SizedBox(
                height: 380,
                child: transactions.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.credit_card_outlined,
                              size: 42,
                              color: Color(0xff8a908a),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No transactions found',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Completed and pending PayChangu payments will appear here.',
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: transactions.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final item = transactions[index];
                          final status = item['status'].toString();
                          final colour = status == 'success'
                              ? green
                              : status == 'failed'
                              ? Colors.red
                              : Colors.orange;
                          return ListTile(
                            leading: Icon(
                              status == 'success'
                                  ? Icons.check_circle_outline
                                  : Icons.payments_outlined,
                              color: colour,
                            ),
                            title: Text(
                              '${item['customer']} · ${money(item['amount'] ?? 0)}',
                            ),
                            subtitle: Text(
                              '${item['tx_ref']} · Order ${item['order_id']}\n${_transactionDate(item['created_at'])}',
                            ),
                            isThreeLine: true,
                            onTap: () => showDetails(item),
                            trailing: Chip(
                              label: Text(status),
                              side: BorderSide.none,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'Amounts shown in MWK',
            style: TextStyle(color: Color(0xff697469)),
          ),
        ),
      ],
    );
  }
}

String _transactionDate(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  return date == null ? '' : '${date.day}/${date.month}/${date.year}';
}

String _transactionDateTime(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  return date == null ? '' : '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
