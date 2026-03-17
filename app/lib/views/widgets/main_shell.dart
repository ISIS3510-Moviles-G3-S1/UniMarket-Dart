import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_theme.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final navUnselected = colorScheme.onSurface.withValues(alpha: 0.70);
    return Scaffold(
      body: navigationShell,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 20),
        child: Container(
          height: 68,
          width: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.30),
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 0,
            shape: const CircleBorder(),
            onPressed: () => context.go('/sell'),
            child: const Icon(Icons.add_rounded, size: 36),
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: colorScheme.surface,
        elevation: 4,
        shape: const CircularNotchedRectangle(),
        notchMargin: 4,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavIcon(
                icon: Icons.home_rounded,
                index: 0,
                currentIndex: navigationShell.currentIndex,
                selectedColor: colorScheme.primary,
                unselectedColor: navUnselected,
                onTap: () => navigationShell.goBranch(0),
              ),
              _NavIcon(
                icon: Icons.search_rounded,
                index: 1,
                currentIndex: navigationShell.currentIndex,
                selectedColor: colorScheme.primary,
                unselectedColor: navUnselected,
                onTap: () => navigationShell.goBranch(1),
              ),
              const SizedBox(width: 48), // space under the center FAB
              Transform.translate(
                offset: const Offset(0, 4),
                child: _NavIcon(
                  icon: Icons.list_rounded,
                  index: 3,
                  currentIndex: navigationShell.currentIndex,
                  selectedColor: colorScheme.primary,
                  unselectedColor: navUnselected,
                  onTap: () => navigationShell.goBranch(3),
                ),
              ),
              _NavIcon(
                icon: Icons.person_rounded,
                index: 4,
                currentIndex: navigationShell.currentIndex,
                selectedColor: colorScheme.primary,
                unselectedColor: navUnselected,
                onTap: () => navigationShell.goBranch(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final int index;
  final int currentIndex;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.index,
    required this.currentIndex,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool selected = index == currentIndex;
    final Color color = selected ? selectedColor : unselectedColor;
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: color),
      splashRadius: 24,
    );
  }
}
