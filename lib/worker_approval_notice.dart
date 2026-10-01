import 'package:flutter/material.dart';

class WorkerApprovalNotice extends StatelessWidget {
  final String status, note;
  const WorkerApprovalNotice({super.key, required this.status, this.note = ''});
  @override
  Widget build(BuildContext context) {
    final title = switch (status) {
      'rejected' => 'Application not approved',
      'suspended' => 'Worker access suspended',
      _ => 'Awaiting admin approval',
    };
    final message = switch (status) {
      'rejected' =>
        'An administrator reviewed your application. Your profile is not listed and you cannot receive jobs.',
      'suspended' =>
        'Your profile is hidden and service requests are unavailable until an administrator restores your access.',
      _ =>
        'Your application has been received. An administrator must verify your identity and qualifications before you can receive jobs. Approval is required only once.',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(message),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Admin review',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(note),
            ],
            const SizedBox(height: 12),
            const Text('Use Refresh to check for an update.'),
          ],
        ),
      ),
    );
  }
}
