import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/trade_proposal.dart';
import '../models/trade_item_snapshot.dart';
import '../view_models/trade_proposal_detail_view_model.dart';
import '../view_models/session_view_model.dart';

class TradeProposalDetailScreen extends StatelessWidget {
  final TradeProposal proposal;

  const TradeProposalDetailScreen({
    super.key,
    required this.proposal,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TradeProposalDetailViewModel(proposal: proposal),
      child: const _TradeProposalDetailContent(),
    );
  }
}

class _TradeProposalDetailContent extends StatelessWidget {
  const _TradeProposalDetailContent();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trade Details', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      body: Consumer<TradeProposalDetailViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final desired = vm.desiredSnapshot;
          final offered = vm.offeredSnapshot;
          final isUnsynced = vm.proposal.isSyncedDecision == 0;

          return Column(
            children: [
              if (isUnsynced)
                Container(
                  color: Colors.orange.withOpacity(0.12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.sync_problem, color: Colors.orange, size: 20),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Offline Decision: pending sync server upload once back online.',
                          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status and match overview
                      _buildHeaderCard(context, vm.proposal),
                      const SizedBox(height: 16),

                      if (desired != null && offered != null) ...[
                        const Text(
                          'TRADE ITEMS',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildItemCard(context, 'DESIRED ITEM', desired)),
                            const SizedBox(width: 8),
                            const Icon(Icons.swap_horiz_rounded, size: 24, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(child: _buildItemCard(context, 'OFFERED ITEM', offered)),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (vm.proposal.message != null) ...[
                        const Text(
                          'PROPOSER MESSAGE',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100]?.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(
                            '"${vm.proposal.message}"',
                            style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // QR meetup instructions / flow
                      if (vm.proposal.status == TradeProposalStatus.accepted) ...[
                        _buildMeetupSection(context, vm.proposal),
                        const SizedBox(height: 24),
                      ],

                      // Actions
                      if (vm.proposal.status == TradeProposalStatus.pending)
                        _buildActionRow(context, vm)
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, TradeProposal proposal) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Proposal Status', style: TextStyle(fontWeight: FontWeight.w600)),
                _buildStatusPill(proposal.status),
              ],
            ),
            const Divider(height: 24),
            Text(
              'Proposed on ${proposal.createdAt.toLocal().toString().substring(0, 16)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, String title, TradeItemSnapshot snapshot) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              snapshot.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '\$${snapshot.price.toStringAsFixed(0)}',
              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Role: ${snapshot.role.toUpperCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetupSection(BuildContext context, TradeProposal proposal) {
    final session = Provider.of<SessionViewModel>(context, listen: false);
    final currentUserId = session.currentUser?.uid ?? '';
    final isProposer = proposal.fromUserID == currentUserId;

    return Card(
      color: Colors.teal.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Colors.teal, width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.qr_code_2, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  'Meetup QR Code',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Both items are now locked for trading! Meet up in person to finalize the deal. One user scans, the other presents the QR code.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            if (!isProposer) ...[
              ElevatedButton.icon(
                onPressed: () {
                  context.push('/meetup/seller/${proposal.desiredListingID}?sellerId=${proposal.toUserID}');
                },
                icon: const Icon(Icons.qr_code_rounded),
                label: const Text('Show Meetup QR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: () {
                  context.push('/meetup/scan');
                },
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan Counterparty QR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, TradeProposalDetailViewModel vm) {
    final session = Provider.of<SessionViewModel>(context, listen: false);
    final currentUserId = session.currentUser?.uid ?? '';
    final isReceiver = vm.proposal.toUserID == currentUserId;

    if (!isReceiver) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Waiting for the other party to approve or decline this offer.',
          textAlign: TextAlign.center,
          style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              final success = await vm.resolveProposal(TradeProposalStatus.declined);
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Trade proposal declined.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to decline proposal.')),
                  );
                }
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('DECLINE'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              final success = await vm.resolveProposal(TradeProposalStatus.accepted);
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Trade proposal approved! Meetup code generated.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to approve proposal.')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('APPROVE'),
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        txt,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}