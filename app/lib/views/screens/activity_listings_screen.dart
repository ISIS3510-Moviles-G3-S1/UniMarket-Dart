import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_theme.dart';
import '../../core/price_formatter.dart';
import '../../view_models/profile_view_model.dart';
import '../incoming_donation_requests_screen.dart';
import '../my_donations_screen.dart';
import '../trade_proposals_inbox_screen.dart';

class ActivityListingsScreen extends StatelessWidget {
  const ActivityListingsScreen({super.key});

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete clothing listing?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final mutedText =
        isDark ? colorScheme.onSurface.withValues(alpha: 0.72) : AppTheme.mutedForeground;
    return Scaffold(
      backgroundColor:
          isDark ? Theme.of(context).scaffoldBackgroundColor : AppTheme.background,
      body: SafeArea(
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                color: AppTheme.deepGreen,
                child: Text(
                  'Activity & Listings',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: colorScheme.onPrimary,
                          ) ??
                      TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimary,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              TabBar(
                labelColor: isDark ? colorScheme.primary : AppTheme.deepGreen,
                unselectedLabelColor: mutedText,
                indicatorColor: isDark ? colorScheme.primary : AppTheme.deepGreen,
                tabs: const [
                  Tab(text: 'Activity Feed'),
                  Tab(text: 'My Listings'),
                ],
              ),
              Expanded(
                child: Consumer<ProfileViewModel>(
                  builder: (context, vm, _) => TabBarView(
                    children: [
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Quick actions section
                          Text(
                            'Barter & Donations',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppTheme.deepGreen,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isDark ? colorScheme.outline : AppTheme.muted,
                              ),
                            ),
                            child: Column(
                              children: [
                                ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.deepGreen.withValues(alpha: 0.1),
                                    child: const Icon(Icons.volunteer_activism, color: AppTheme.deepGreen),
                                  ),
                                  title: const Text(
                                    'Donation Claims Inbox',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: const Text('Manage claims for items you donated'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const IncomingDonationRequestsScreen(),
                                      ),
                                    );
                                  },
                                ),
                                Divider(height: 1, color: isDark ? colorScheme.outline : AppTheme.muted),
                                ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.sage.withValues(alpha: 0.1),
                                    child: const Icon(Icons.card_giftcard, color: AppTheme.sage),
                                  ),
                                  title: const Text(
                                    'My Donations',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: const Text('Track items you have given or claimed'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const MyDonationsScreen(),
                                      ),
                                    );
                                  },
                                ),
                                Divider(height: 1, color: isDark ? colorScheme.outline : AppTheme.muted),
                                ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.accent.withValues(alpha: 0.1),
                                    child: const Icon(Icons.sync_alt_rounded, color: AppTheme.accent),
                                  ),
                                  title: const Text(
                                    'Trade Proposals Inbox',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: const Text('Manage incoming and outgoing barter offers'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const TradeProposalsInboxScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Activity Feed',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppTheme.deepGreen,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (vm.activityFeed.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: Text(
                                  'No recent activity',
                                  style: TextStyle(color: mutedText),
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: vm.activityFeed.length,
                              itemBuilder: (context, i) {
                                final a = vm.activityFeed[i];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: Text(
                                      a.icon,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                    title: Text(
                                      a.text,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(
                                      a.time,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: mutedText,
                                      ),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isDark
                                                ? AppTheme.sage.withValues(alpha: 0.28)
                                                : AppTheme.sage.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color:
                                              isDark
                                                  ? AppTheme.sage.withValues(alpha: 0.48)
                                                  : AppTheme.sage.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        '+${a.xp} XP',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              isDark
                                                  ? Colors.white.withValues(alpha: 0.92)
                                                  : AppTheme.sageDark,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: vm.listings.length + 1,
                        itemBuilder: (context, i) {
                          if (i == vm.listings.length) {
                            return GestureDetector(
                              onTap: () => context.go('/sell'),
                              child: Card(
                                child: Container(
                                  height: 160,
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.add_rounded,
                                        size: 40,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Add New Listing',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: mutedText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          final listing = vm.listings[i];
                          final statusLabel = listing.isSold ? 'Sold' : 'Active';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: 120,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (listing.hasPrimaryImage)
                                        CachedNetworkImage(
                                          imageUrl: listing.primaryImageUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => const Icon(Icons.image_rounded),
                                        )
                                      else
                                        const Center(child: Icon(Icons.image_rounded)),
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: listing.isSold ? AppTheme.muted : AppTheme.sage,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            statusLabel,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: listing.isSold
                                                  ? AppTheme.mutedForeground
                                                  : AppTheme.sageDark,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        listing.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        PriceFormatter.formatCop(listing.price),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.accent,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () =>
                                                  context.push('/item/${listing.id}'),
                                              icon: const Icon(
                                                Icons.edit_rounded,
                                                size: 14,
                                              ),
                                              label: const Text('Edit'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    AppTheme.deepGreen,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            onPressed: () async {
                                              final confirmed = await _confirmDelete(context);
                                              if (!confirmed || !context.mounted) return;

                                              final queuedOffline = await vm.deleteListing(listing.id);
                                              if (!context.mounted) return;

                                              final message = queuedOffline
                                                  ? 'Your clothing will be deleted when internet connection is restored.'
                                                  : 'Clothing deleted successfully.';
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text(message)),
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: AppTheme.destructive,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
