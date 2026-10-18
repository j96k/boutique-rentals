import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../widgets/common.dart';
import '../widgets/inquiry_widgets.dart';

/// Everyone on a waitlist whose cloth is free for the dates they want — ready to contact.
class WaitlistScreen extends StatefulWidget {
  const WaitlistScreen({super.key});

  @override
  State<WaitlistScreen> createState() => _WaitlistScreenState();
}

class _WaitlistScreenState extends State<WaitlistScreen> {
  late Future<List<Inquiry>> _future = Api.instance.readyInquiries();

  Future<void> _reload() async {
    setState(() => _future = Api.instance.readyInquiries());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ready to contact')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Inquiry>>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) return ListView(children: [ErrorRetry(snap.error.toString(), onRetry: _reload)]);
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final people = snap.data!;
            if (people.isEmpty) {
              return ListView(children: const [
                EmptyState(
                  icon: Icons.check_circle_rounded,
                  title: 'All caught up',
                  subtitle: 'Nobody is waiting for a cloth that is free right now.',
                ),
              ]);
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                const Text(
                  'These clothes are free for the dates these people want. Best offer first — '
                  'contacting someone marks them as "Contacted".',
                ),
                const SizedBox(height: 12),
                ...people.map((i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InquiryCard(inquiry: i, onChanged: _reload, showCloth: true),
                    )),
              ],
            );
          },
        ),
      ),
    );
  }
}
