import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/sustainability_impact.dart';

/// Flutter equivalent of the Swift SustainabilityImpactCard.
///
/// Displays three stat tiles (water, CO2, waste) and an AI-generated insight
/// from the EcoService (same OpenRouter endpoint used by EcoMessageCard).
class SustainabilityImpactCard extends StatelessWidget {
  const SustainabilityImpactCard({
    super.key,
    required this.impact,
    required this.message,
    required this.isLoading,
  });

  final SustainabilityImpact impact;
  final String message;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(itemsReused: impact.itemsReused),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ImpactStatTile(
                  value: _formatWater(impact.waterLiters),
                  unit: 'L water',
                  label: 'water spared',
                  icon: Icons.water_drop_outlined,
                  tint: Colors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ImpactStatTile(
                  value: _formatCo2(impact.co2Kg),
                  unit: 'kg CO2',
                  label: 'emissions avoided',
                  icon: Icons.eco_outlined,
                  tint: Colors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ImpactStatTile(
                  value: _formatWaste(impact.wasteKg),
                  unit: 'kg',
                  label: 'waste diverted',
                  icon: Icons.recycling_outlined,
                  tint: AppTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _InsightBlock(message: message, isLoading: isLoading),
        ],
      ),
    );
  }

  static String _formatWater(int liters) {
    if (liters >= 1000) return (liters / 1000).toStringAsFixed(1);
    return '$liters';
  }

  static String _formatCo2(double kg) {
    return kg >= 10 ? kg.round().toString() : kg.toStringAsFixed(1);
  }

  static String _formatWaste(double kg) {
    return kg >= 10 ? kg.round().toString() : kg.toStringAsFixed(1);
  }
}

// ── Private sub-widgets ──────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.itemsReused});

  final int itemsReused;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.public_rounded, size: 18, color: AppTheme.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your sustainability impact',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$itemsReused item${itemsReused == 1 ? '' : 's'} given a second life',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurface.withValues(alpha: 0.60),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InsightBlock extends StatelessWidget {
  const _InsightBlock({required this.message, required this.isLoading});

  final String message;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 11, color: AppTheme.accent),
            const SizedBox(width: 6),
            Text(
              'Eco insight',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (isLoading)
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(
                'Reading your numbers...',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.60),
                ),
              ),
            ],
          )
        else
          Text(
            message.isEmpty
                ? 'Sell your first item to unlock a personalized insight.'
                : message,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
          ),
      ],
    );
  }
}

class _ImpactStatTile extends StatelessWidget {
  const _ImpactStatTile({
    required this.value,
    required this.unit,
    required this.label,
    required this.icon,
    required this.tint,
  });

  final String value;
  final String unit;
  final String label;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: tint),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.60),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            style: TextStyle(
              fontSize: 9,
              color: colorScheme.onSurface.withValues(alpha: 0.60),
            ),
          ),
        ],
      ),
    );
  }
}
