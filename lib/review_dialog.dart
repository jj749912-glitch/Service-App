import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewDialog extends StatefulWidget {
  final Map<String, dynamic> booking;
  const ReviewDialog({required this.booking, super.key});
  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  final form = GlobalKey<FormState>();
  final author = TextEditingController(), body = TextEditingController();
  int rating = 5;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    author.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('How was your service?'),
    content: SingleChildScrollView(
      child: SizedBox(
        width: 400,
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.booking['professional_name']),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: rating,
                decoration: const InputDecoration(labelText: 'Your rating'),
                items: [1, 2, 3, 4, 5]
                    .map((r) => DropdownMenuItem(value: r, child: Text('$r ★')))
                    .toList(),
                onChanged: busy ? null : (v) => rating = v!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: author,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Your display name',
                ),
                validator: (v) =>
                    (v?.trim().length ?? 0) < 2 ? 'Enter your name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: body,
                maxLength: 2000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Tell others about your experience',
                ),
                validator: (v) => (v?.trim().length ?? 0) < 5
                    ? 'Write at least 5 characters'
                    : null,
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                if (!form.currentState!.validate()) return;
                setState(() => busy = true);
                try {
                  final client = Supabase.instance.client;
                  await client.from('reviews').insert({
                    'booking_id': widget.booking['id'],
                    'professional_id': widget.booking['professional_id'],
                    'customer_id': client.auth.currentUser!.id,
                    'author_name': author.text.trim(),
                    'rating': rating,
                    'body': body.text.trim(),
                  });
                  if (context.mounted) Navigator.pop(context, true);
                } on PostgrestException catch (e) {
                  if (mounted) {
                    setState(() {
                      busy = false;
                      error = e.code == '23505'
                          ? 'You have already reviewed this service.'
                          : 'Reviews are available only for your completed services.';
                    });
                  }
                } catch (_) {
                  if (mounted) {
                    setState(() {
                      busy = false;
                      error = 'Review could not be saved. Please retry.';
                    });
                  }
                }
              },
        child: Text(busy ? 'Publishing…' : 'Publish review'),
      ),
    ],
  );
}
