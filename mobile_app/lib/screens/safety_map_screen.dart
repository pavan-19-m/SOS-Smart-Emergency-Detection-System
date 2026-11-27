import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SafetyMapScreen extends StatefulWidget {
  const SafetyMapScreen({super.key});

  @override
  State<SafetyMapScreen> createState() => _SafetyMapScreenState();
}

class _SafetyMapScreenState extends State<SafetyMapScreen> {
  late Future<Map<String, dynamic>> _snapshot;
  String _layer = 'Combined overview';
  String _crimeCategory = 'All categories';

  @override
  void initState() {
    super.initState();
    _snapshot = _loadSnapshot();
  }

  Future<Map<String, dynamic>> _loadSnapshot() async {
    try {
      final raw = await rootBundle.loadString('assets/safety_summary.json');
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return const {'availability': 'unavailable', 'dataStatus': 'historical'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety Map')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _snapshot,
        builder: (context, state) {
          if (state.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = state.data ?? const <String, dynamic>{};
          final accidents = (data['accidents'] as Map?) ?? const {};
          final crimes = (data['crimes'] as Map?) ?? const {};
          final accidentRows = (accidents['records'] as List?) ?? const [];
          final crimeRows = (crimes['records'] as List?) ?? const [];
          final availability = data['availability']?.toString() ?? 'unavailable';
          final showAccidents = _layer != 'Crime';
          final showCrimes = _layer != 'Accidents';
          final categoryOptions = crimeRows
              .map((row) => (row as Map)['sourceCategory']?.toString() ?? '')
              .where((category) => category.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          final selectedCategory = categoryOptions.contains(_crimeCategory)
              ? _crimeCategory
              : 'All categories';
          final visibleCrimes = selectedCategory == 'All categories'
              ? crimeRows
              : crimeRows
                  .where((row) =>
                      (row as Map)['sourceCategory'] == selectedCategory)
                  .toList();
          return RefreshIndicator(
            onRefresh: () async => setState(() => _snapshot = _loadSnapshot()),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Icon(Icons.history), SizedBox(width: 8), Text('Historical reported records', style: TextStyle(fontWeight: FontWeight.bold))]),
                      SizedBox(height: 8),
                      Text('Awareness information only. Records may be incomplete, delayed, or affected by reporting bias. Concentration levels do not guarantee the safety or danger of a location.'),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Combined overview', label: Text('Combined')),
                    ButtonSegment(value: 'Accidents', label: Text('Accidents')),
                    ButtonSegment(value: 'Crime', label: Text('Crime')),
                  ],
                  selected: {_layer},
                  onSelectionChanged: (selection) => setState(() => _layer = selection.first),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [const Icon(Icons.map_outlined), const SizedBox(width: 8), Text('Geographic view', style: Theme.of(context).textTheme.titleMedium)]),
                      const SizedBox(height: 8),
                      Text(availability == 'unavailable'
                          ? 'Official source files have not been ingested yet. The download host challenged automated access; no sample incidents are shown.'
                          : 'Source records have no incident coordinates. Counts are shown at the published station or city level; no point locations or false distance estimates are drawn.'),
                      const SizedBox(height: 8),
                      const Text('Nearby search is unavailable until a source provides defensible geographic coordinates or area boundaries.'),
                    ]),
                  ),
                ),
                if (showAccidents) ...[
                  _sectionHeader(context, 'Road crashes · 2023', 'Police station aggregate'),
                  if (accidentRows.isEmpty)
                    const _EmptyDataCard(message: 'No verified crash records are bundled. Run the documented source refresh after the publisher CSV is accessible.'),
                  ...accidentRows.map((row) => _accidentCard(context, Map<String, dynamic>.from(row as Map))),
                ],
                if (showCrimes) ...[
                  _sectionHeader(context, 'Reported crimes · 2021–2023', 'Bengaluru city totals by category'),
                  if (crimeRows.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Crime category'),
                      items: [
                        const DropdownMenuItem(value: 'All categories', child: Text('All categories')),
                        ...categoryOptions.map((category) => DropdownMenuItem(value: category, child: Text(category))),
                      ],
                      onChanged: (value) => setState(() => _crimeCategory = value ?? 'All categories'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (crimeRows.isEmpty)
                    const _EmptyDataCard(message: 'No verified crime records are bundled. City totals cannot identify street or police-station hotspots.'),
                  ...visibleCrimes.map((row) => _crimeCard(context, Map<String, dynamic>.from(row as Map))),
                ],
                const SizedBox(height: 12),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.source_outlined),
                  title: Text('Sources & data details'),
                  subtitle: Text('OpenCity.in · Bengaluru Traffic Police · Bengaluru City Police · refresh status and limitations'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );

  Widget _accidentCard(BuildContext context, Map<String, dynamic> row) {
    final count = row['totalCases'];
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.car_crash_outlined),
        title: Text('${row['station'] ?? 'Station unavailable'} · ${count ?? '—'} crashes'),
        subtitle: Text((row['concentration'] ?? 'classification unavailable').toString().replaceAll('_', ' ')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _detail('Fatal crashes', row['fatalCases']),
          _detail('People killed', row['peopleKilled']),
          _detail('Non-fatal crashes', row['nonFatalCases']),
          _detail('People injured', row['peopleInjured']),
          _detail('Zone / subdivision', [row['zone'], row['subdivision']].where((v) => v != null && v.toString().isNotEmpty).join(' / ')),
          const Text('Precision: police station aggregate · 2023. No incident-level location or time is available.'),
        ],
      ),
    );
  }

  Widget _crimeCard(BuildContext context, Map<String, dynamic> row) => Card(
        child: ExpansionTile(
          leading: const Icon(Icons.policy_outlined),
          title: Text((row['sourceCategory'] ?? 'Crime category').toString()),
          subtitle: Text('2023 reported: ${row['reported2023'] ?? '—'} · city aggregate'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            _detail('2021 reported / detected', '${row['reported2021'] ?? '—'} / ${row['detected2021'] ?? '—'}'),
            _detail('2022 reported / detected', '${row['reported2022'] ?? '—'} / ${row['detected2022'] ?? '—'}'),
            _detail('2023 reported / detected', '${row['reported2023'] ?? '—'} / ${row['detected2023'] ?? '—'}'),
            const Text('Precision: Bengaluru city aggregate. Category counts do not identify where or when an incident occurred.'),
          ],
        ),
      );

  Widget _detail(String label, Object? value) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        trailing: Text(value == null || value.toString().isEmpty ? 'Unavailable' : value.toString()),
      );
}

class _EmptyDataCard extends StatelessWidget {
  final String message;
  const _EmptyDataCard({required this.message});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ]),
        ),
      );
}
