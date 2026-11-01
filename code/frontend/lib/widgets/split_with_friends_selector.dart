import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../models/split_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import 'user_avatar.dart';

/// Single participant breakdown representation in a split.
class SplitParticipantShare {
  final String name;
  final String? friendId;
  final bool isYou;
  final double amount;
  final double? percentage;

  const SplitParticipantShare({
    required this.name,
    this.friendId,
    required this.isYou,
    required this.amount,
    this.percentage,
  });
}

/// Data emitted by [SplitWithFriendsSelector].
class SplitSelectionData {
  final bool isEnabled;
  final String splitType; // 'equal', 'custom', 'percentage'
  final List<FriendModel> selectedFriends;
  final List<SplitParticipantShare> participantShares;
  final bool isValid;

  const SplitSelectionData({
    required this.isEnabled,
    this.splitType = 'equal',
    required this.selectedFriends,
    this.participantShares = const [],
    this.isValid = true,
  });
}

/// A versatile, clean component allowing users to split an expense with friends
/// across Manual Entry, UPI Screenshot OCR, and Bill/Receipt Parsing flows
/// supporting Equal, Custom Exact Amounts, and Percentage splits.
class SplitWithFriendsSelector extends StatefulWidget {
  final double totalAmount;
  final ValueChanged<SplitSelectionData> onChanged;

  const SplitWithFriendsSelector({
    super.key,
    required this.totalAmount,
    required this.onChanged,
  });

  /// Helper to record the split in the backend.
  static Future<void> createSplitIfEnabled({
    required bool isEnabled,
    String splitType = 'equal',
    required List<FriendModel> selectedFriends,
    List<SplitParticipantShare> participantShares = const [],
    required String title,
    required double totalAmount,
    String? description,
  }) async {
    if (!isEnabled || selectedFriends.isEmpty || totalAmount <= 0) return;

    try {
      List<Map<String, dynamic>> participants;

      if (participantShares.isNotEmpty) {
        participants = participantShares
            .map(
              (p) => {
                'participant_name': p.name.trim().isNotEmpty
                    ? p.name.trim()
                    : (p.isYou ? 'You' : 'Friend'),
                'amount_owed': p.amount,
                if (p.percentage != null) 'percentage': p.percentage,
                'is_payer': p.isYou,
                if (p.friendId != null) 'friend_id': p.friendId,
              },
            )
            .toList();
      } else {
        final currentUser = await ApiService.getCurrentUser().catchError(
          (_) => const UserModel(id: 'me', name: 'You', email: ''),
        );
        final totalPeople = selectedFriends.length + 1;
        final sharePerPerson = totalAmount / totalPeople;
        participants = <Map<String, dynamic>>[
          {
            'participant_name': currentUser.name.isNotEmpty
                ? currentUser.name
                : 'You',
            'amount_owed': sharePerPerson,
            'is_payer': true,
          },
          ...selectedFriends.map(
            (f) => {
              'participant_name': f.name,
              'amount_owed': sharePerPerson,
              'is_payer': false,
              'friend_id': f.id,
            },
          ),
        ];
      }

      await ApiService.createExpenseSplit(
        title: title.trim().isNotEmpty ? title.trim() : 'Expense Split',
        totalAmount: totalAmount,
        splitType: splitType,
        description: description ?? 'Split for $title',
        participants: participants,
      );
    } catch (e) {
      debugPrint('[SplitWithFriendsSelector] Error creating split: $e');
      rethrow;
    }
  }

  @override
  State<SplitWithFriendsSelector> createState() =>
      _SplitWithFriendsSelectorState();
}

class _SplitWithFriendsSelectorState extends State<SplitWithFriendsSelector> {
  bool _isSplitEnabled = false;
  bool _isLoadingFriends = false;
  List<FriendModel> _friends = [];
  final Set<String> _selectedFriendIds = {};
  String _splitType = 'equal'; // 'equal', 'custom', 'percentage'

  UserModel _currentUser = const UserModel(id: 'me', name: 'You', email: '');
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _fetchFriends();
    _fetchCurrentUser();
  }

  @override
  void didUpdateWidget(covariant SplitWithFriendsSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalAmount != widget.totalAmount) {
      if (_splitType == 'equal') {
        _recalculateEqualControllers();
      }
      _notifyChange();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchCurrentUser() async {
    try {
      final user = await ApiService.getCurrentUser();
      if (!mounted) return;
      setState(() => _currentUser = user);
    } catch (_) {}
  }

  Future<void> _fetchFriends() async {
    setState(() => _isLoadingFriends = true);
    try {
      final list = await ApiService.getFriends();
      if (!mounted) return;
      setState(() {
        _friends = list;
        _isLoadingFriends = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingFriends = false);
    }
  }

  TextEditingController _getController(String id) {
    return _controllers.putIfAbsent(id, () {
      final ctrl = TextEditingController();
      ctrl.addListener(() {
        if (mounted) setState(() {});
        _notifyChange();
      });
      return ctrl;
    });
  }

  void _recalculateEqualControllers() {
    final selectedFriends = _friends
        .where((f) => _selectedFriendIds.contains(f.id))
        .toList();
    final count = selectedFriends.length + 1;
    if (count <= 0) return;
    final share = widget.totalAmount > 0 ? (widget.totalAmount / count) : 0.0;

    _getController('me').text = share.toStringAsFixed(2);
    for (final f in selectedFriends) {
      _getController(f.id).text = share.toStringAsFixed(2);
    }
  }

  void _recalculatePercentageControllers() {
    final selectedFriends = _friends
        .where((f) => _selectedFriendIds.contains(f.id))
        .toList();
    final count = selectedFriends.length + 1;
    if (count <= 0) return;
    final pct = (100.0 / count).toStringAsFixed(1);

    _getController('me').text = pct;
    for (final f in selectedFriends) {
      _getController(f.id).text = pct;
    }
  }

  List<SplitParticipantShare> _buildParticipantShares() {
    final selected = _friends
        .where((f) => _selectedFriendIds.contains(f.id))
        .toList();
    final totalPeople = selected.length + 1;

    if (_splitType == 'equal') {
      final share = widget.totalAmount > 0
          ? (widget.totalAmount / totalPeople)
          : 0.0;
      final pct = 100.0 / totalPeople;
      return [
        SplitParticipantShare(
          name: _currentUser.name.isNotEmpty ? _currentUser.name : 'You',
          isYou: true,
          amount: share,
          percentage: pct,
        ),
        ...selected.map(
          (f) => SplitParticipantShare(
            name: f.name,
            friendId: f.id,
            isYou: false,
            amount: share,
            percentage: pct,
          ),
        ),
      ];
    }

    if (_splitType == 'custom') {
      final myVal = double.tryParse(_getController('me').text) ?? 0.0;
      return [
        SplitParticipantShare(
          name: _currentUser.name.isNotEmpty ? _currentUser.name : 'You',
          isYou: true,
          amount: myVal,
          percentage: widget.totalAmount > 0
              ? (myVal / widget.totalAmount) * 100
              : 0.0,
        ),
        ...selected.map((f) {
          final val = double.tryParse(_getController(f.id).text) ?? 0.0;
          return SplitParticipantShare(
            name: f.name,
            friendId: f.id,
            isYou: false,
            amount: val,
            percentage: widget.totalAmount > 0
                ? (val / widget.totalAmount) * 100
                : 0.0,
          );
        }),
      ];
    }

    // percentage
    final myPct = double.tryParse(_getController('me').text) ?? 0.0;
    final myAmt = (widget.totalAmount * myPct) / 100.0;
    return [
      SplitParticipantShare(
        name: _currentUser.name.isNotEmpty ? _currentUser.name : 'You',
        isYou: true,
        amount: myAmt,
        percentage: myPct,
      ),
      ...selected.map((f) {
        final p = double.tryParse(_getController(f.id).text) ?? 0.0;
        final amt = (widget.totalAmount * p) / 100.0;
        return SplitParticipantShare(
          name: f.name,
          friendId: f.id,
          isYou: false,
          amount: amt,
          percentage: p,
        );
      }),
    ];
  }

  bool _isSplitValid() {
    final selected = _friends
        .where((f) => _selectedFriendIds.contains(f.id))
        .toList();
    if (selected.isEmpty) return false;
    if (widget.totalAmount <= 0) return true;

    if (_splitType == 'equal') return true;

    if (_splitType == 'custom') {
      double totalAllocated = 0.0;
      totalAllocated += double.tryParse(_getController('me').text) ?? 0.0;
      for (final f in selected) {
        totalAllocated += double.tryParse(_getController(f.id).text) ?? 0.0;
      }
      return (totalAllocated - widget.totalAmount).abs() <= 1.0;
    }

    if (_splitType == 'percentage') {
      double totalPct = 0.0;
      totalPct += double.tryParse(_getController('me').text) ?? 0.0;
      for (final f in selected) {
        totalPct += double.tryParse(_getController(f.id).text) ?? 0.0;
      }
      return (totalPct - 100.0).abs() <= 0.5;
    }

    return true;
  }

  void _notifyChange() {
    final selected = _friends
        .where((f) => _selectedFriendIds.contains(f.id))
        .toList();
    final shares = _buildParticipantShares();
    widget.onChanged(
      SplitSelectionData(
        isEnabled: _isSplitEnabled,
        splitType: _splitType,
        selectedFriends: selected,
        participantShares: shares,
        isValid: _isSplitValid(),
      ),
    );
  }

  void _toggleFriend(FriendModel friend) {
    setState(() {
      if (_selectedFriendIds.contains(friend.id)) {
        _selectedFriendIds.remove(friend.id);
      } else {
        _selectedFriendIds.add(friend.id);
      }
      if (_splitType == 'equal') {
        _recalculateEqualControllers();
      } else if (_splitType == 'percentage') {
        _recalculatePercentageControllers();
      }
    });
    _notifyChange();
  }

  void _changeSplitType(String type) {
    setState(() {
      _splitType = type;
      if (type == 'equal' || type == 'custom') {
        _recalculateEqualControllers();
      } else if (type == 'percentage') {
        _recalculatePercentageControllers();
      }
    });
    _notifyChange();
  }

  Future<void> _showAddFriendDialog() async {
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
            side: const BorderSide(color: AppColors.border),
          ),
          title: const Text(
            'Add Friend',
            style: TextStyle(
              fontFamily: AppTheme.fontSans,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: "Friend's name",
                    hintText: 'e.g. Rahul, Sneha',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      try {
                        final newFriend = await ApiService.addFriend(
                          nameCtrl.text.trim(),
                        );
                        if (!dialogCtx.mounted) return;
                        Navigator.pop(dialogCtx);
                        if (!mounted) return;
                        setState(() {
                          _friends.insert(0, newFriend);
                          _selectedFriendIds.add(newFriend.id);
                        });
                        _notifyChange();
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Failed to add friend: ${e.toString().replaceAll('Exception: ', '')}',
                            ),
                            backgroundColor: AppColors.debit,
                          ),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add & Select'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedFriends = _friends
        .where((f) => _selectedFriendIds.contains(f.id))
        .toList();
    final totalPeople = selectedFriends.length + 1; // User + selected friends
    final equalShare = widget.totalAmount > 0
        ? (widget.totalAmount / totalPeople)
        : 0.0;

    // Custom amounts total
    double customAllocated = 0.0;
    if (_splitType == 'custom') {
      customAllocated += double.tryParse(_getController('me').text) ?? 0.0;
      for (final f in selectedFriends) {
        customAllocated += double.tryParse(_getController(f.id).text) ?? 0.0;
      }
    }

    // Percentage total
    double percentageAllocated = 0.0;
    if (_splitType == 'percentage') {
      percentageAllocated += double.tryParse(_getController('me').text) ?? 0.0;
      for (final f in selectedFriends) {
        percentageAllocated +=
            double.tryParse(_getController(f.id).text) ?? 0.0;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(
          color: _isSplitEnabled
              ? AppColors.accent.withValues(alpha: 0.5)
              : AppColors.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with toggle switch
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _isSplitEnabled
                      ? AppColors.accent.withValues(alpha: 0.12)
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                ),
                child: Icon(
                  Icons.call_split_rounded,
                  size: 18,
                  color: _isSplitEnabled
                      ? AppColors.accent
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Split with friends',
                      style: TextStyle(
                        fontFamily: AppTheme.fontSans,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _isSplitEnabled
                          ? 'Divide equally, by exact amount, or %'
                          : 'Record as a shared group expense',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontSans,
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _isSplitEnabled,
                activeTrackColor: AppColors.accent,
                activeThumbColor: Colors.white,
                onChanged: (val) {
                  setState(() {
                    _isSplitEnabled = val;
                    if (val && _splitType == 'equal') {
                      _recalculateEqualControllers();
                    }
                  });
                  _notifyChange();
                },
              ),
            ],
          ),

          if (_isSplitEnabled) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),

            // Friends chips selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SELECT FRIENDS TO SPLIT WITH',
                  style: TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (_friends.isNotEmpty)
                  Text(
                    '${selectedFriends.length} selected',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontSans,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accent,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            if (_isLoadingFriends)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Quick add friend chip
                  ActionChip(
                    avatar: const Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 15,
                      color: AppColors.accent,
                    ),
                    label: const Text(
                      'Add friend',
                      style: TextStyle(
                        fontFamily: AppTheme.fontSans,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                    backgroundColor: AppColors.surfaceElevated,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTokens.radiusSmall,
                      ),
                      side: const BorderSide(color: AppColors.border, width: 1),
                    ),
                    onPressed: _showAddFriendDialog,
                  ),

                  // Friends list chips
                  ..._friends.map((friend) {
                    final isSelected = _selectedFriendIds.contains(friend.id);
                    return FilterChip(
                      selected: isSelected,
                      avatar: UserAvatar(
                        emailSeed: friend.email ?? friend.name,
                        initials: friend.name.isNotEmpty
                            ? friend.name[0].toUpperCase()
                            : 'F',
                        size: 20,
                      ),
                      label: Text(
                        friend.name,
                        style: TextStyle(
                          fontFamily: AppTheme.fontSans,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? AppColors.ink
                              : AppColors.textPrimary,
                        ),
                      ),
                      selectedColor: AppColors.accent.withValues(alpha: 0.18),
                      backgroundColor: AppColors.surfaceElevated,
                      checkmarkColor: AppColors.ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusSmall,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.border,
                          width: isSelected ? 1.4 : 1,
                        ),
                      ),
                      onSelected: (_) => _toggleFriend(friend),
                    );
                  }),
                ],
              ),

            if (!_isLoadingFriends && _friends.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'No friends saved yet. Tap "+ Add friend" above to add someone.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),

            if (selectedFriends.isNotEmpty) ...[
              const SizedBox(height: 14),

              // Split method tabs: Equal | Exact Amount | Percentage
              Row(
                children: [
                  _SplitTypePill(
                    label: 'Equal',
                    icon: Icons.equalizer_rounded,
                    isSelected: _splitType == 'equal',
                    onTap: () => _changeSplitType('equal'),
                  ),
                  const SizedBox(width: 8),
                  _SplitTypePill(
                    label: 'Exact ₹',
                    icon: Icons.currency_rupee_rounded,
                    isSelected: _splitType == 'custom',
                    onTap: () => _changeSplitType('custom'),
                  ),
                  const SizedBox(width: 8),
                  _SplitTypePill(
                    label: 'Percentage %',
                    icon: Icons.percent_rounded,
                    isSelected: _splitType == 'percentage',
                    onTap: () => _changeSplitType('percentage'),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Participant share inputs
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // You (Payer)
                    _buildParticipantRow(
                      id: 'me',
                      name: _currentUser.name.isNotEmpty
                          ? '${_currentUser.name} (You, Payer)'
                          : 'You (Payer)',
                      emailSeed: _currentUser.email,
                      initials: 'Y',
                      isYou: true,
                      equalShare: equalShare,
                    ),

                    const Divider(height: 14, color: AppColors.border),

                    // Selected friends
                    ...selectedFriends.map((f) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: _buildParticipantRow(
                          id: f.id,
                          name: f.name,
                          emailSeed: f.email ?? f.name,
                          initials: f.name.isNotEmpty
                              ? f.name[0].toUpperCase()
                              : 'F',
                          isYou: false,
                          equalShare: equalShare,
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Status / Validation Banner
              _buildStatusBanner(
                totalPeople: totalPeople,
                equalShare: equalShare,
                customAllocated: customAllocated,
                percentageAllocated: percentageAllocated,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildParticipantRow({
    required String id,
    required String name,
    required String? emailSeed,
    required String initials,
    required bool isYou,
    required double equalShare,
  }) {
    final ctrl = _getController(id);

    return Row(
      children: [
        UserAvatar(emailSeed: emailSeed, initials: initials, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              fontFamily: AppTheme.fontSans,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),

        if (_splitType == 'equal') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '₹${equalShare.toStringAsFixed(0)}',
              style: const TextStyle(
                fontFamily: AppTheme.fontSans,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ] else if (_splitType == 'custom') ...[
          SizedBox(
            width: 95,
            height: 36,
            child: TextFormField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: AppTheme.fontSans,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: const TextStyle(
                  fontFamily: AppTheme.fontSans,
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                fillColor: AppColors.surfaceCard,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                  borderSide: const BorderSide(
                    color: AppColors.accent,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ] else if (_splitType == 'percentage') ...[
          SizedBox(
            width: 85,
            height: 36,
            child: TextFormField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: AppTheme.fontSans,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                suffixText: '%',
                suffixStyle: const TextStyle(
                  fontFamily: AppTheme.fontSans,
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                fillColor: AppColors.surfaceCard,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                  borderSide: const BorderSide(
                    color: AppColors.accent,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusBanner({
    required int totalPeople,
    required double equalShare,
    required double customAllocated,
    required double percentageAllocated,
  }) {
    if (_splitType == 'equal') {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 16,
              color: AppColors.accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Equal Split: ₹${equalShare.toStringAsFixed(0)} each across $totalPeople people',
                style: const TextStyle(
                  fontFamily: AppTheme.fontSans,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_splitType == 'custom') {
      final diff = widget.totalAmount - customAllocated;
      final isBalanced = diff.abs() <= 1.0;

      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isBalanced
              ? AppColors.credit.withValues(alpha: 0.08)
              : AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          border: Border.all(
            color: isBalanced
                ? AppColors.credit.withValues(alpha: 0.3)
                : AppColors.warning.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isBalanced
                  ? Icons.check_circle_rounded
                  : Icons.info_outline_rounded,
              size: 16,
              color: isBalanced ? AppColors.credit : AppColors.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isBalanced
                    ? 'Exact match: ₹${customAllocated.toStringAsFixed(0)} allocated'
                    : (diff > 0
                          ? '₹${diff.toStringAsFixed(0)} left to allocate (Total ₹${widget.totalAmount.toStringAsFixed(0)})'
                          : '₹${(-diff).toStringAsFixed(0)} over total (Total ₹${widget.totalAmount.toStringAsFixed(0)})'),
                style: TextStyle(
                  fontFamily: AppTheme.fontSans,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isBalanced ? AppColors.credit : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // percentage
    final pctDiff = 100.0 - percentageAllocated;
    final isPctBalanced = pctDiff.abs() <= 0.5;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isPctBalanced
            ? AppColors.credit.withValues(alpha: 0.08)
            : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        border: Border.all(
          color: isPctBalanced
              ? AppColors.credit.withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPctBalanced
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            size: 16,
            color: isPctBalanced ? AppColors.credit : AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isPctBalanced
                  ? 'Percentages balanced: 100% allocated'
                  : (pctDiff > 0
                        ? '${pctDiff.toStringAsFixed(1)}% remaining to reach 100%'
                        : '${(-pctDiff).toStringAsFixed(1)}% over 100%'),
              style: TextStyle(
                fontFamily: AppTheme.fontSans,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isPctBalanced ? AppColors.credit : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitTypePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SplitTypePill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.15)
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? AppColors.ink : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.fontSans,
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.ink : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
