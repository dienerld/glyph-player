import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../live/live_home_page.dart';
import '../movies/movie_categories_page.dart';
import '../series/series_home_page.dart';
import '../settings/settings_page.dart';

enum _Tab { live, movies, series }

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  _Tab _tab = _Tab.live;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Row(
      children: [
        _Rail(tab: _tab, onSelect: (t) => setState(() => _tab = t)),
        Expanded(
          child: switch (_tab) {
            _Tab.live => const LiveHomePage(),
            _Tab.movies => const MovieCategoriesPage(),
            _Tab.series => const SeriesHomePage(),
          },
        ),
      ],
    ),
  );
}

class _Rail extends StatelessWidget {
  const _Rail({required this.tab, required this.onSelect});
  final _Tab tab;
  final ValueChanged<_Tab> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    width: Tokens.railWidth,
    color: Tokens.panel,
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      children: [
        const Icon(Icons.live_tv, color: Tokens.tally, size: 28),
        const SizedBox(height: 28),
        _RailItem(
          icon: Icons.sensors,
          label: 'Ao vivo',
          active: tab == _Tab.live,
          onTap: () => onSelect(_Tab.live),
        ),
        _RailItem(
          icon: Icons.movie_outlined,
          label: 'Filmes',
          active: tab == _Tab.movies,
          onTap: () => onSelect(_Tab.movies),
        ),
        _RailItem(
          icon: Icons.tv_outlined,
          label: 'Séries',
          active: tab == _Tab.series,
          onTap: () => onSelect(_Tab.series),
        ),
        const Spacer(),
        _RailItem(
          icon: Icons.settings_outlined,
          label: 'Configurações',
          onTap: () => openSettings(context),
        ),
      ],
    ),
  );
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: InkResponse(
      onTap: onTap,
      radius: 26,
      child: SizedBox(
        width: Tokens.railWidth,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (active)
              const Positioned(
                left: 0,
                child: SizedBox(
                  width: 3,
                  height: 24,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Tokens.tally),
                  ),
                ),
              ),
            Icon(icon, color: active ? Tokens.text : Tokens.textDim),
          ],
        ),
      ),
    ),
  );
}
