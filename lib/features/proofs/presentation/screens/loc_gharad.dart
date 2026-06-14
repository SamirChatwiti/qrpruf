import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/gharad_provider.dart';
import '../../../../blocks/animated_menu.dart';
import '../widgets/select_fonction.dart';
import '../widgets/select_acte_contrat.dart';
import '../widgets/select_moment.dart';

enum PageSection { functions, contracts, moment }

class LocGharadPage extends ConsumerStatefulWidget {
  final PageSection? initialSection;
  const LocGharadPage({super.key, this.initialSection});

  @override
  ConsumerState<LocGharadPage> createState() => _LocGharadPageState();
}

class _LocGharadPageState extends ConsumerState<LocGharadPage> {
  late PageSection _activeExpandedSection;
  bool _isMenuOpen = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _activeExpandedSection = widget.initialSection ?? PageSection.functions;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gharadProvider.notifier).setActiveBlock(ActiveBlock.none);
      _loadUserFunction();
    });
    _preWarmGps();
  }

  Future<void> _preWarmGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadUserFunction() {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata;
    final function = metadata?['fonction'];
    final defaultFunction = availableFunctions.isNotEmpty ? availableFunctions.first : null;

    if (function is String && function.isNotEmpty) {
      ref.read(gharadProvider.notifier).setFunction(function);
    } else {
      ref.read(gharadProvider.notifier).setFunction(defaultFunction);
    }
  }

  void _navigateToProfile() {
    context.push('/profile');
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    EdgeInsetsGeometry? margin,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: (margin?.horizontal ?? 1) == 0 ? BorderRadius.zero : BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Icon(icon, color: primaryColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        extendBody: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        bottomNavigationBar: AnimatedMenu(
          selectedIndex: 0,
          onMenuToggle: (isOpen) => setState(() => _isMenuOpen = isOpen),
          onHomeTap: () {
            setState(() => _activeExpandedSection = PageSection.functions);
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          },
          onProfileTap: _navigateToProfile,
          onFunctionsTap: () {
            setState(() => _activeExpandedSection = PageSection.functions);
          },
          onContractsTap: () {
            setState(() => _activeExpandedSection = PageSection.contracts);
          },
          onMomentTap: () {
             setState(() => _activeExpandedSection = PageSection.moment);
          },
        ),
        body: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Builder(
                    builder: (context) {
                      switch (_activeExpandedSection) {
                        case PageSection.functions:
                          return _buildSectionCard(
                            title: 'الوظائف والمهام',
                            icon: Icons.business_center,
                            child: const SelectFonction(),
                            margin: EdgeInsets.zero,
                          );
                        case PageSection.contracts:
                          return _buildSectionCard(
                            title: 'العقود والالتزامات',
                            icon: Icons.assignment,
                            child: const SelectActeContrat(),
                          );
                        case PageSection.moment:
                          return _buildSectionCard(
                            title: 'توثيق لحظة',
                            icon: Icons.camera_alt,
                            child: const SelectMoment(),
                          );
                      }
                    },
                  ),
                ),
                const SliverPadding(
                  padding: EdgeInsets.only(bottom: 140),
                ),
              ],
            ),
            // Home button — top-left (visual), top-right in RTL layout
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.home_rounded),
                  color: Theme.of(context).colorScheme.primary,
                  iconSize: 28,
                  tooltip: 'الرئيسية',
                  onPressed: () => context.go('/dashboard'),
                ),
              ),
            ),
            if (_isMenuOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _isMenuOpen = false),
                  child: Container(
                    color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
