import 'package:flutter/material.dart';

import '../models/hex_score.dart';
import '../models/incident.dart';
import '../services/supabase_service.dart';

/// Hex detay paneli: guvenlik skoru + zaman cizelgesi (sonsuz kaydirma).
class IncidentSheet extends StatefulWidget {
  final HexScore hex;
  const IncidentSheet({super.key, required this.hex});

  @override
  State<IncidentSheet> createState() => _IncidentSheetState();
}

class _IncidentSheetState extends State<IncidentSheet> {
  final _service = SupabaseService();
  final _scrollController = ScrollController();
  final List<Incident> _incidents = [];
  int _page = 0;
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scrollController.addListener(() {
      if (_scrollController.position.extentAfter < 200) _loadMore();
    });
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final batch = await _service.incidentsInHex(widget.hex.h3Res9, page: _page);
      setState(() {
        _incidents.addAll(batch);
        _hasMore = batch.length == 20;
        _page++;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (context, _) => Column(children: [
        _buildHeader(),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _incidents.length + (_loading ? 1 : 0),
            itemBuilder: (context, i) {
              if (i >= _incidents.length) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ));
              }
              return _IncidentCard(incident: _incidents[i]);
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
    final score = widget.hex.safetyScore;
    final color = score > 70 ? Colors.green : (score > 40 ? Colors.orange : Colors.red);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: color,
          child: Text('$score', style: const TextStyle(color: Colors.white, fontSize: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Guvenlik Skoru', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Bu ~300 metrelik alanda ${widget.hex.incidentCount} kayitli olay'),
          ]),
        ),
      ]),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  final Incident incident;
  const _IncidentCard({required this.incident});

  @override
  Widget build(BuildContext context) {
    final d = incident.occurredOn;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Chip(
              avatar: Icon(incident.icon, size: 16),
              label: Text(incident.eventTypeLabel),
              visualDensity: VisualDensity.compact,
            ),
            const Spacer(),
            Text('${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}'),
          ]),
          const SizedBox(height: 8),
          Text(incident.summary),
          const SizedBox(height: 8),
          Row(children: [
            if (incident.sourceCount > 1)
              Text(
                '${incident.sourceCount} kaynak tarafindan dogrulandi',
                style: TextStyle(color: Colors.green.shade700, fontSize: 12),
              ),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Habere Git (Kaynak)'),
              // Telif kalkani: tam metin yok, kaynaga trafik gonderilir.
              onPressed: () => _showSources(context),
            ),
          ]),
        ]),
      ),
    );
  }

  void _showSources(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Kaynaklar'),
        children: [
          for (final url in incident.sourceUrls)
            SimpleDialogOption(
              child: Text(url, style: const TextStyle(color: Colors.blue)),
              // V2: url_launcher paketi ile acilacak.
              onPressed: () => Navigator.pop(context),
            ),
        ],
      ),
    );
  }
}
