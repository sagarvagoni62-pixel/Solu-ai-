import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Pill button used for the top-right upgrade entry point.
class UpgradePill extends StatelessWidget {
  const UpgradePill({super.key, this.label = 'Upgrade', this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: SoluColors.brandGradient,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: SoluColors.brand.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, size: 15, color: Colors.black),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal scrolling filter chips with an optional count badge.
class ProChipBar extends StatelessWidget {
  const ProChipBar({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.counts = const {},
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (_, i) {
          final active = i == selected;
          final count = counts[labels[i]];
          return GestureDetector(
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? SoluColors.text : SoluColors.raised,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: active ? Colors.transparent : SoluColors.stroke,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: active ? SoluColors.canvas : SoluColors.textMuted,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: active
                            ? SoluColors.canvas.withValues(alpha: 0.12)
                            : SoluColors.surface,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color:
                              active ? SoluColors.canvas : SoluColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class PromoSlide {
  const PromoSlide({
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.colors,
    this.poster,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String cta;
  final List<Color> colors;
  final String? poster;
  final VoidCallback? onTap;
}

/// Auto-advancing promo carousel with dot indicators.
class PromoCarousel extends StatefulWidget {
  const PromoCarousel({super.key, required this.slides, this.height = 178});

  final List<PromoSlide> slides;
  final double height;

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    if (widget.slides.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || !_controller.hasClients) return;
        final next = (_page + 1) % widget.slides.length;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: widget.slides.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _slide(widget.slides[i]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.slides.length, (i) {
            final active = i == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? SoluColors.brandAlt : SoluColors.raised,
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _slide(PromoSlide s) {
    return GestureDetector(
      onTap: s.onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SoluRadius.lg),
          gradient: LinearGradient(
            colors: s.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (s.poster != null)
              Opacity(
                opacity: 0.35,
                child: Image.asset(s.poster!, fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    s.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      s.cta,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
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

/// Section title with a trailing "See All" action.
class ProSectionHeader extends StatelessWidget {
  const ProSectionHeader({
    super.key,
    required this.title,
    this.actionLabel = 'See All',
    this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Row(
                children: [
                  Text(
                    actionLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: SoluColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: SoluColors.textMuted),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Masonry-style template card: poster, pro badge, bookmark and meta row.
class TemplateCard extends StatefulWidget {
  const TemplateCard({
    super.key,
    required this.title,
    required this.poster,
    required this.height,
    this.badge,
    this.pro = false,
    this.likes,
    this.onTap,
  });

  final String title;
  final String poster;
  final double height;
  final String? badge;
  final bool pro;
  final String? likes;
  final VoidCallback? onTap;

  @override
  State<TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<TemplateCard> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(SoluRadius.md),
            child: Stack(
              children: [
                Image.asset(
                  widget.poster,
                  height: widget.height,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: widget.height,
                    color: SoluColors.raised,
                    child: const Center(
                      child: Icon(Icons.image_outlined,
                          color: SoluColors.textMuted),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.45),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.pro)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: SoluColors.divineGradient,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(Icons.workspace_premium_rounded,
                          size: 13, color: Colors.black),
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _saved = !_saved),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(
                        _saved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        size: 15,
                        color: _saved ? SoluColors.brandAlt : Colors.white,
                      ),
                    ),
                  ),
                ),
                if (widget.badge != null)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        widget.badge!,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          if (widget.likes != null) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(Icons.favorite_rounded,
                    size: 12, color: SoluColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  widget.likes!,
                  style: const TextStyle(
                      fontSize: 11.5, color: SoluColors.textMuted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Two-column masonry layout with alternating card heights.
class MasonryGrid extends StatelessWidget {
  const MasonryGrid({super.key, required this.children, this.spacing = 14});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      (i.isEven ? left : right).add(children[i]);
    }

    Widget column(List<Widget> items, {double topPad = 0}) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: topPad),
            child: Column(
              children: [
                for (final w in items) ...[
                  w,
                  SizedBox(height: spacing),
                ],
              ],
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          column(left),
          SizedBox(width: spacing),
          column(right, topPad: 26),
        ],
      ),
    );
  }
}

class NavItem {
  const NavItem({required this.icon, required this.activeIcon, required this.label});
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Floating bottom bar with a central gradient action button.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onSelected,
    required this.onCreate,
  });

  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onSelected;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final half = (items.length / 2).ceil();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: SoluColors.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: SoluColors.stroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < half; i++) _tab(i),
              _fab(),
              for (var i = half; i < items.length; i++) _tab(i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(int i) {
    final active = i == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelected(i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? items[i].activeIcon : items[i].icon,
              size: 22,
              color: active ? SoluColors.brandAlt : SoluColors.textMuted,
            ),
            const SizedBox(height: 3),
            Text(
              items[i].label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: active ? SoluColors.text : SoluColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: onCreate,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: SoluColors.brandGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: SoluColors.brand.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, size: 28, color: Colors.black),
        ),
      ),
    );
  }
}
