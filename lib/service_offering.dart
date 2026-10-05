import 'package:flutter/material.dart';

const offeredServices = [
  'Solar cleaning',
  'Solar inspection',
  'Solar repair',
  'Electrical',
  'Plumbing',
  'Home cleaning',
];

class ServiceOffering {
  final String service, details;
  final int rate, years;
  const ServiceOffering(this.service, this.rate, this.years, this.details);
  factory ServiceOffering.fromJson(Map<String, dynamic> json) =>
      ServiceOffering(
        json['service'] as String,
        (json['hourly_rate'] as num).toInt(),
        (json['years'] as num).toInt(),
        json['details'] as String,
      );
  Map<String, dynamic> toJson() => {
    'service': service,
    'hourly_rate': rate,
    'years': years,
    'details': details,
  };
}

/// Form fields remain mounted when other services are selected.
class ServiceApplicationFields extends StatefulWidget {
  final ValueChanged<List<ServiceOffering>> onChanged;
  const ServiceApplicationFields({super.key, required this.onChanged});
  @override
  State<ServiceApplicationFields> createState() =>
      _ServiceApplicationFieldsState();
}

class _ServiceApplicationFieldsState extends State<ServiceApplicationFields> {
  final selected = <String>{};
  final rates = {for (final s in offeredServices) s: TextEditingController()};
  final years = {for (final s in offeredServices) s: TextEditingController()};
  final details = {for (final s in offeredServices) s: TextEditingController()};
  void changed() => widget.onChanged(
    selected
        .map(
          (s) => ServiceOffering(
            s,
            int.tryParse(rates[s]!.text) ?? 0,
            int.tryParse(years[s]!.text) ?? -1,
            details[s]!.text.trim(),
          ),
        )
        .toList(),
  );
  @override
  void dispose() {
    for (final c in [...rates.values, ...years.values, ...details.values]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Select your services',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      const Text(
        'Choose all services you offer. Enter a rate, experience and details for each.',
      ),
      const SizedBox(height: 12),
      FormField<bool>(
        validator: (_) =>
            selected.isEmpty ? 'Select at least one service' : null,
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: offeredServices
                  .map(
                    (s) => FilterChip(
                      label: Text(s),
                      selected: selected.contains(s),
                      onSelected: (v) {
                        setState(
                          () => v ? selected.add(s) : selected.remove(s),
                        );
                        field.didChange(selected.isNotEmpty);
                        changed();
                      },
                    ),
                  )
                  .toList(),
            ),
            if (field.hasError)
              Text(
                field.errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      for (final s in offeredServices)
        if (selected.contains(s))
          Card(
            key: ValueKey('application-$s'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextFormField(
                    controller: rates[s],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '$s hourly rate (₹)',
                    ),
                    onChanged: (_) => changed(),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 1 || n > 100000
                          ? 'Enter ₹1–100,000'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: years[s],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '$s experience (years)',
                    ),
                    onChanged: (_) => changed(),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 0 || n > 60
                          ? 'Enter 0–60 years'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: details[s],
                    maxLines: 3,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      labelText: '$s service details',
                    ),
                    onChanged: (_) => changed(),
                    validator: (v) => (v?.trim().length ?? 0) < 20
                        ? 'Write at least 20 characters'
                        : null,
                  ),
                ],
              ),
            ),
          ),
    ],
  );
}
