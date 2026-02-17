import 'package:flutter/material.dart';

const Color _kPrimary = Color(0xFF007BFF);
const Color _kMuted = Color(0xFF6C757D);

class CustomBottomNavBar extends StatefulWidget {
  final dynamic pharmacyProvider;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onHome;
  final VoidCallback onRegister;
  final VoidCallback onChat;
  final VoidCallback onReports;
  final VoidCallback onAudit;

  const CustomBottomNavBar({
    super.key,
    required this.pharmacyProvider,
    required this.selectedIndex,
    required this.onSelect,
    required this.onHome,
    required this.onRegister,
    required this.onChat,
    required this.onReports,
    required this.onAudit,
  });

  @override
  State<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(covariant CustomBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != _currentIndex) {
      setState(() => _currentIndex = widget.selectedIndex);
    }
  }

  Widget _buildItem({
    required int index,
    required IconData outlined,
    required IconData filled,
    required String label,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    final active = _currentIndex == index;
    final iconSize = active ? 26.0 : 22.0;
    return Expanded(
      child: InkWell(
        onTap: () {
          widget.onSelect(index);
          onTap();
          setState(() => _currentIndex = index);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: 36,
                    height: 32,
                    child: Center(
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 220),
                        scale: active ? 1.12 : 1.0,
                        child: Icon(
                          active ? filled : outlined,
                          size: iconSize,
                          color: active ? _kPrimary : _kMuted,
                        ),
                      ),
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: 0,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _kPrimary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? _kPrimary : _kMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final newReports = (widget.pharmacyProvider?.newReportsCount ?? 0) as int;
    return BottomAppBar(
      // render a flat bar and include a centered register button inline
      elevation: 8,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        height: 64 + bottomInset,
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // left side
            _buildItem(
              index: 0,
              outlined: Icons.home_outlined,
              filled: Icons.home,
              label: 'Home',
              onTap: widget.onHome,
            ),
            _buildItem(
              index: 1,
              outlined: Icons.chat_bubble_outline,
              filled: Icons.chat_bubble,
              label: 'Chat',
              onTap: widget.onChat,
            ),
            // centered register button (inline so it aligns with other icons)
            SizedBox(
              width: 76,
              child: Center(
                child: InkWell(
                  onTap: widget.onRegister,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _kPrimary,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.12 * 255).round()),
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
            // right side
            _buildItem(
              index: 2,
              outlined: Icons.bar_chart_outlined,
              filled: Icons.bar_chart,
              label: 'Reports',
              onTap: widget.onReports,
              badgeCount: newReports,
            ),
            _buildItem(
              index: 3,
              outlined: Icons.assessment_outlined,
              filled: Icons.assessment,
              label: 'Audit',
              onTap: widget.onAudit,
            ),
          ],
        ),
      ),
    );
  }
}
