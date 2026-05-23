import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/donation_request.dart';
import '../models/listing.dart';
import '../view_models/my_donations_view_model.dart';
import '../view_models/session_view_model.dart';

class MyDonationsScreen extends StatelessWidget {
  const MyDonationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionViewModel>(context, listen: false);
    final currentUserId = session.currentUser?.uid ?? '';

    return ChangeNotifierProvider(
      create: (_) => MyDonationsViewModel(requesterId: currentUserId),
      child: const MyDonationsTabs(),
    );
  }
}

class MyDonationsTabs extends StatelessWidget {
  const MyDonationsTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Donations', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: colorScheme.surface,
          elevation: 0,
          bottom: TabBar(
            labelColor: colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: colorScheme.primary,
            tabs: const [
              Tab(text: 'Given', icon: Icon(Icons.volunteer_activism_outlined)),
              Tab(text: 'Claimed', icon: Icon(Icons.card_giftcard_outlined)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _GivenTab(),
            _ClaimedTab(),
          ],
        ),
      ),
    );
  }
}

class _GivenTab extends StatefulWidget {
  const _GivenTab();

  @override
  State<_GivenTab> createState() => _GivenTabState();
}

class _GivenTabState extends State<_GivenTab> {
  List<Listing> _myDonationListings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyDonationListings();
  }

  Future<void> _fetchMyDonationListings() async {
    final session = Provider.of<SessionViewModel>(context, listen: false);
    final currentUserId = session.currentUser?.uid ?? '';

    try {
      final snap = await FirebaseFirestore.instance
          .collection('listings')
          .where('sellerId', isEqualTo: currentUserId)
          .where('kind', isEqualTo: 'donation')
          .get();

      if (mounted) {
        setState(() {
          _myDonationListings = snap.docs.map((doc) => Listing.fromFirestore(doc)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching given donations: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myDonationListings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎁', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'No items donated yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a listing of kind "Donation" to start!',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myDonationListings.length,
      itemBuilder: (context, index) {
        final item = _myDonationListings[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.volunteer_activism),
            ),
            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Status: ${item.status.toUpperCase()}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: item.status == 'active' ? Colors.green.withOpacity(0.12) : Colors.grey.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.status.toUpperCase(),
                style: TextStyle(
                  color: item.status == 'active' ? Colors.green : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ClaimedTab extends StatelessWidget {
  const _ClaimedTab();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<MyDonationsViewModel>(
      builder: (context, vm, _) {
        if (vm.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final unsyncedCount = vm.requests.where((r) => r.isSyncedClaim == 0 || r.isSyncedDecision == 0).length;

        if (vm.requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🛍️', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                const Text(
                  'No donation claims requested',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Browse donation listings and claim some items!',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: vm.requests.length,
                itemBuilder: (context, index) {
                  final request = vm.requests[index];
                  final isUnsynced = request.isSyncedClaim == 0 || request.isSyncedDecision == 0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Listing ID: ${request.donationListingID}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                              if (isUnsynced)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.sync_problem, color: Colors.orange, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'Sending...',
                                        style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                _buildStatusPill(request.status),
                            ],
                          ),
                          if (request.requesterMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'My message: "${request.requesterMessage}"',
                              style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            'Requested: ${request.createdAt.toLocal().toString().substring(0, 16)}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.grey[150]?.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(
                    unsyncedCount > 0 ? Icons.sync_problem : Icons.cloud_done_outlined,
                    color: unsyncedCount > 0 ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    unsyncedCount > 0
                        ? '$unsyncedCount request(s) waiting to sync offline...'
                        : 'All requests successfully synced',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: unsyncedCount > 0 ? Colors.orange[800] : Colors.green[800],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusPill(DonationRequestStatus status) {
    Color color = Colors.grey;
    String txt = status.name.toUpperCase();

    switch (status) {
      case DonationRequestStatus.pending:
        color = Colors.orange;
        break;
      case DonationRequestStatus.approved:
        color = Colors.green;
        break;
      case DonationRequestStatus.declined:
        color = Colors.red;
        break;
      case DonationRequestStatus.withdrawn:
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        txt,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}