import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/listing.dart';
import '../view_models/donation_request_view_model.dart';
import '../view_models/session_view_model.dart';

class DonationRequestSheet extends StatefulWidget {
  final Listing listing;

  const DonationRequestSheet({
    super.key,
    required this.listing,
  });

  static void show(BuildContext context, Listing listing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DonationRequestSheet(listing: listing),
    );
  }

  @override
  State<DonationRequestSheet> createState() => _DonationRequestSheetState();
}

class _DonationRequestSheetState extends State<DonationRequestSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionVM = Provider.of<SessionViewModel>(context, listen: false);
    final requesterId = sessionVM.currentUser?.uid ?? '';
    final colorScheme = Theme.of(context).colorScheme;

    return ChangeNotifierProvider(
      create: (_) {
        final vm = DonationRequestViewModel();
        vm.loadDraft(requesterId, widget.listing.id).then((_) {
          _controller.text = vm.messageText;
        });
        return vm;
      },
      child: Consumer<DonationRequestViewModel>(
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
                    'Claim Donation',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You are requesting: ${widget.listing.title}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Include an optional message to the donor...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
                    ),
                    onChanged: (text) {
                      vm.updateDraft(requesterId, widget.listing.id, text);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    vm.isOffline
                        ? '⚠️ You are currently offline. Your claim will be saved and synced automatically once you are back online.'
                        : 'Your claim will be submitted directly to the owner.',
                    style: TextStyle(
                      color: vm.isOffline ? Colors.orange[800] : Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: vm.isSubmitting
                        ? null
                        : () async {
                            final success = await vm.submitClaim(
                              listing: widget.listing,
                              requesterId: requesterId,
                            );
                            if (mounted) {
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(vm.isOffline
                                        ? 'Draft saved! Will sync when connection is restored.'
                                        : 'Claim request submitted successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                context.pop(); // Close sheet
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to submit claim. Please try again.'),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: vm.isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text(
                            'Request Item',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}