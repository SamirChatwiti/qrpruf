import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/selection/models.dart';
import 'gharad_tile.dart';
// import 'dash_wassit.dart'; // Will be migrated soon
import 'wassit_step_indicator.dart';
import '../../../../core/providers/gharad_provider.dart';
import '../../../../core/providers/wassit_provider.dart';

import '../sifate/chakhsi.dart' as chakhsi;
import '../sifate/mofawad.dart' as mofawad;
import '../sifate/mohami.dart' as mohami;
import '../sifate/mowatik.dart' as mowatik;
import '../sifate/oudoul.dart' as oudoul;
import '../sifate/assistant_huissier.dart' as assistant;
import '../sifate/mohandis.dart' as mohandis;
import '../sifate/idara.dart' as idara;
import '../sifate/prive.dart' as prive;
import '../sifate/expert.dart' as expert;
import '../sifate/jamiyate.dart' as jamiyate;

const List<String> availableFunctions = [
  'استعمال شخصي',
  'مفوض قضائي',
  'محامي',
  'موثق',
  'عدل',
  'مهندس',
  'الإدارة العمومية',
  'المقاولات والمؤسسات الخاصة',
  'الباحثين والخبراء',
  'الهيئات المهنية والجمعيات',
];

class SelectFonction extends ConsumerStatefulWidget {
  const SelectFonction({super.key});

  @override
  ConsumerState<SelectFonction> createState() => _SelectFonctionState();
}

class _SelectFonctionState extends ConsumerState<SelectFonction> {

  List<GharadOption> _getGharadOptions(String? selectedFunction, bool isAssistantMode) {
    if (selectedFunction == 'استعمال شخصي') {
      return chakhsi.chakhsiGharadOptions
          .map((o) => GharadOption(
              title: o.title,
              description: o.description,
              iconPath: o.iconPath))
          .toList();
    }
    if (selectedFunction == 'مفوض قضائي') {
      final list = isAssistantMode 
          ? assistant.assistantGharadOptions
          : mofawad.mofawadGharadOptions;
      
      return list.map((o) => GharadOption(
              title: o.title,
              description: o.description,
              autoFields: o.autoFields,
              reportTemplate: o.reportTemplate,
              iconPath: o.iconPath))
          .toList();
    }
    if (selectedFunction == 'محامي') {
      return mohami.mohamiGharadOptions
          .map((o) => GharadOption(
              title: o.title,
              description: o.description,
              autoFields: o.autoFields,
              reportTemplate: o.reportTemplate,
              iconPath: o.iconPath))
          .toList();
    }
    if (selectedFunction == 'موثق') {
      return mowatik.mowatikGharadOptions
          .map((o) => GharadOption(
              title: o.title,
              description: o.description,
              autoFields: o.autoFields,
              reportTemplate: o.reportTemplate,
              iconPath: o.iconPath,
            ))
          .toList();
    }
    if (selectedFunction == 'عدل') {
      return oudoul.oudoulGharadOptions
          .map((o) => GharadOption(
              title: o.title,
              description: o.description,
              autoFields: o.autoFields,
              reportTemplate: o.reportTemplate,
              iconPath: o.iconPath,
            ))
          .toList();
    }
    if (selectedFunction == 'مهندس') {
      return mohandis.mohandisGharadOptions
          .map((o) => GharadOption(
              title: o.title,
              description: o.description,
              autoFields: o.autoFields,
              reportTemplate: o.reportTemplate,
              iconPath: o.iconPath))
          .toList();
    }
    if (selectedFunction == 'الإدارة العمومية') {
      return idara.idaraGharadOptions
          .map((o) => GharadOption(
              title: o.title,
              description: o.description,
              autoFields: o.autoFields,
              reportTemplate: o.reportTemplate,
              iconPath: o.iconPath))
          .toList();
    }
    if (selectedFunction == 'المقاولات والمؤسسات الخاصة') {
      return prive.priveGharadOptions
          .map((o) => GharadOption(
              title: o.title,
              description: o.description,
              autoFields: o.autoFields,
              reportTemplate: o.reportTemplate,
              iconPath: o.iconPath))
          .toList();
    }
    if (selectedFunction == 'الباحثين والخبراء') {
      return expert.expertGharadOptions
          .map((o) => GharadOption(
              title: o.title,
              description: o.description,
              autoFields: o.autoFields,
              reportTemplate: o.reportTemplate,
              iconPath: o.iconPath))
          .toList();
    }
    if (selectedFunction == 'الهيئات المهنية والجمعيات') {
      return jamiyate.jamiyateGharadOptions
          .map((o) => GharadOption(
              title: o.title,
              description: o.description,
              autoFields: o.autoFields,
              reportTemplate: o.reportTemplate,
              iconPath: o.iconPath))
          .toList();
    }
    return const [];
  }


  IconData _getIconForFunction(String function) {
    switch (function) {
      case 'استعمال شخصي':
        return Icons.person;
      case 'مفوض قضائي':
        return Icons.gavel;
      case 'محامي':
        return Icons.account_balance;
      case 'موثق':
        return Icons.history_edu;
      case 'عدل':
        return Icons.balance;
      case 'مهندس':
        return Icons.engineering;
      case 'الإدارة العمومية':
        return Icons.account_balance_wallet;
      case 'المقاولات والمؤسسات الخاصة':
        return Icons.business;
      case 'الباحثين والخبراء':
        return Icons.psychology;
      case 'الهيئات المهنية والجمعيات':
        return Icons.groups;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gharadProvider);
    final wassitState = ref.watch(wassitProvider);
    
    String? lockedFunction;
    bool isLocked = false;
    if (wassitState.drafts.isNotEmpty) {
      isLocked = true;
      final latestDraft = wassitState.drafts.reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);
      lockedFunction = latestDraft.role;
      if (lockedFunction == 'مساعد مفوض') lockedFunction = 'مفوض قضائي';
    }

    final items = _getGharadOptions(state.selectedFunction, state.isAssistantMode);
    final isCompactFunction = state.selectedFunction == 'استعمال شخصي' ||
        state.selectedFunction == 'مفوض قضائي';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WassitStepIndicator(activeStep: 1, isDark: false),
        const SizedBox(height: 12),
        SizedBox(
          height: 94,
          child: MediaQuery.removePadding(
            context: context,
            removeLeft: true,
            removeRight: true,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              itemCount: availableFunctions.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                final func = availableFunctions[index];
                final isSelected = state.selectedFunction == func;
                final isOtherLocked = isLocked && lockedFunction != func;
                final isThisLocked = isLocked && lockedFunction == func;

                return GestureDetector(
                  onTap: isOtherLocked ? null : () => ref.read(gharadProvider.notifier).setFunction(func),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 105,
                    margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isOtherLocked ? 0.02 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).dividerColor,
                        width: 1.5,
                      ),
                    ),
                    child: Opacity(
                      opacity: isOtherLocked ? 0.4 : 1.0,
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getIconForFunction(func),
                                  color: isThisLocked ? Colors.red : (isSelected ? Colors.white : Theme.of(context).primaryColor),
                                  size: 24,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  func,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).textTheme.bodyMedium?.color,
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isOtherLocked)
                            const Positioned(
                              top: 4,
                              right: 4,
                              child: Icon(Icons.lock_outline, size: 12, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              const SizedBox(height: 4),
              const Text(
                'اختيار الغرض',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'),
                textAlign: TextAlign.right,
              ),

              if (state.selectedFunction == 'مفوض قضائي') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => ref.read(gharadProvider.notifier).setAssistantMode(false),
                          child: Container(
                             padding: const EdgeInsets.symmetric(vertical: 8),
                             decoration: BoxDecoration(
                               color: !state.isAssistantMode ? Theme.of(context).primaryColor : Colors.transparent,
                               borderRadius: BorderRadius.circular(8),
                             ),
                             child: Text(
                               'مفوض قضائي',
                               textAlign: TextAlign.center,
                               style: TextStyle(
                                 color: !state.isAssistantMode ? Colors.white : Theme.of(context).hintColor,
                                 fontWeight: !state.isAssistantMode ? FontWeight.bold : FontWeight.normal,
                                 fontFamily: 'Cairo',
                               ),
                             ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => ref.read(gharadProvider.notifier).setAssistantMode(true),
                          child: Container(
                             padding: const EdgeInsets.symmetric(vertical: 8),
                             decoration: BoxDecoration(
                               color: state.isAssistantMode ? Theme.of(context).primaryColor : Colors.transparent,
                               borderRadius: BorderRadius.circular(8),
                             ),
                             child: Text(
                               'مساعد مفوض',
                               textAlign: TextAlign.center,
                               style: TextStyle(
                                 color: state.isAssistantMode ? Colors.white : Theme.of(context).hintColor,
                                 fontWeight: state.isAssistantMode ? FontWeight.bold : FontWeight.normal,
                                 fontFamily: 'Cairo',
                               ),
                             ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 8),
              ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final hasAssociatedDrafts = wassitState.drafts.any((d) => d.intentions?.contains(item.title) ?? false);
                  
                  return GharadTile(
                    option: item,
                    isChecked: state.selectedGharad.contains(item.title),
                    isDisabled: hasAssociatedDrafts,
                    expandedPanel: state.expandedPanel,
                    index: index,
                    totalCount: items.length,
                    isCompact: isCompactFunction,
                    onCheckChanged: (checked) {
                      if (hasAssociatedDrafts) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('هذا الخيار مقفل لأنه مرتبط بوسائط مسجلة', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo')),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      ref
                          .read(gharadProvider.notifier)
                          .toggleGharad(item.title, checked ?? false);
                    },
                    onPanelTap: (i, s, h) {
                      ref.read(gharadProvider.notifier).togglePanel(i, s, h);
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push('/capture-hub');
                  },
                  icon: const Icon(Icons.fingerprint, color: Colors.white, size: 28),
                  label: const Text('ابدأ التوثيق الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                   style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                ),
              ),
              if (wassitState.drafts.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/summary'),
                    icon: Icon(Icons.checklist_rtl, color: Theme.of(context).primaryColor, size: 22),
                    label: Text(
                      'مراجعة التوثيقات (${wassitState.drafts.length})',
                      style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}
