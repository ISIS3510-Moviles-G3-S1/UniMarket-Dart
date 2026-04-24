import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class SustainabilityLevelInfo {
  const SustainabilityLevelInfo({
    required this.title,
    required this.nextTitle,
    required this.minXP,
    required this.maxXP,
  });

  final String title;
  final String nextTitle;
  final int minXP;
  final int maxXP;
}

class SustainabilityProgressCard extends StatelessWidget {
  const SustainabilityProgressCard({
    super.key,
    required this.xp,
    required this.xpToNext,
    required this.levelInfo,
  });

  final int xp;
  final int xpToNext;
  final SustainabilityLevelInfo levelInfo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final denominator = (levelInfo.maxXP - levelInfo.minXP).toDouble();
    final rawProgress = denominator <= 0 ? 1.0 : (xp - levelInfo.minXP) / denominator;
    final progress = rawProgress.clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current level',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.deepGreen),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        levelInfo.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.deepGreen),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Next level',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.sage),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        levelInfo.nextTitle,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.sage),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        xpToNext <= 0 ? 'MAX' : '$xpToNext XP to go',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              color: AppTheme.sage,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${levelInfo.minXP} XP', style: const TextStyle(fontSize: 11, color: AppTheme.deepGreen)),
                Text('$xp XP', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.sage)),
                Text('${levelInfo.maxXP} XP', style: const TextStyle(fontSize: 11, color: AppTheme.deepGreen)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
