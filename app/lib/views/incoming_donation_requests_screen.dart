import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/donation_request.dart';
import '../models/app_user.dart';
import '../view_models/incoming_donation_requests_view_model.dart';
import '../view_models/session_view_model.dart';

class IncomingDonationRequestsScreen extends StatelessWidget {
  const IncomingDonationRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionViewModel>(context, listen: false);
    final sellerId = session.currentUser?.uid ?? '';

    return ChangeNotifierProvider(
      create: (_) => IncomingDonationRequestsViewModel(sellerId: sellerId),
      child: const _IncomingDonationsContent(),
    );
  }
}

class _IncomingDonationsContent extends StatelessWidget {
  const _IncomingDonationsContent();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incoming Donation Requests', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      body: Consumer<IncomingDonationRequestsViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (vm.requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('📬', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  const Text(
                    'No requests received yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When users request your donations, they will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // Group by listing ID
          final grouped = <String, List<DonationRequest>>{};
          for (final r in vm.requests) {
            grouped.putIfAbsent(r.donationListingID, () => []).add(r);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: grouped.keys.length,
            itemBuilder: (context, index) {
              final listingId = grouped.keys.elementAt(index);
              final requests = grouped[listingId]!;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  initiallyExpanded: true,
                  title: Text(
                    'Listing ID: $listingId',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${requests.length} claim request(s)'),
                  children: requests.map((req) {
                    return _RequestRowItem(request: req, vm: vm);
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RequestRowItem extends StatelessWidget {
  final DonationRequest request;
  final IncomingDonationRequestsViewModel vm;

  const _RequestRowItem({required this.request, required this.vm});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<AppUser?>(
      future: vm.getRequesterProfile(request.requesterID),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = profile?.displayName ?? 'Loading name...';
        final email = profile?.email ?? 'Loading email...';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primary.withOpacity(0.1),
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            if (request.isSyncedDecision == 0)
                              const Tooltip(
                                message: 'Unsynced pending offline decision',
                                child: Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(Icons.access_time_rounded, color: Colors.orange, size: 18),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          email,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        if (request.requesterMessage != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[200]?.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '"${request.requesterMessage}"',
                              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (request.status == DonationRequestStatus.pending) ...[
                    OutlinedButton(
                      onPressed: () async {
                        final success = await vm.resolveRequest(request.id, DonationRequestStatus.declined);
                        if (context.mounted && !success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to decline request')),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text('Decline'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final success = await vm.resolveRequest(request.id, DonationRequestStatus.approved);
                        if (context.mounted) {
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Request approved! Meetup QR is ready.')),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to approve request')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Approve'),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: request.status == DonationRequestStatus.approved
                            ? Colors.green.withOpacity(0.12)
                            : Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            request.status == DonationRequestStatus.approved
                                ? Icons.check_circle_outline
                                : Icons.cancel_outlined,
                            color: request.status == DonationRequestStatus.approved ? Colors.green : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            request.status == DonationRequestStatus.approved ? 'APPROVED' : 'DECLINED',
                            style: TextStyle(
                              color: request.status == DonationRequestStatus.approved ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]
                ],
              ),
              const Divider(height: 24),
            ],
          ),
        );
      },
    );
  }
}