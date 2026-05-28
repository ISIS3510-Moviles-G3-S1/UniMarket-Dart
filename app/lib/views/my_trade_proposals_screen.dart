import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trade_proposal.dart';
import '../view_models/my_trade_proposals_view_model.dart';
import '../view_models/session_view_model.dart';
import 'trade_proposal_detail_screen.dart';

class MyTradeProposalsScreen extends StatelessWidget {
  const MyTradeProposalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionViewModel>(context, listen: false);
    final currentUserId = session.currentUser?.uid ?? '';

    return ChangeNotifierProvider(
      create: (_) => MyTradeProposalsViewModel(userId: currentUserId),
      child: Consumer<MyTradeProposalsViewModel>(
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
                    'No proposals sent yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Go browse other listings and pick "Propose Trade"!',
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
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    // Navigate to detail view
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TradeProposalDetailScreen(proposal: proposal),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Trade Proposal ID: ${proposal.id.substring(0, 8)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            _buildStatusPill(proposal.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'For Item: ${proposal.desiredListingID}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          'Offered: ${proposal.offeredListingID}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        if (proposal.message != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'My message: "${proposal.message}"',
                            style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'Sent: ${proposal.createdAt.toLocal().toString().substring(0, 16)}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                      ],
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