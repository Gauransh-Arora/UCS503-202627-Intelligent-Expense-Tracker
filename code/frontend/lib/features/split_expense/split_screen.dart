import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/expense_model.dart';
import '../../models/split_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../widgets/primary_button.dart';

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
        ApiService.getCurrentUser().catchError((_) => const UserModel(id: 'me', name: 'You', email: '')),
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
      return (allocated - total).abs() < 1;
    }

    if (_splitMethod == AppConstants.splitPercentage) {
      for (final p in _allParticipants) {
        final val = double.tryParse(_controllers[p.id]?.text ?? '') ?? 0;
        allocated += val;
      }
      return (allocated - 100).abs() < 0.1;
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
      return 100 - allocated;
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
      _controllers[p.id]?.text = each.toStringAsFixed(0);
    }
  }

  Future<void> _createSplit() async {
    if (!_isValid) return;
    setState(() => _isSaving = true);

    try {
      final participantsList = _allParticipants.map((p) {
        final isPayer = p.id == _currentUser.id;
        final amount = double.tryParse(_controllers[p.id]?.text ?? '') ?? (widget.expense.amount / _allParticipants.length);
        final percentage = _splitMethod == AppConstants.splitPercentage
            ? amount
            : (widget.expense.amount > 0 ? (amount / widget.expense.amount) * 100 : 0.0);

        return {
          'participant_name': p.name,
          'amount_owed': isPayer ? 0.0 : amount,
          'percentage': percentage,
          'is_payer': isPayer,
        };
      }).toList();

      await ApiService.createExpenseSplit(
        title: widget.expense.merchant,
        totalAmount: widget.expense.amount,
        splitType: _splitMethod == AppConstants.splitPercentage
            ? 'percentage'
            : (_splitMethod == AppConstants.splitCustom ? 'exact' : 'equal'),
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
      appBar: AppBar(
        title: const Text('Split Expense'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.groups_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.expense.merchant,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                    Text(
                      widget.expense.formattedAmount,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Participants
          Text('Select Contacts to Split With', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),

          if (_isLoadingContacts)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_friends.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('No contacts found. Please add friends in Shared Expenses screen first.',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          else ...[
            ..._friends.map((f) => UserModel(id: f.id, name: f.name, email: f.email ?? ''))
                .map((contact) {
              final isSelected = _selectedContacts.contains(contact.id);
              return GestureDetector(
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
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            AppColors.primary.withValues(alpha: isSelected ? 0.2 : 0.1),
                        child: Text(
                          contact.initials,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          contact.name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          key: ValueKey(isSelected),
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 24),

          // Split method
          Text('Split Method', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              _MethodChip(
                label: 'Equal',
                isSelected: _splitMethod == AppConstants.splitEqual,
                onTap: () {
                  setState(() => _splitMethod = AppConstants.splitEqual);
                  _updateEqualSplit();
                },
              ),
              const SizedBox(width: 8),
              _MethodChip(
                label: 'Percentage',
                isSelected: _splitMethod == AppConstants.splitPercentage,
                onTap: () => setState(() => _splitMethod = AppConstants.splitPercentage),
              ),
              const SizedBox(width: 8),
              _MethodChip(
                label: 'Custom',
                isSelected: _splitMethod == AppConstants.splitCustom,
                onTap: () => setState(() => _splitMethod = AppConstants.splitCustom),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Split details
          if (_allParticipants.length >= 2) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  ..._allParticipants.map((p) {
                    final isYou = p.id == _currentUser.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            child: Text(
                              p.initials,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isYou ? 'You' : p.name,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          if (_splitMethod == AppConstants.splitEqual)
                            Text(
                              '₹${(widget.expense.amount / _allParticipants.length).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppColors.primary,
                              ),
                            )
                          else
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: _controllers[p.id],
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                textAlign: TextAlign.right,
                                decoration: InputDecoration(
                                  hintText: _splitMethod == AppConstants.splitPercentage ? '%' : '₹',
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        const BorderSide(color: AppColors.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: AppColors.primary, width: 2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        const BorderSide(color: AppColors.border),
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
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _splitMethod == AppConstants.splitCustom
                              ? 'Expense Total'
                              : 'Total %',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          _splitMethod == AppConstants.splitCustom
                              ? '₹${widget.expense.amount.toStringAsFixed(0)}'
                              : '100%',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _remainingCustom() == 0 ? 'Balanced' : 'Remaining',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _remainingCustom() == 0
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                        ),
                        Text(
                          _splitMethod == AppConstants.splitCustom
                              ? '₹${_remainingCustom().toStringAsFixed(0)}'
                              : '${_remainingCustom().toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _remainingCustom() == 0
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Create Split',
              isLoading: _isSaving,
              onPressed: _isValid ? _createSplit : null,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Select at least one participant to split the expense.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
