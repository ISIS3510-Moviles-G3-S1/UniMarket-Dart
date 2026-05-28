import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/trade_proposal.dart';
import '../models/app_user.dart';
import '../view_models/trade_proposals_inbox_view_model.dart';
import '../view_models/session_view_model.dart';
import 'my_trade_proposals_screen.dart';
import 'trade_proposal_detail_screen.dart';

class TradeProposalsInboxScreen extends StatefulWidget {
  const TradeProposalsInboxScreen({super.key});

  @override
  State<TradeProposalsInboxScreen> createState() => _TradeProposalsInboxScreenState();
}

class _TradeProposalsInboxScreenState extends State<TradeProposalsInboxScreen> {
  int _selectedSegment = 0; // 0 for Received, 1 for Sent

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trade Proposals', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Segmented controller Received / Sent
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedSegment = 0;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedSegment == 0 ? colorScheme.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Received',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _selectedSegment == 0 ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedSegment = 1;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedSegment == 1 ? colorScheme.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Sent',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _selectedSegment == 1 ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _selectedSegment == 0
                  ? const _ReceivedProposalsView()
                  : const MyTradeProposalsScreen(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceivedProposalsView extends StatelessWidget {
  const _ReceivedProposalsView();

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionViewModel>(context, listen: false);
    final currentUserId = session.currentUser?.uid ?? '';

    return ChangeNotifierProvider(
      create: (_) => TradeProposalsInboxViewModel(userId: currentUserId),
      child: Consumer<TradeProposalsInboxViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (vm.proposals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'No trade proposals received',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Incoming requests to barter with you will appear here.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vm.proposals.length,
            itemBuilder: (context, index) {
              final proposal = vm.proposals[index];
              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    // Navigate to detail screen
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TradeProposalDetailScreen(proposal: proposal),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FutureBuilder<AppUser?>(
                      future: vm.getCounterpartyProfile(proposal.fromUserID),
                      builder: (context, snapshot) {
                        final sender = snapshot.data;
                        final senderName = sender?.displayName ?? 'Loading name...';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Proposal from \$senderName',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                                _buildStatusPill(proposal.status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Desired Listing ID: \${proposal.desiredListingID}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              'Offered Listing ID: \${proposal.offeredListingID}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                            if (proposal.message != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '"\${proposal.message}"',
                                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              'Sent: ${proposal.createdAt.toLocal().toString().substring(0, 16)}',
                              style: TextStyle(color: Colors.grey[500], fontSize: 11),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusPill(TradeProposalStatus status) {
    Color color = Colors.grey;
    String txt = status.name.toUpperCase();

    switch (status) {
      case TradeProposalStatus.pending:
        color = Colors.orange;
        break;
      case TradeProposalStatus.accepted:
        color = Colors.green;
        break;
      case TradeProposalStatus.declined:
        color = Colors.red;
        break;
      case TradeProposalStatus.withdrawn:
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        txt,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }
}