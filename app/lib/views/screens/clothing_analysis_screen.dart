import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/analysis_result.dart';
import '../../models/clothing_tag.dart';
import '../../view_models/clothing_analysis_view_model.dart';
import '../widgets/loading_analysis_view.dart';
import '../widgets/tag_chip_widget.dart';

class ClothingAnalysisScreen extends StatelessWidget {
  const ClothingAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ClothingAnalysisViewModel(),
      child: const _ClothingAnalysisView(),
    );
  }
}

class _ClothingAnalysisView extends StatelessWidget {
  const _ClothingAnalysisView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clothing Analysis'),
      ),
      body: Consumer<ClothingAnalysisViewModel>(
        builder: (context, vm, _) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: switch (vm.status) {
              ClothingAnalysisStatus.initial => _InitialState(onTakePhoto: vm.takePhoto, onChooseGallery: vm.chooseFromGallery),
              ClothingAnalysisStatus.loading => const LoadingAnalysisView(),
              ClothingAnalysisStatus.results => _ResultsState(provider: vm),
              ClothingAnalysisStatus.error => _ErrorState(provider: vm),
            },
          );
        },
      ),
    );
  }
}

class _InitialState extends StatelessWidget {
  final VoidCallback onTakePhoto;
  final VoidCallback onChooseGallery;

  const _InitialState({
    required this.onTakePhoto,
    required this.onChooseGallery,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.checkroom_rounded, size: 72, color: scheme.primary),
              const SizedBox(height: 20),
              Text(
                'Analyze a clothing item',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Take a photo or pick one from your gallery to generate editable tags.',
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onTakePhoto,
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('Take Photo'),
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onChooseGallery,
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Choose from Gallery'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultsState extends StatelessWidget {
  final ClothingAnalysisViewModel provider;

  const _ResultsState({required this.provider});

  @override
  Widget build(BuildContext context) {
    final result = provider.result;
    if (result == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryCard(result: result),
                  const SizedBox(height: 20),
                  _TagGroupSection(
                    title: 'Item Type',
                    tags: provider.tagsFor(TagCategory.category),
                    onRemove: provider.removeTag,
                  ),
                  _TagGroupSection(
                    title: 'Colors',
                    tags: provider.tagsFor(TagCategory.color),
                    onRemove: provider.removeTag,
                  ),
                  _TagGroupSection(
                    title: 'Style',
                    tags: provider.tagsFor(TagCategory.style),
                    onRemove: provider.removeTag,
                  ),
                  _TagGroupSection(
                    title: 'Pattern',
                    tags: provider.tagsFor(TagCategory.pattern),
                    onRemove: provider.removeTag,
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: provider.analyzeAnotherItem,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Analyze Another Item'),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop<Map<String, List<String>>>(context, provider.buildListingTags());
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Create Listing'),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final AnalysisResult result;

  const _SummaryCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(result.category, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Confidence ${(result.confidence * 100).round()}% · ${result.processingTimeMs} ms'),
          const SizedBox(height: 6),
          Text('Colors: ${result.colors.join(', ')}'),
          if (result.style != null) Text('Style: ${result.style}'),
          if (result.pattern != null) Text('Pattern: ${result.pattern}'),
        ],
      ),
    );
  }
}

class _TagGroupSection extends StatelessWidget {
  final String title;
  final List<ClothingTag> tags;
  final ValueChanged<String> onRemove;

  const _TagGroupSection({
    required this.title,
    required this.tags,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .map(
                  (tag) => TagChipWidget(
                    tag: tag,
                    onRemove: () => onRemove(tag.id),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final ClothingAnalysisViewModel provider;

  const _ErrorState({required this.provider});

  @override
  Widget build(BuildContext context) {
    final error = provider.error;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 72, color: scheme.error),
              const SizedBox(height: 16),
              Text(error?.userMessage ?? 'Something went wrong.', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                error?.recoverySuggestion ?? 'Please try again with a different image.',
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: provider.retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: provider.startOver,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Start Over'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}