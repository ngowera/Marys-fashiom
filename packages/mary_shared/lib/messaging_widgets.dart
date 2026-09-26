part of 'mary_shared.dart';

class AccountDialog extends StatefulWidget {
  const AccountDialog({super.key});
  @override
  State<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<AccountDialog> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool creating = false, busy = false;
  String error = '';
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      if (creating) {
        await Api.signUp(email.text, password.text);
      } else {
        await Api.signIn(email.text, password.text);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(creating ? 'Create your account' : 'Sign in'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email address'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => setState(() => creating = !creating),
        child: Text(creating ? 'I already have an account' : 'Create account'),
      ),
      OutlinedButton.icon(
        onPressed: busy
            ? null
            : () async {
                try {
                  await Api.signInWithGoogle();
                } catch (e) {
                  if (mounted) setState(() => error = e.toString());
                }
              },
        icon: const Icon(Icons.account_circle_outlined),
        label: const Text('Continue with Google'),
      ),
      FilledButton(
        onPressed: busy ? null : submit,
        child: Text(
          busy
              ? 'Please wait…'
              : creating
              ? 'Create account'
              : 'Sign in',
        ),
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
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
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
  const MessagesPanel({super.key, required this.reload});
  @override
  State<MessagesPanel> createState() => _MessagesPanelState();
}

class _MessagesPanelState extends State<MessagesPanel> {
  String filter = 'All';
  List<dynamic> threads = [], messages = [];
  Map<String, dynamic>? selected;
  final composer = TextEditingController();
  bool sending = false;
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
      final result = await Api.call('messages', {'staff': true});
      if (mounted) setState(() { threads = result['threads'] ?? []; error = ''; });
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> open(Map<String, dynamic> thread) async {
    try {
      final result = await Api.call('message-thread', {
        'thread_id': thread['id'],
      });
      await Api.call('message-read', {'thread_id': thread['id']});
      if (mounted) setState(() { selected = thread; messages = result['messages'] ?? []; error = ''; });
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
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
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  List<dynamic> get visible => threads.where((raw) {
    final t = raw as Map;
    return filter == 'All' ||
        (filter == 'Unread' && t['unread'] == true) ||
        t['status'] == filter.toLowerCase();
  }).toList();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Expanded(child: Wrap(spacing: 24, children: [for (final item in ['All', 'Unread', 'Open', 'Closed']) TextButton(onPressed: () => setState(() => filter = item), child: Text(item, style: TextStyle(fontWeight: filter == item ? FontWeight.bold : FontWeight.normal))) ])),
        IconButton(tooltip: 'Refresh messages', onPressed: load, icon: const Icon(Icons.refresh)),
      ]),
      if (error.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(child: Text(error, style: const TextStyle(color: Colors.red))),
            TextButton(onPressed: load, child: const Text('Retry')),
          ]),
        ),
      const Divider(height: 1),
      Expanded(
        child: Row(
          children: [
            SizedBox(
              width: 360,
              child: ListView(
                children: [
                  for (final raw in visible)
                    Builder(
                      builder: (_) {
                        final t = Map<String, dynamic>.from(raw as Map);
                        return ListTile(
                          selected: selected?['id'] == t['id'],
                          leading: Badge(
                            isLabelVisible: t['unread'] == true,
                            child: const CircleAvatar(
                              child: Icon(Icons.person_outline),
                            ),
                          ),
                          title: Text(
                            t['customer_email'] ?? 'Customer message',
                          ),
                          subtitle: Text(
                            '${t['subject'] ?? 'Conversation'} · ${t['status']}',
                          ),
                          trailing: t['unread'] == true
                              ? const Icon(
                                  Icons.mark_email_unread_outlined,
                                  color: green,
                                )
                              : null,
                          onTap: () => open(t),
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
