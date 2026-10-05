import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mobile/customer_data.dart';
import 'mobile/design.dart';

class BookingChat extends StatefulWidget {
  final Map<String, dynamic> booking;
  const BookingChat({super.key, required this.booking});
  @override
  State<BookingChat> createState() => _BookingChatState();
}

class _BookingChatState extends State<BookingChat> {
  final client = Supabase.instance.client;
  final message = TextEditingController();
  List<Map<String, dynamic>> rows = [];
  Timer? timer;
  bool busy = false, loading = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 5), (_) => load());
  }

  @override
  void dispose() {
    timer?.cancel();
    message.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (loading) return;
    loading = true;
    try {
      final data = await client
          .from('booking_messages')
          .select()
          .eq('booking_id', widget.booking['id'])
          .order('created_at', ascending: false)
          .limit(200);
      if (mounted) setState(() => rows = data.reversed.toList());
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not refresh messages. Please retry.');
      }
    } finally {
      loading = false;
    }
  }

  Future<void> send() async {
    final body = message.text.trim();
    if (body.isEmpty || body.length > 2000) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await client.from('booking_messages').insert({
        'booking_id': widget.booking['id'],
        'sender_id': client.auth.currentUser!.id,
        'body': body,
      });
      message.clear();
      await load();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Message was not sent. Check your connection and booking access.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(displayService(widget.booking['service'] as String)),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          children: [
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            Expanded(
              child: rows.isEmpty
                  ? const Center(
                      child: Text(
                        'No messages yet. Send a message about this booking.',
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        for (final row in rows)
                          Align(
                            alignment:
                                row['sender_id'] == client.auth.currentUser!.id
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 340),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color:
                                    row['sender_id'] ==
                                        client.auth.currentUser!.id
                                    ? const Color(0xFFDFF1FF)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(row['body'] as String),
                                  Text(
                                    formatTime(
                                      DateTime.parse(
                                        row['created_at'] as String,
                                      ).toLocal(),
                                    ),
                                    style: const TextStyle(
                                      color: serveMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: message,
                        enabled: !busy,
                        maxLength: 2000,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Write a message',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      onPressed: busy ? null : send,
                      icon: const Icon(Icons.send),
                      tooltip: 'Send Message',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
