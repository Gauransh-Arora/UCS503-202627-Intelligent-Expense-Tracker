
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/expense_model.dart';
import '../../models/split_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/user_avatar.dart';

class SplitScreen extends StatefulWidget {
  final ExpenseModel expense;
  const SplitScreen({super.key, required this.expense});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  String _splitMethod = AppConstants.splitEqual;
  final Set<String> _selectedContacts = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;
  bool _isLoadingContacts = true;
  List<FriendModel> _friends = [];
  UserModel _currentUser = const UserModel(id: 'me', name: 'You', email: '');

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final results = await Future.wait([
        ApiService.getFriends().catchError((_) => <FriendModel>[]),
        ApiService.getCurrentUser().catchError(
          (_) => const UserModel(id: 'me', name: 'You', email: ''),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _friends = results[0] as List<FriendModel>;
        _currentUser = results[1] as UserModel;
        _isLoadingContacts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingContacts = false);
    }
  }

  List<UserModel> get _allParticipants {
    final list = <UserModel>[_currentUser];
    for (final f in _friends) {
      if (_selectedContacts.contains(f.id)) {
        list.add(UserModel(id: f.id, name: f.name, email: f.email ?? ''));
      }
    }
    return list;
  }

  bool get _isValid {
    if (_allParticipants.length < 2) return false;
    if (_splitMethod == AppConstants.splitEqual) return true;

    final total = widget.expense.amount;
    double allocated = 0;

    if (_splitMethod == AppConstants.splitCustom) {
      for (final p in _allParticipants) {
        final val = double.tryParse(_controllers[p.id]?.text ?? '') ?? 0;
        allocated += val;
      }
      return (allocated - total).abs() <= 1.0;
    }

    if (_splitMethod == AppConstants.splitPercentage) {
      for (final p in _allParticipants) {
        final val = double.tryParse(_controllers[p.id]?.text ?? '') ?? 0;
        allocated += val;
      }
      return (allocated - 100).abs() <= 0.1;
    }

    return false;
  }

  double _remainingCustom() {
    if (_splitMethod == AppConstants.splitCustom) {
      double allocated = 0;
      for (final p in _allParticipants) {
        final val = double.tryParse(_controllers[p.id]?.text ?? '') ?? 0;
        allocated += val;
      }
      return widget.expense.amount - allocated;
    }
    if (_splitMethod == AppConstants.splitPercentage) {
      double allocated = 0;
      for (final p in _allParticipants) {
        final val = double.tryParse(_controllers[p.id]?.text ?? '') ?? 0;
        allocated += val;
      }
      return 100.0 - allocated;
    }
    return 0;
  }

  void _initControllers() {
    for (final p in _allParticipants) {
      _controllers.putIfAbsent(p.id, () => TextEditingController());
    }
  }

  void _updateEqualSplit() {
    if (_splitMethod != AppConstants.splitEqual) return;
    final n = _allParticipants.length;
    if (n == 0) return;
    final each = widget.expense.amount / n;
    for (final p in _allParticipants) {
      _controllers[p.id]?.text = each.toStringAsFixed(2);
    }
  }

  Future<void> _createSplit() async {
    if (!_isValid) return;
    setState(() => _isSaving = true);

    try {
      final participantsList = _allParticipants.map((p) {
        final isPayer = p.id == _currentUser.id;
        final amount =
            double.tryParse(_controllers[p.id]?.text ?? '') ??
            (widget.expense.amount / _allParticipants.length);
        final percentage = _splitMethod == AppConstants.splitPercentage
            ? amount
            : (widget.expense.amount > 0
                  ? (amount / widget.expense.amount) * 100
                  : 0.0);

        return {
          'participant_name': p.name,
          'amount_owed': amount,
          'percentage': percentage,
          'is_payer': isPayer,
        };
      }).toList();

      await ApiService.createExpenseSplit(
        title: widget.expense.merchant,
        totalAmount: widget.expense.amount,
        splitType: _splitMethod == AppConstants.splitPercentage
            ? 'percentage'
            : (_splitMethod == AppConstants.splitCustom ? 'custom' : 'equal'),
        description: 'Split for ${widget.expense.merchant}',
        participants: participantsList,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Split created successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create split: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _initControllers();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Split Expense')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // Expense Summary Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.expense.merchant,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.expense.category,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  widget.expense.formattedAmount,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Participants
          Text(
            'Select Contacts to Split With',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          if (_isLoadingContacts)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_friends.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'No contacts found. Add contacts in Shared Expenses screen first.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            )
          else ...[
            ..._friends
                .map(
                  (f) =>
                      UserModel(id: f.id, name: f.name, email: f.email ?? ''),
                )
                .map((contact) {
                  final isSelected = _selectedContacts.contains(contact.id);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedContacts.remove(contact.id);
                            _controllers.remove(contact.id);
                          } else {
                            _selectedContacts.add(contact.id);
                          }
                          _updateEqualSplit();
                        });
                      },
                      borderRadius: BorderRadius.circular(
                        AppTokens.radiusMedium,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.surfaceElevated
                              : AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusMedium,
                          ),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            UserAvatar(
                              avatarUrl: contact.avatarUrl,
                              emailSeed: contact.email,
                              initials: contact.initials,
                              size: 28,
                              borderRadius: AppTokens.radiusSmall,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                contact.name,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                            ),
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 18,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.borderStrong,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
          ],
          const SizedBox(height: 20),

          // Split method
          Text(
            'Split Method',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MethodChip(
                label: 'Equal',
                isSelected: _splitMethod == AppConstants.splitEqual,
                onTap: () {
                  setState(() {
                    _splitMethod = AppConstants.splitEqual;
                    _updateEqualSplit();
                  });
                },
              ),
              const SizedBox(width: 8),
              _MethodChip(
                label: 'Percentage',
                isSelected: _splitMethod == AppConstants.splitPercentage,
                onTap: () {
                  setState(() {
                    _splitMethod = AppConstants.splitPercentage;
                    final n = _allParticipants.length;
                    if (n > 0) {
                      final each = (100.0 / n).toStringAsFixed(1);
                      for (final p in _allParticipants) {
                        _controllers[p.id]?.text = each;
                      }
                    }
                  });
                },
              ),
              const SizedBox(width: 8),
              _MethodChip(
                label: 'Custom',
                isSelected: _splitMethod == AppConstants.splitCustom,
                onTap: () {
                  setState(() {
                    _splitMethod = AppConstants.splitCustom;
                    final n = _allParticipants.length;
                    if (n > 0) {
                      final each = (widget.expense.amount / n).toStringAsFixed(
                        2,
                      );
                      for (final p in _allParticipants) {
                        _controllers[p.id]?.text = each;
                      }
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Split details
          if (_allParticipants.length >= 2) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  ..._allParticipants.map((p) {
                    final isYou = p.id == _currentUser.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          UserAvatar(
                            avatarUrl: p.avatarUrl,
                            emailSeed: p.email,
                            initials: p.initials,
                            size: 28,
                            borderRadius: AppTokens.radiusSmall,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isYou ? 'You' : p.name,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                          ),
                          if (_splitMethod == AppConstants.splitEqual)
                            Text(
                              '₹${(widget.expense.amount / _allParticipants.length).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            )
                          else
                            SizedBox(
                              width: 90,
                              height: 36,
                              child: TextField(
                                controller: _controllers[p.id],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (_) => setState(() {}),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  fillColor: AppColors.surfaceElevated,
                                  filled: true,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  if (_splitMethod != AppConstants.splitEqual) ...[
                    const Divider(height: 20, color: AppColors.border),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _splitMethod == AppConstants.splitCustom
                              ? 'Expense Total'
                              : 'Total %',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          _splitMethod == AppConstants.splitCustom
                              ? '₹${widget.expense.amount.toStringAsFixed(2)}'
                              : '100%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _remainingCustom().abs() < 0.01
                              ? 'Balanced'
                              : 'Remaining',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _remainingCustom().abs() < 0.01
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                        ),
                        Text(
                          _splitMethod == AppConstants.splitCustom
                              ? '₹${_remainingCustom().abs().toStringAsFixed(2)}'
                              : '${_remainingCustom().abs().toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: _remainingCustom().abs() < 0.01
                                ? AppColors.success
                                : AppColors.danger,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Create Split',
              isLoading: _isSaving,
              onPressed: _isValid ? _createSplit : null,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'Select at least one contact to split the expense.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MethodChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
