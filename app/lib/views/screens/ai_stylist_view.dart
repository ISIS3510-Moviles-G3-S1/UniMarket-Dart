import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/ai_outfit_analysis.dart';
import '../../models/listing.dart';
import '../../services/outfit_sync_service.dart';
import '../../view_models/browse_view_model.dart';
import '../../view_models/ai_stylist_view_model.dart';

class AIStylistView extends StatelessWidget {
  const AIStylistView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create:
          (_) => AIStylistViewModel(
            syncService: context.read<OutfitSyncService>(),
          ),
      child: const _AIStylistScaffold(),
    );
  }
}

class _AIStylistScaffold extends StatefulWidget {
  const _AIStylistScaffold();

  @override
  State<_AIStylistScaffold> createState() => _AIStylistScaffoldState();
}

class _AIStylistScaffoldState extends State<_AIStylistScaffold> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AIStylistViewModel>().onViewOpened(
        sourceScreen: 'profile_screen',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Outfit Stylist'),
        actions: [
          IconButton(
            onPressed:
                () => context.read<AIStylistViewModel>().clearSelection(),
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'Clear selection',
          ),
        ],
      ),
      body: Consumer<AIStylistViewModel>(
        builder: (context, vm, _) {
          final analysis = vm.currentAnalysis;
          return RefreshIndicator(
            onRefresh: vm.loadHistory,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _HeroCard(
                      isDark: isDark,
                      colorScheme: colorScheme,
                      vm: vm,
                    ),
                  ),
                ),
                if (vm.errorMessage != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _MessageBanner(
                        icon: Icons.error_outline_rounded,
                        color: Colors.red.shade700,
                        message: vm.errorMessage!,
                      ),
                    ),
                  ),
                if (vm.statusMessage != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _MessageBanner(
                        icon:
                            vm.isSyncing
                                ? Icons.sync_rounded
                                : Icons.info_outline_rounded,
                        color:
                            vm.isSyncing ? AppTheme.accent : AppTheme.sageDark,
                        message: vm.statusMessage!,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _ImagePickerSection(vm: vm),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _SelectedImagesSection(vm: vm),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _AnalyzeButton(vm: vm),
                  ),
                ),
                if (vm.isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                if (analysis != null && !vm.isLoading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: _AnalysisSection(vm: vm, analysis: analysis),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Selector<AIStylistViewModel, List<Listing>>(
                      selector: (_, vm) => vm.recommendedListings,
                      builder: (context, listings, _) => _MarketplaceSection(
                        vm: vm,
                        listings: listings,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Consumer<AIStylistViewModel>(
                      builder: (context, vm, _) => _HistorySection(vm: vm),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.isDark,
    required this.colorScheme,
    required this.vm,
  });

  final bool isDark;
  final ColorScheme colorScheme;
  final AIStylistViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isDark
                  ? [colorScheme.surfaceContainerHighest, colorScheme.surface]
                  : [const Color(0xFFF6F8F6), const Color(0xFFE8F0E9)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.sage.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.sage.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppTheme.sageDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Outfit Stylist',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Upload 1 to 3 clothing images for outfit-only analysis, styling tips, and matching suggestions.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatusPill(
                label: vm.isSyncing ? 'Syncing' : 'Ready',
                icon:
                    vm.isSyncing
                        ? Icons.sync_rounded
                        : Icons.check_circle_rounded,
              ),
              const SizedBox(width: 8),
              if (vm.selectedImages.isNotEmpty)
                _StatusPill(
                  label: '${vm.selectedImages.length}/3 selected',
                  icon: Icons.photo_library_rounded,
                ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go('/profile'),
                child: const Text('Back to profile'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImagePickerSection extends StatelessWidget {
  const _ImagePickerSection({required this.vm});

  final AIStylistViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Image picker',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose up to three clothing photos from your gallery. These are used for styling analysis only.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: vm.isLoading ? null : vm.pickImages,
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text('Pick Images'),
            ),
            if (vm.selectedImages.length == 3) ...[
              const SizedBox(height: 8),
              Text(
                'Maximum of 3 images reached.',
                style: TextStyle(
                  color: AppTheme.sageDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SelectedImagesSection extends StatelessWidget {
  const _SelectedImagesSection({required this.vm});

  final AIStylistViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected images',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (vm.selectedImages.isEmpty)
              Text(
                'No clothing photos selected yet.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var index = 0; index < vm.selectedImages.length; index++)
                    _PreviewCard(
                      image: vm.selectedImages[index],
                      onRemove: () => vm.removeImageAt(index),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.image, required this.onRemove});

  final XFile image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                _buildPreviewImage(image),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black54,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            image.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

Widget _buildPreviewImage(XFile image) {
  return FutureBuilder<Uint8List>(
    future: image.readAsBytes(),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done ||
          !snapshot.hasData) {
        return Container(
          width: 110,
          height: 110,
          color: Colors.grey.shade300,
          child: const Center(child: CircularProgressIndicator()),
        );
      }

      return Image.memory(
        snapshot.data!,
        width: 110,
        height: 110,
        fit: BoxFit.cover,
      );
    },
  );
}

class _AnalyzeButton extends StatelessWidget {
  const _AnalyzeButton({required this.vm});

  final AIStylistViewModel vm;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed:
            vm.isLoading || !vm.canAnalyze ? null : vm.analyzeSelectedImages,
        icon:
            vm.isLoading
                ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                : const Icon(Icons.auto_fix_high_rounded),
        label: const Text('Analyze Outfit'),
      ),
    );
  }
}

class _AnalysisSection extends StatelessWidget {
  const _AnalysisSection({required this.vm, required this.analysis});

  final AIStylistViewModel vm;
  final AIOutfitAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI result',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        _ResultCard(
          title: 'Detected categories',
          icon: Icons.checkroom_rounded,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                analysis.categories.map((value) => _Chip(text: value)).toList(),
          ),
        ),
        _ResultCard(
          title: 'Dominant colors',
          icon: Icons.palette_rounded,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                analysis.dominantColors
                    .map((value) => _Chip(text: value))
                    .toList(),
          ),
        ),
        _ResultCard(
          title: 'Style',
          icon: Icons.style_rounded,
          child: Text(analysis.style.isEmpty ? 'Not detected' : analysis.style),
        ),
        _ResultCard(
          title: 'Aesthetic',
          icon: Icons.auto_awesome_rounded,
          child: Text(
            analysis.aesthetic.isEmpty ? 'Not detected' : analysis.aesthetic,
          ),
        ),
        _ResultCard(
          title: 'Outfit advice',
          icon: Icons.tips_and_updates_rounded,
          child: Text(analysis.outfitAdvice),
        ),
        _ResultCard(
          title: 'Missing item suggestions',
          icon: Icons.add_circle_outline_rounded,
          child:
              analysis.missingItems.isEmpty
                  ? const Text('No obvious gaps detected.')
                  : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        analysis.missingItems
                            .map((value) => _Chip(text: value))
                            .toList(),
                  ),
        ),
        _ResultCard(
          title: 'Marketplace tags',
          icon: Icons.sell_rounded,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                analysis.marketplaceTags
                    .map((value) => _Chip(text: value))
                    .toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: vm.isSaving ? null : vm.saveCurrentAnalysis,
                icon:
                    vm.isSaving
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.bookmark_add_rounded),
                label: const Text('Save Outfit'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: vm.clearSelection,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Start Over'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MarketplaceSection extends StatelessWidget {
  const _MarketplaceSection({required this.vm, required this.listings});

  final AIStylistViewModel vm;
  final List<Listing> listings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommended from UniMarket',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (listings.isEmpty)
              Text(
                'No matching listings yet. Try another outfit or save the analysis for later.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              Consumer<BrowseViewModel>(
                builder:
                    (context, browseVm, _) => SizedBox(
                      height: 220,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          final item = listings[index];
                          final isSaved = browseVm.isSaved(item.id);
                          return _ListingCard(
                            item: item,
                            isSaved: isSaved,
                            onTap: () {
                              vm.logRecommendationClicked(item);
                              context.go('/item/${item.id}');
                            },
                            onToggleSave: () async {
                              final wasSaved = browseVm.isSaved(item.id);
                              await browseVm.toggleSave(item.id);
                              final isNowSaved = browseVm.isSaved(item.id);
                              if (!wasSaved && isNowSaved) {
                                vm.logRecommendationSaved(item);
                              }
                            },
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemCount: listings.length,
                      ),
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.item,
    required this.isSaved,
    required this.onTap,
    required this.onToggleSave,
  });

  final Listing item;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onToggleSave;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.primaryImageUrl.trim();

    return SizedBox(
      width: 150,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child:
                    imageUrl.isEmpty
                        ? Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image_rounded),
                        )
                        : imageUrl.startsWith('file://') ||
                            imageUrl.startsWith('/')
                        ? Image.file(
                          File(imageUrl.replaceFirst('file://', '')),
                          fit: BoxFit.cover,
                        )
                        : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder:
                              (_, __) => Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                          errorWidget:
                              (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.image_rounded),
                              ),
                        ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.tags.take(2).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: isSaved ? 'Saved' : 'Save from AI stylist',
                        icon: Icon(
                          isSaved
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                        ),
                        color:
                            isSaved
                                ? Colors.redAccent
                                : Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                        onPressed: onToggleSave,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.vm});

  final AIStylistViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved outfit history',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (vm.history.isEmpty)
              Text(
                'Previous outfit analyses will appear here after you save or analyze one.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              Column(
                children: [
                  for (final analysis in vm.history)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => vm.openHistoryAnalysis(analysis),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      analysis.categories.isNotEmpty
                                          ? analysis.categories.join(', ')
                                          : 'Outfit analysis',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _StatusPill(
                                    label: analysis.syncStatus.name,
                                    icon:
                                        analysis.syncStatus ==
                                                AIOutfitSyncStatus.synced
                                            ? Icons.check_circle_rounded
                                            : analysis.syncStatus ==
                                                AIOutfitSyncStatus.pending
                                            ? Icons.schedule_rounded
                                            : Icons.error_outline_rounded,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                analysis.outfitAdvice,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.sageDark),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.sage.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.sage.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.sage.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.sageDark),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
