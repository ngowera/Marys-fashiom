part of 'mary_shared.dart';

Widget googleSignInButton({
  required VoidCallback? onPressed,
  String label = 'Continue with Google',
}) => OutlinedButton.icon(
  onPressed: onPressed,
  style: OutlinedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: ink,
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
    side: const BorderSide(color: Color(0xffc8ccc8)),
  ),
  icon: ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: Image.asset(
      'assets/images/google-logo.jpg',
      package: 'mary_shared',
      width: 24,
      height: 24,
      fit: BoxFit.cover,
    ),
  ),
  label: Text(label),
);

class AccountDialog extends StatefulWidget {
  const AccountDialog({super.key});
  @override
  State<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<AccountDialog> {
  bool busy = false;
  String error = '';

  Future<void> continueWithGoogle() async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final opened = await Api.signInWithGoogle();
      if (!opened) throw Exception('Unable to open Google sign-in.');
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Sign in with Google'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Use your Google account to track orders, write verified reviews and contact Mary’s Fashion.',
          ),
          if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: googleSignInButton(
              onPressed: busy ? null : continueWithGoogle,
              label: busy ? 'Opening Google…' : 'Continue with Google',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}

class OrderTrackingDialog extends StatefulWidget {
  const OrderTrackingDialog({super.key});
  @override
  State<OrderTrackingDialog> createState() => _OrderTrackingDialogState();
}

class _OrderTrackingDialogState extends State<OrderTrackingDialog> {
  final orderReference = TextEditingController();
  final trackingCode = TextEditingController();
  List<dynamic> orders = [];
  Map<String, dynamic>? guestOrder;
  bool loading = true, checking = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    loadOrders();
  }

  @override
  void dispose() {
    orderReference.dispose();
    trackingCode.dispose();
    super.dispose();
  }

  Future<void> loadOrders() async {
    try {
      final result = await Api.call('my-orders');
      if (mounted) setState(() => orders = result['orders'] as List? ?? []);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> lookupGuestOrder() async {
    if (orderReference.text.trim().isEmpty ||
        trackingCode.text.trim().isEmpty) {
      setState(
        () => error = 'Enter the order reference and private tracking code.',
      );
      return;
    }
    setState(() {
      checking = true;
      error = '';
    });
    try {
      final result = await Api.call('track', {
        'id': orderReference.text.trim(),
        'token': trackingCode.text.trim(),
      });
      if (mounted) setState(() => guestOrder = result);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  Widget orderCard(Map<String, dynamic> order) {
    final items = order['items'] as List? ?? [];
    final payment = order['payment_status']?.toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order['id']?.toString() ?? 'Order',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  order['status']?.toString() ?? 'Placed',
                  style: const TextStyle(
                    color: green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${money(order['total'] ?? 0)}${payment == null ? '' : ' · $payment'}',
            ),
            Text('Delivery: ${order['delivery'] ?? 'To be confirmed'}'),
            const Divider(height: 20),
            for (final item in items)
              Text(
                '${item['qty']} × ${item['name']}${item['variant'] == null ? '' : ' · ${item['variant']}'}',
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Track your orders'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Orders placed while signed in with this Google account appear here.',
            ),
            const SizedBox(height: 16),
            if (loading) const Center(child: CircularProgressIndicator()),
            if (!loading && orders.isEmpty)
              const Text('No orders are linked to this Google account yet.'),
            for (final raw in orders)
              orderCard(Map<String, dynamic>.from(raw as Map)),
            const Divider(height: 32),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Track an older or guest order'),
              children: [
                TextField(
                  controller: orderReference,
                  decoration: const InputDecoration(
                    labelText: 'Order reference',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: trackingCode,
                  decoration: const InputDecoration(
                    labelText: 'Private tracking code',
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: checking ? null : lookupGuestOrder,
                    child: Text(checking ? 'Checking…' : 'Check status'),
                  ),
                ),
                if (guestOrder != null) orderCard(guestOrder!),
              ],
            ),
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(error, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}

class CustomerMessagesPage extends StatefulWidget {
  const CustomerMessagesPage({super.key});
  @override
  State<CustomerMessagesPage> createState() => _CustomerMessagesPageState();
}

class _CustomerMessagesPageState extends State<CustomerMessagesPage> {
  List<dynamic> threads = [], messages = [];
  Map<String, dynamic>? selected;
  final composer = TextEditingController();
  bool loading = true, sending = false;
  String error = '';
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    composer.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final result = await Api.call('messages', {'staff': false});
      if (!mounted) return;
      setState(() {
        threads = result['threads'] ?? [];
        loading = false;
        error = '';
      });
      if (selected != null) await open(selected!);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString().replaceFirst('Exception: ', '');
          loading = false;
        });
      }
    }
  }

  Future<void> open(Map<String, dynamic> thread) async {
    setState(() => selected = thread);
    try {
      final result = await Api.call('message-thread', {
        'thread_id': thread['id'],
      });
      if (!mounted) return;
      setState(() => messages = result['messages'] ?? []);
      await Api.call('message-read', {'thread_id': thread['id']});
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> send() async {
    if (composer.text.trim().isEmpty || sending) return;
    setState(() => sending = true);
    try {
      final result = await Api.call('message-send', {
        'thread_id': selected?['id'],
        'body': composer.text.trim(),
        'subject': 'Message from customer',
      });
      composer.clear();
      await load();
      if (selected == null && result['thread_id'] != null) {
        final created = threads
            .where((thread) => (thread as Map)['id'] == result['thread_id'])
            .firstOrNull;
        if (created != null)
          await open(Map<String, dynamic>.from(created as Map));
      }
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Widget threadList() => ListView(
    children: [
      if (threads.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No conversations yet. Send a message to Mary’s Fashion.',
          ),
        ),
      for (final raw in threads)
        Builder(
          builder: (_) {
            final thread = Map<String, dynamic>.from(raw as Map);
            return ListTile(
              selected: selected?['id'] == thread['id'],
              title: Text(thread['subject'] ?? 'Conversation'),
              subtitle: Text(
                '${thread['status'] ?? 'open'} · ${_shortDate(thread['last_message_at'])}',
              ),
              trailing: thread['unread'] == true
                  ? const Icon(Icons.mark_email_unread_outlined, color: green)
                  : null,
              onTap: () => open(thread),
            );
          },
        ),
    ],
  );
  Widget conversation() => selected == null
      ? Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Start a conversation with Mary’s Fashion',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: composer,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'Write your message',
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: sending ? null : send,
                  icon: const Icon(Icons.send),
                  label: const Text('Send message'),
                ),
              ],
            ),
          ),
        )
      : Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  for (final raw in messages)
                    _bubble(Map<String, dynamic>.from(raw as Map)),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: composer,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Write a message',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Send message',
                    onPressed: sending ? null : send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        );
  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error.isNotEmpty) return Center(child: Text(error));
    final wide = MediaQuery.sizeOf(context).width >= 760;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Messages',
          style: TextStyle(fontFamily: 'BrandSerif', fontSize: 30),
        ),
        const SizedBox(height: 4),
        const Text(
          'Ask about products, sizing, delivery or an existing order.',
        ),
        const SizedBox(height: 16),
        Expanded(
          child: wide
              ? Row(
                  children: [
                    SizedBox(width: 300, child: threadList()),
                    const VerticalDivider(width: 1),
                    Expanded(child: conversation()),
                  ],
                )
              : selected == null
              ? threadList()
              : conversation(),
        ),
      ],
    );
  }
}

class MessagesPanel extends StatefulWidget {
  final Future<void> Function() reload;
  final List<dynamic> products;
  const MessagesPanel({
    super.key,
    required this.reload,
    this.products = const [],
  });

  @override
  State<MessagesPanel> createState() => _MessagesPanelState();
}

class _MessagesPanelState extends State<MessagesPanel> {
  String section = 'Messages', filter = 'All';
  List<dynamic> threads = [], messages = [], reviews = [];
  Map<String, dynamic>? selected, selectedReview;
  final composer = TextEditingController();
  final reviewComposer = TextEditingController();
  bool sending = false, replyingToReview = false;
  String error = '', reviewError = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    composer.dispose();
    reviewComposer.dispose();
    super.dispose();
  }

  String productName(dynamic id) {
    for (final raw in widget.products) {
      final product = raw as Map;
      if (product['id'] == id) return product['name']?.toString() ?? '$id';
    }
    return id?.toString() ?? 'Product';
  }

  Future<void> load() async {
    try {
      final result = await Api.call('messages', {'staff': true});
      if (mounted) {
        setState(() {
          threads = result['threads'] ?? [];
          error = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
    try {
      final result = await Api.call('staff-reviews');
      if (!mounted) return;
      final loaded = result['reviews'] as List? ?? [];
      final selectedId = selectedReview?['id'];
      setState(() {
        reviews = loaded;
        selectedReview = selectedId == null
            ? selectedReview
            : loaded
                  .where((raw) => (raw as Map)['id'] == selectedId)
                  .map((raw) => Map<String, dynamic>.from(raw as Map))
                  .firstOrNull;
        reviewError = '';
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => reviewError = e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  Future<void> open(Map<String, dynamic> thread) async {
    try {
      final result = await Api.call('message-thread', {
        'thread_id': thread['id'],
      });
      await Api.call('message-read', {'thread_id': thread['id']});
      if (mounted) {
        setState(() {
          selected = thread;
          messages = result['messages'] ?? [];
          error = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> reply() async {
    if (composer.text.trim().isEmpty) return;
    setState(() => sending = true);
    try {
      await Api.call('message-send', {
        'thread_id': selected?['id'],
        'body': composer.text.trim(),
      });
      composer.clear();
      await load();
      await open(selected!);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void selectReview(Map<String, dynamic> review) {
    reviewComposer.text = review['reply_body']?.toString() ?? '';
    setState(() => selectedReview = review);
  }

  Future<void> replyToReview() async {
    if (selectedReview == null || reviewComposer.text.trim().isEmpty) return;
    setState(() {
      replyingToReview = true;
      reviewError = '';
    });
    try {
      await Api.call('review-reply', {
        'review_id': selectedReview!['id'],
        'reply': reviewComposer.text.trim(),
      });
      await load();
    } catch (e) {
      if (mounted) {
        setState(
          () => reviewError = e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => replyingToReview = false);
    }
  }

  List<dynamic> get visible => threads.where((raw) {
    final thread = raw as Map;
    return filter == 'All' ||
        (filter == 'Unread' && thread['unread'] == true) ||
        thread['status'] == filter.toLowerCase();
  }).toList();

  Widget errorNotice(String message) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(message, style: const TextStyle(color: Colors.red)),
        ),
        TextButton(onPressed: load, child: const Text('Retry')),
      ],
    ),
  );

  Widget conversationsPanel() => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 12,
              children: [
                for (final item in ['All', 'Unread', 'Open', 'Closed'])
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
        ],
      ),
      if (error.isNotEmpty) errorNotice(error),
      const Divider(height: 1),
      Expanded(
        child: Row(
          children: [
            SizedBox(
              width: 340,
              child: ListView(
                children: [
                  if (visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No customer messages yet.'),
                    ),
                  for (final raw in visible)
                    Builder(
                      builder: (_) {
                        final thread = Map<String, dynamic>.from(raw as Map);
                        return ListTile(
                          selected: selected?['id'] == thread['id'],
                          leading: Badge(
                            isLabelVisible: thread['unread'] == true,
                            child: const CircleAvatar(
                              child: Icon(Icons.person_outline),
                            ),
                          ),
                          title: Text(
                            thread['customer_email'] ?? 'Customer message',
                          ),
                          subtitle: Text(
                            '${thread['subject'] ?? 'Conversation'} · ${thread['status']}',
                          ),
                          trailing: thread['unread'] == true
                              ? const Icon(
                                  Icons.mark_email_unread_outlined,
                                  color: green,
                                )
                              : null,
                          onTap: () => open(thread),
                        );
                      },
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: selected == null
                  ? const Center(child: Text('Select a conversation'))
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  selected!['subject'] ?? 'Conversation',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (status) async {
                                  await Api.call('message-status', {
                                    'thread_id': selected!['id'],
                                    'status': status,
                                  });
                                  await load();
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'open',
                                    child: Text('Reopen'),
                                  ),
                                  PopupMenuItem(
                                    value: 'closed',
                                    child: Text('Close conversation'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(18),
                            children: [
                              for (final raw in messages)
                                _bubble(Map<String, dynamic>.from(raw as Map)),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: composer,
                                  maxLines: 4,
                                  decoration: const InputDecoration(
                                    hintText: 'Reply to customer',
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Send message',
                                onPressed: sending ? null : reply,
                                icon: const Icon(Icons.send),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget reviewsPanel() => Column(
    children: [
      const SizedBox(height: 8),
      if (reviewError.isNotEmpty) errorNotice(reviewError),
      Expanded(
        child: Row(
          children: [
            SizedBox(
              width: 340,
              child: ListView(
                children: [
                  if (reviews.isEmpty && reviewError.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No customer reviews yet.'),
                    ),
                  for (final raw in reviews)
                    Builder(
                      builder: (_) {
                        final review = Map<String, dynamic>.from(raw as Map);
                        return ListTile(
                          selected: selectedReview?['id'] == review['id'],
                          leading: CircleAvatar(
                            child: Text('${review['rating']}★'),
                          ),
                          title: Text(review['reviewer_name'] ?? 'Customer'),
                          subtitle: Text(
                            '${productName(review['product_id'])} · ${review['reply_body'] == null ? 'Needs reply' : 'Replied'}',
                          ),
                          trailing: review['reply_body'] == null
                              ? const Icon(Icons.reply_outlined, color: green)
                              : const Icon(Icons.check_circle_outline),
                          onTap: () => selectReview(review),
                        );
                      },
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: selectedReview == null
                  ? const Center(child: Text('Select a customer review'))
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          productName(selectedReview!['product_id']),
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${selectedReview!['reviewer_name']} · ${List.filled((selectedReview!['rating'] as num).toInt(), '★').join()}',
                          style: const TextStyle(color: green),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          selectedReview!['body'] ?? '',
                          style: const TextStyle(fontSize: 16, height: 1.45),
                        ),
                        const Divider(height: 36),
                        TextField(
                          controller: reviewComposer,
                          maxLines: 5,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                            labelText: 'Public reply from Mary’s Fashion',
                            hintText: 'Thank the customer or respond to their feedback.',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: replyingToReview ? null : replyToReview,
                            icon: const Icon(Icons.reply),
                            label: Text(
                              replyingToReview
                                  ? 'Publishing reply…'
                                  : selectedReview!['reply_body'] == null
                                  ? 'Publish reply'
                                  : 'Update public reply',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This reply will appear publicly beneath the customer’s review on the shop website.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xff697469),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Messages'),
                  selected: section == 'Messages',
                  onSelected: (_) => setState(() => section = 'Messages'),
                ),
                ChoiceChip(
                  label: Text('Reviews (${reviews.length})'),
                  selected: section == 'Reviews',
                  onSelected: (_) => setState(() => section = 'Reviews'),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh customer communication',
            onPressed: load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Expanded(
        child: section == 'Reviews' ? reviewsPanel() : conversationsPanel(),
      ),
    ],
  );
}

Widget _bubble(Map<String, dynamic> message) => Align(
  alignment: message['sender_user_id'] == Api.userId
      ? Alignment.centerRight
      : Alignment.centerLeft,
  child: Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    constraints: const BoxConstraints(maxWidth: 600),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xffd5dbd2)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(message['body'] ?? ''),
  ),
);
String _shortDate(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  return date == null ? '' : '${date.day}/${date.month}';
}
