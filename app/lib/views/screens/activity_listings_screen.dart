import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_theme.dart';
import '../../view_models/profile_view_model.dart';

class ActivityListingsScreen extends StatelessWidget {
  const ActivityListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
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
                            color: Colors.white,
                          ) ??
                      const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              TabBar(
                labelColor: AppTheme.deepGreen,
                unselectedLabelColor: AppTheme.mutedForeground,
                indicatorColor: AppTheme.deepGreen,
                tabs: const [
                  Tab(text: 'Activity Feed'),
                  Tab(text: 'My Listings'),
                ],
              ),
              Expanded(
                child: Consumer<ProfileViewModel>(
                  builder: (context, vm, _) => TabBarView(
                    children: [
                      ListView.builder(
                        padding: const EdgeInsets.all(16),
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
                                  color: AppTheme.mutedForeground,
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.sage.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.sage.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  '+${a.xp} XP',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.sageDark,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
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
                                        color: AppTheme.mutedForeground,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Add New Listing',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.mutedForeground,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          final listing = vm.listings[i];
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
                                      CachedNetworkImage(
                                        imageUrl: listing.image,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) =>
                                            const Icon(Icons.image_rounded),
                                      ),
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: listing.status == 'Active'
                                                ? AppTheme.sage
                                                : AppTheme.muted,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            listing.status,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: listing.status == 'Active'
                                                  ? AppTheme.sageDark
                                                  : AppTheme.mutedForeground,
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
                                        listing.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '\$${listing.price.toStringAsFixed(0)}',
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
                                            onPressed: () =>
                                                vm.deleteListing(listing.id),
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
