import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/listing.dart';
import '../models/trade_match_score.dart';
import '../view_models/propose_trade_view_model.dart';
import '../view_models/session_view_model.dart';

class ProposeTradeSheet extends StatefulWidget {
  final Listing desiredListing;

  const ProposeTradeSheet({
    super.key,
    required this.desiredListing,
  });

  static void show(BuildContext context, Listing desiredListing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProposeTradeSheet(desiredListing: desiredListing),
    );
  }

  @override
  State<ProposeTradeSheet> createState() => _ProposeTradeSheetState();
}

class _ProposeTradeSheetState extends State<ProposeTradeSheet> {
  late final TextEditingController _messageController;
  bool _loadingMyListings = true;
  List<Listing> _myListings = [];

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _fetchMyActiveListings();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _fetchMyActiveListings() async {
    final session = Provider.of<SessionViewModel>(context, listen: false);
    final currentUserId = session.currentUser?.uid ?? '';

    try {
      final snap = await FirebaseFirestore.instance
          .collection('listings')
          .where('sellerId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'active')
          .get();

      _myListings = snap.docs.map((doc) => Listing.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error loading my listings for trade proposal: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingMyListings = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingMyListings) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final session = Provider.of<SessionViewModel>(context, listen: false);
    final currentUserId = session.currentUser?.uid ?? '';
    final colorScheme = Theme.of(context).colorScheme;

    return ChangeNotifierProvider(
      create: (_) {
        final vm = ProposeTradeViewModel(
          desiredListing: widget.desiredListing,
          currentUserId: currentUserId,
        );
        vm.fetchMyCandidates(_myListings).then((_) {
          vm.loadDraft().then((_) {
            _messageController.text = vm.message;
          });
        });
        return vm;
      },
      child: Consumer<ProposeTradeViewModel>(
        builder: (context, vm, _) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Propose a Trade/Barter',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Trading for: ${widget.desiredListing.title} (${widget.desiredListing.price > 0 ? "\$${widget.desiredListing.price}" : "No Price"})',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Select an item of yours to offer:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  if (vm.myActiveListings.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'You don\'t have any other active listings to offer. Please upload a product first before proposing a trade.',
                        style: TextStyle(color: Colors.amber[900], fontSize: 13),
                      ),
                    )
                  else
                    SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: vm.myActiveListings.length,
                        itemBuilder: (context, index) {
                          final item = vm.myActiveListings[index];
                          final isSelected = vm.selectedOfferedListing?.id == item.id;
                          final score = vm.getScoreFor(item);

                          return GestureDetector(
                            onTap: () => vm.selectOfferedListing(item),
                            child: Container(
                              width: 148,
                              margin: const EdgeInsets.only(right: 12, bottom: 4, top: 4),
                              decoration: BoxDecoration(
                                color: isSelected ? colorScheme.primary.withOpacity(0.08) : Theme.of(context).cardColor,
                                border: Border.all(
                                  color: isSelected ? colorScheme.primary : Colors.grey[300]!,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${item.price.toStringAsFixed(0)}',
                                    style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                  const Spacer(),
                                  if (score != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Match: ${(score.total * 100).toStringAsFixed(0)}%',
                                        style: const TextStyle(
                                          color: Colors.teal,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Overlap: ${(score.tagOverlap * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(color: Colors.grey[500], fontSize: 9),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _messageController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Add an optional message to the seller...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
                    ),
                    onChanged: (text) {
                      vm.saveDraft(text, vm.selectedOfferedListing?.id);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    vm.isOffline
                        ? '⚠️ Offline Mode. Your trade proposal is saved as a draft locally and will submitt automatically once you reconnect.'
                        : 'Your offer is sent securely.',
                    style: TextStyle(
                      color: vm.isOffline ? Colors.orange[800] : Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: vm.isSubmitting || vm.selectedOfferedListing == null
                        ? null
                        : () async {
                            final success = await vm.submitProposal();
                            if (mounted) {
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(vm.isOffline
                                        ? 'Draft saved! Will sync when connection is restored.'
                                        : 'Trade proposal submitted successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                context.pop();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to submit proposal. Please try again.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: vm.isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text(
                            'Submit Offer',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}