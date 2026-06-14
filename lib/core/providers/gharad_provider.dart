import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qrpruf/features/proofs/presentation/screens/selection/models.dart';

// State to hold the current selection data
class GharadState {
  final String? selectedFunction;
  final Set<String> selectedGharad;
  final String? selectedType;
  final ActiveBlock activeBlock;
  final ExpandedPanel? expandedPanel;
  final bool isAssistantMode; // New field

  const GharadState({
    this.selectedFunction,
    this.selectedGharad = const {},
    this.selectedType,
    this.activeBlock = ActiveBlock.none,
    this.expandedPanel,
    this.isAssistantMode = false,
  });

  GharadState copyWith({
    String? selectedFunction,
    Set<String>? selectedGharad,
    String? selectedType,
    ActiveBlock? activeBlock,
    ExpandedPanel? expandedPanel,
    bool clearExpandedPanel = false,
    bool? isAssistantMode,
  }) {
    return GharadState(
      selectedFunction: selectedFunction ?? this.selectedFunction,
      selectedGharad: selectedGharad ?? this.selectedGharad,
      selectedType: selectedType ?? this.selectedType,
      activeBlock: activeBlock ?? this.activeBlock,
      expandedPanel: clearExpandedPanel ? null : (expandedPanel ?? this.expandedPanel),
      isAssistantMode: isAssistantMode ?? this.isAssistantMode,
    );
  }
}

enum ActiveBlock { none, selection, moment }

class GharadNotifier extends Notifier<GharadState> {
  @override
  GharadState build() {
    return const GharadState();
  }

  void setFunction(String? function, {bool force = false}) {
    if (!force && state.selectedFunction == function && state.selectedGharad.isNotEmpty) {
      return;
    }
    state = state.copyWith(
      selectedFunction: function,
      selectedGharad: force ? state.selectedGharad : {}, // Keep selections on force (initial sync)
      activeBlock: ActiveBlock.selection,
      isAssistantMode: false,
    );
  }

  void setAssistantMode(bool isAssistant) {
    state = state.copyWith(isAssistantMode: isAssistant);
  }

  void toggleGharad(String title, bool isSelected) {
    if (isSelected) {
      // Enforce single selection: replace the set with the new selection
      state = state.copyWith(selectedGharad: {title});
    } else {
      // Allow unchecking the current selection
      state = state.copyWith(selectedGharad: {});
    }
  }

  void setType(String? type) {
    state = state.copyWith(selectedType: type);
  }

  void clearGharad() {
     state = state.copyWith(selectedGharad: {});
  }

  void setActiveBlock(ActiveBlock block) {
    state = state.copyWith(activeBlock: block);
  }

  void togglePanel(int index, PanelSection section, bool hasContent) {
    if (!hasContent) return;
    
    if (state.expandedPanel?.index == index && state.expandedPanel?.section == section) {
       state = state.copyWith(clearExpandedPanel: true);
    } else {
       state = state.copyWith(expandedPanel: ExpandedPanel(index: index, section: section));
    }
  }
}

final gharadProvider = NotifierProvider<GharadNotifier, GharadState>(() {
  return GharadNotifier();
});
