import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../view_models/donations_browse_view_model.dart';
import '../models/listing.dart';
import '../core/app_theme.dart';

class DonationsBrowseScreen extends StatelessWidget {
  const DonationsBrowseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DonationsBrowseViewModel(),
      child: const _DonationsBrowseContent(),
    );
  }
}

class _DonationsBrowseContent extends StatelessWidget {
  const _DonationsBrowseContent();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final mutedText = isDark ? colorScheme.onSurface.withOpacity(0.72) : AppTheme.mutedForeground;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: const Text('Donations', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Consumer<DonationsBrowseViewModel>(
          builder: (context, vm, _) {
            // Calculate elapsed time from lastRefreshed
            String refreshedText = '';
            if (vm.lastRefreshed != null) {
              final diff = DateTime.now().difference(vm.lastRefreshed!);
              if (diff.inSeconds < 60) {
                refreshedText = 'Last refreshed just now';
              } else if (diff.inMinutes < 60) {
                refreshedText = 'Last refreshed ${diff.inMinutes}m ago';
              } else {
                refreshedText = 'Refreshed at ${vm.lastRefreshed!.hour.toString().padLeft(2, '0')}:${vm.lastRefreshed!.minute.toString().padLeft(2, '0')}';
              }
            } else {
              refreshedText = 'Not refreshed yet';
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (vm.isOffline)
                  Container(
                    color: Colors.red.withOpacity(0.12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off, color: Colors.red, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Offline Mode • $refreshedText',
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (vm.lastRefreshed != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      refreshedText,
                      style: TextStyle(color: mutedText, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),

                // Category filter chips
                Container(
                  height: 48,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _buildFilterChip(context, vm, 'all', 'All Items'),
                      _buildFilterChip(context, vm, 'clothing', 'Clothing'),
                      _buildFilterChip(context, vm, 'shoes', 'Shoes'),
                      _buildFilterChip(context, vm, 'accessories', 'Accessories'),
                      _buildFilterChip(context, vm, 'eco', 'Eco'),
                    ],
                  ),
                ),

                if (vm.errorMessage != null)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Error loading donations:\n${vm.errorMessage}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  )
                else if (vm.isLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (vm.listings.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 16),
                          const Text(
                            'No donations available',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try selecting a different filter.',
                            style: TextStyle(color: mutedText),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => vm.fetchDonations(forceRefresh: true),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => vm.fetchDonations(forceRefresh: true),
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: vm.listings.length,
                        itemBuilder: (context, index) {
                          final item = vm.listings[index];
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            elevation: 2,
                            child: InkWell(
                              onTap: () => context.push('/item/${item.id}'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        if (item.imageURLs.isNotEmpty)
                                          CachedNetworkImage(
                                            imageUrl: item.imageURLs.first,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(color: Colors.grey[200]),
                                            errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                                          )
                                        else
                                          Container(
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.card_giftcard, size: 48, color: Colors.grey),
                                          ),
                                        Positioned(
                                          top: 8,
                                          left: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'FREE',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.conditionTag,
                                          style: TextStyle(color: mutedText, fontSize: 12),
                                        ),
                                        if (item.tags.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: item.tags.take(3).map((tag) => Container(
                                                margin: const EdgeInsets.only(right: 4),
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.primaryContainer,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  tag,
                                                  style: TextStyle(
                                                    color: colorScheme.onPrimaryContainer,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              )).toList(),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, DonationsBrowseViewModel vm, String category, String label) {
    final isSelected = vm.selectedCategory.toLowerCase() == category.toLowerCase();
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          vm.selectCategory(category);
        },
        selectedColor: colorScheme.primary.withOpacity(0.2),
        checkmarkColor: colorScheme.primary,
      ),
    );
  }
}