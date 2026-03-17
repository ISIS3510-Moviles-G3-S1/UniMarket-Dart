import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_theme.dart';
import '../../view_models/browse_view_model.dart';
import '../../models/listing.dart';
import '../widgets/filter_sheet.dart';

class BrowseScreen extends StatelessWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mutedText = colorScheme.onSurface.withValues(alpha: 0.72);
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            color: AppTheme.deepGreen,
            child: Text(
              'Browse',
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
          Expanded(
            child: SafeArea(
              top: false,
              child: Consumer<BrowseViewModel>(
                builder: (context, vm, _) {
                  final items = vm.filteredAndSorted;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 22,
                              color: mutedText,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                onChanged: (v) => vm.search = v,
                                decoration: InputDecoration(
                                  hintText: 'Search items...',
                                  filled: true,
                                  fillColor: colorScheme.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(999),
                                    borderSide: BorderSide(
                                      color: colorScheme.outline.withValues(alpha: 0.65),
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => vm.aiSearch = !vm.aiSearch,
                              style: IconButton.styleFrom(
                                backgroundColor: colorScheme.surface,
                                foregroundColor: colorScheme.primary,
                                side: BorderSide(
                                  color: colorScheme.outline.withValues(alpha: 0.65),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              icon: const Icon(Icons.camera_alt_rounded),
                            ),
                            IconButton(
                              onPressed: () => vm.showFilters = true,
                              style: IconButton.styleFrom(
                                backgroundColor: colorScheme.surface,
                                foregroundColor: colorScheme.primary,
                                side: BorderSide(
                                  color: colorScheme.outline.withValues(alpha: 0.65),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              icon: const Icon(Icons.tune_rounded),
                            ),
                          ],
                        ),
                      ),
                      if (vm.aiSearch)
                        Container(
                          margin: const EdgeInsets.only(left: 12, right: 12, top: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.accent.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 16, color: colorScheme.onPrimary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Upload a photo to find similar items',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {},
                                child: Text(
                                  'Upload',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: Stack(
                          children: [
                            ListView(
                              padding: const EdgeInsets.all(12),
                              children: [
                                Text(
                                  '${items.length} items',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: mutedText,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (items.isEmpty)
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 48),
                                      child: Column(
                                        children: [
                                          const Text(
                                            '🔍',
                                            style: TextStyle(fontSize: 48),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'No items found',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Try different filters',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: mutedText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          childAspectRatio: 0.72,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                        ),
                                    itemCount: items.length,
                                    itemBuilder: (context, index) =>
                                        _ListingCard(
                                          listing: items[index],
                                          vm: vm,
                                        ),
                                  ),
                              ],
                            ),
                            if (vm.showFilters) FilterSheet(vm: vm),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final Listing listing;
  final BrowseViewModel vm;

  const _ListingCard({required this.listing, required this.vm});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mutedText = colorScheme.onSurface.withValues(alpha: 0.70);
    return GestureDetector(
      onTap: () => context.push('/item/${listing.id}'),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: listing.image,
                    fit: BoxFit.cover,
                    placeholder:
                        (_, __) => Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    errorWidget:
                        (_, __, ___) =>
                            const Icon(Icons.image_not_supported, size: 40),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => vm.toggleSave(listing.id),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: colorScheme.surface.withValues(alpha: 0.92),
                        child: Icon(
                          vm.isSaved(listing.id)
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 18,
                          color:
                              vm.isSaved(listing.id)
                                  ? Colors.red
                                  : mutedText,
                        ),
                      ),
                    ),
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
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colorScheme.outline),
                      ),
                      child: Text(
                        listing.condition,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${listing.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.sage,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 12,
                            color: AppTheme.mustard,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${listing.rating}',
                            style: TextStyle(
                              fontSize: 10,
                              color: mutedText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    listing.seller,
                    style: TextStyle(
                      fontSize: 10,
                      color: mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
