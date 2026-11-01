
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/split_model.dart';
import '../../services/api_service.dart';
import '../../widgets/primary_button.dart';

class SharedExpensesScreen extends StatefulWidget {
  const SharedExpensesScreen({super.key});

  @override
  State<SharedExpensesScreen> createState() => _SharedExpensesScreenState();
}

class _SharedExpensesScreenState extends State<SharedExpensesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  UserBalanceModel? _userBalance;
  List<SettlementItemModel> _settlements = [];
  List<FriendModel> _friends = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.calculateUserBalance(forceRefresh: forceRefresh)
            .catchError((_) => const UserBalanceModel(
                  totalOwedToUser: 0.0,
                  totalUserOwes: 0.0,
                  netBalance: 0.0,
                  friendBalances: [],
                )),
        ApiService.getSettlementHistory(forceRefresh: forceRefresh)
            .catchError((_) => <SettlementItemModel>[]),
        ApiService.getFriends(forceRefresh: forceRefresh)
            .catchError((_) => <FriendModel>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _userBalance = results[0] as UserBalanceModel;
        _settlements = results[1] as List<SettlementItemModel>;
        _friends = results[2] as List<FriendModel>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _showAddFriendDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusLarge),
        ),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add Contact',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'e.g. Sarah Jenkins',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address (Optional)',
                      hintText: 'e.g. sarah@example.com',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number (Optional)',
                      hintText: 'e.g. +91 98765 43210',
                    ),
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: isSaving ? 'Saving...' : 'Add Contact',
                    onPressed: isSaving
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;

                            setSheetState(() => isSaving = true);
                            try {
                              await ApiService.addFriend(
                                name,
                                email: emailCtrl.text.trim().isNotEmpty
                                    ? emailCtrl.text.trim()
                                    : null,
                                phone: phoneCtrl.text.trim().isNotEmpty
                                    ? phoneCtrl.text.trim()
                                    : null,
                              );
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              _loadAllData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Contact added'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            } catch (e) {
                              setSheetState(() => isSaving = false);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to add contact: $e'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSettleUpDialog({String? defaultFriendName, double? defaultAmount}) {
    final friendCtrl = TextEditingController(text: defaultFriendName ?? '');
    final amountCtrl = TextEditingController(
      text: defaultAmount != null && defaultAmount > 0
          ? defaultAmount.toStringAsFixed(0)
          : '',
    );
    String direction = 'you_paid'; // 'you_paid' or 'friend_paid'
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusLarge),
        ),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Record Settlement',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 16),
                  TextField(
                    controller: friendCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Friend Name',
                      hintText: 'e.g. Alex Carter',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Settlement Amount (₹)',
                      hintText: 'e.g. 500',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Direction',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _DirectionChip(
                        label: 'You paid friend',
                        isSelected: direction == 'you_paid',
                        onTap: () =>
                            setSheetState(() => direction = 'you_paid'),
                      ),
                      const SizedBox(width: 8),
                      _DirectionChip(
                        label: 'Friend paid you',
                        isSelected: direction == 'friend_paid',
                        onTap: () =>
                            setSheetState(() => direction = 'friend_paid'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: isSaving ? 'Recording...' : 'Save Settlement',
                    onPressed: isSaving
                        ? null
                        : () async {
                            final friend = friendCtrl.text.trim();
                            final amount =
                                double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                            if (friend.isEmpty || amount <= 0) return;

                            setSheetState(() => isSaving = true);
                            try {
                              final payer = direction == 'you_paid'
                                  ? 'You'
                                  : friend;
                              final payee = direction == 'you_paid'
                                  ? friend
                                  : 'You';

                              await ApiService.recordSettlement(
                                payerName: payer,
                                payeeName: payee,
                                amount: amount,
                              );

                              if (!context.mounted) return;
                              Navigator.pop(context);
                              _loadAllData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Settlement recorded'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            } catch (e) {
                              setSheetState(() => isSaving = false);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFriendLedger(FriendBalanceItemModel item) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusLarge),
        ),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.friendName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.netBalance > 0
                            ? 'Owes you ₹${item.netBalance.toStringAsFixed(0)}'
                            : (item.netBalance < 0
                                  ? 'You owe ₹${item.netBalance.abs().toStringAsFixed(0)}'
                                  : 'All settled up'),
                        style: TextStyle(
                          color: item.netBalance > 0
                              ? AppColors.success
                              : (item.netBalance < 0
                                    ? AppColors.danger
                                    : AppColors.textSecondary),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showSettleUpDialog(
                        defaultFriendName: item.friendName,
                        defaultAmount: item.netBalance.abs(),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusSmall,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Settle',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              Text(
                'Breakdown',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildLedgerRow(
                      'Friend borrowed from you',
                      '₹${item.totalOwedByFriend.toStringAsFixed(0)}',
                      AppColors.textPrimary,
                    ),
                    _buildLedgerRow(
                      'Friend settled with you',
                      '₹${item.totalSettledByFriend.toStringAsFixed(0)}',
                      AppColors.success,
                    ),
                    const Divider(height: 16, color: AppColors.border),
                    _buildLedgerRow(
                      'You borrowed from friend',
                      '₹${item.totalOwedByUser.toStringAsFixed(0)}',
                      AppColors.textPrimary,
                    ),
                    _buildLedgerRow(
                      'You settled with friend',
                      '₹${item.totalSettledByUser.toStringAsFixed(0)}',
                      AppColors.info,
                    ),
                    const Divider(height: 16, color: AppColors.border),
                    _buildLedgerRow(
                      'Net Balance',
                      item.netBalance >= 0
                          ? '+₹${item.netBalance.toStringAsFixed(0)}'
                          : '-₹${item.netBalance.abs().toStringAsFixed(0)}',
                      item.netBalance >= 0
                          ? AppColors.success
                          : AppColors.danger,
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLedgerRow(
    String title,
    String val,
    Color color, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            val,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final net = _userBalance?.netBalance ?? 0.0;
    final totalOwedToYou = _userBalance?.totalOwedToUser ?? 0.0;
    final totalYouOwe = _userBalance?.totalUserOwes ?? 0.0;
    final balances = _userBalance?.friendBalances ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Shared Expenses & Splits'),
        actions: [
          IconButton(
            tooltip: 'Add Contact',
            icon: const Icon(Icons.person_add_outlined, size: 20),
            onPressed: _showAddFriendDialog,
          ),
          IconButton(
            tooltip: 'Settle Up',
            icon: const Icon(Icons.swap_horiz_rounded, size: 22),
            onPressed: () => _showSettleUpDialog(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
          tabs: const [
            Tab(text: 'Balances'),
            Tab(text: 'Settlements'),
            Tab(text: 'Contacts'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // ─── TAB 1: BALANCES ─────────────────────────────────────────
                RefreshIndicator(
                  onRefresh: () => _loadAllData(forceRefresh: true),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    children: [
                      // Net Balance Overview Banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusMedium,
                          ),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Text(
                              net >= 0
                                  ? 'You are overall owed'
                                  : 'You overall owe',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              currencyFormatter.format(net.abs()),
                              style: TextStyle(
                                color: net >= 0
                                    ? AppColors.success
                                    : AppColors.danger,
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Divider(height: 1, color: AppColors.border),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text(
                                      'Owed to You',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      currencyFormatter.format(totalOwedToYou),
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: AppColors.border,
                                ),
                                Column(
                                  children: [
                                    const Text(
                                      'You Owe',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      currencyFormatter.format(totalYouOwe),
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Friend Debts List
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Contacts & Balances',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          TextButton(
                            onPressed: () => _showSettleUpDialog(),
                            child: const Text(
                              'Settle Up',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (balances.isEmpty && _friends.isEmpty)
                        _buildEmptyBalances()
                      else if (balances.isEmpty)
                        ..._friends.map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _FriendBalanceCard(
                              item: FriendBalanceItemModel(
                                friendName: f.name,
                                friendId: f.id,
                                netBalance: 0.0,
                                totalOwedByFriend: 0.0,
                                totalSettledByFriend: 0.0,
                                totalOwedByUser: 0.0,
                                totalSettledByUser: 0.0,
                                status: 'settled',
                              ),
                              onTap: () => _showFriendLedger(
                                FriendBalanceItemModel(
                                  friendName: f.name,
                                  friendId: f.id,
                                  netBalance: 0.0,
                                  totalOwedByFriend: 0.0,
                                  totalSettledByFriend: 0.0,
                                  totalOwedByUser: 0.0,
                                  totalSettledByUser: 0.0,
                                  status: 'settled',
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        ...balances.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _FriendBalanceCard(
                              item: item,
                              onTap: () => _showFriendLedger(item),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ─── TAB 2: SETTLEMENTS HISTORY ──────────────────────────────
                RefreshIndicator(
                  onRefresh: () => _loadAllData(forceRefresh: true),
                  child: _settlements.isEmpty
                      ? _buildEmptySettlements()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                          itemCount: _settlements.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final s = _settlements[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceCard,
                                borderRadius: BorderRadius.circular(
                                  AppTokens.radiusMedium,
                                ),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Center(
                                      child: Icon(
                                        Icons.check_circle_outline_rounded,
                                        color: AppColors.success,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${s.payerName} paid ${s.payeeName}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          DateFormat('dd MMM yyyy, hh:mm a')
                                              .format(s.createdAt),
                                          style: const TextStyle(
                                            color: AppColors.textTertiary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    s.formattedAmount,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // ─── TAB 3: CONTACTS & FRIENDS ───────────────────────────────
                RefreshIndicator(
                  onRefresh: () => _loadAllData(forceRefresh: true),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'All Contacts (${_friends.length})',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          OutlinedButton(
                            onPressed: _showAddFriendDialog,
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTokens.radiusSmall,
                                ),
                              ),
                            ),
                            child: const Text(
                              'Add Contact',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_friends.isEmpty)
                        _buildEmptyFriends()
                      else
                        ..._friends.map(
                          (f) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceCard,
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusMedium,
                              ),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(
                                      AppTokens.radiusSmall,
                                    ),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Center(
                                    child: Text(
                                      f.name.isNotEmpty
                                          ? f.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        f.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (f.email != null)
                                        Text(
                                          f.email!,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      if (f.phone != null)
                                        Text(
                                          f.phone!,
                                          style: const TextStyle(
                                            color: AppColors.textTertiary,
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: AppColors.textTertiary,
                                  ),
                                  onPressed: () async {
                                    try {
                                      await ApiService.deleteFriend(f.id);
                                      _loadAllData();
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            SnackBar(
                                              content: Text('Failed: $e'),
                                              backgroundColor: AppColors.danger,
                                            ),
                                          );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyBalances() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Text(
            'No Active Shared Balances',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Split an expense or add contacts to track balances.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _showAddFriendDialog,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
              ),
            ),
            child: const Text(
              'Add Contact',
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySettlements() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'No Settlements Recorded',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              'Recorded settlement transactions will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFriends() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: const [
          Text(
            'No Contacts Added Yet',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            'Add contacts to quickly split expenses with friends.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DirectionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DirectionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceElevated,
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

class _FriendBalanceCard extends StatelessWidget {
  final FriendBalanceItemModel item;
  final VoidCallback onTap;

  const _FriendBalanceCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final owesYou = item.netBalance > 0;
    final youOwe = item.netBalance < 0;
    final color = owesYou
        ? AppColors.success
        : (youOwe ? AppColors.danger : AppColors.textSecondary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Text(
                  item.friendName.isNotEmpty
                      ? item.friendName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.friendName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    owesYou ? 'Owes you' : (youOwe ? 'You owe' : 'Settled up'),
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${item.netBalance.abs().toStringAsFixed(0)}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Ledger',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
