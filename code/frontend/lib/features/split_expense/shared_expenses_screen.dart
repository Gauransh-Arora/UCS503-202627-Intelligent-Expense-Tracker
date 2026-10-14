import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
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

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final balance = await ApiService.calculateUserBalance();
      final settlements = await ApiService.getSettlementHistory();
      final friends = await ApiService.getFriends();

      if (!mounted) return;
      setState(() {
        _userBalance = balance;
        _settlements = settlements;
        _friends = friends;
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
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Add New Friend / Contact',
                        style: Theme.of(context).textTheme.titleLarge),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'e.g., Sarah Jenkins',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address (Optional)',
                    hintText: 'e.g., sarah@example.com',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    hintText: 'e.g., +91 98765 43210',
                  ),
                ),
                const SizedBox(height: 24),
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
                                content: Text('Friend added successfully'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          } catch (e) {
                            setSheetState(() => isSaving = false);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to add friend: $e'),
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
    );
  }

  void _showSettleUpDialog({String? defaultFriendName, double? defaultAmount}) {
    final friendCtrl = TextEditingController(text: defaultFriendName ?? '');
    final amountCtrl = TextEditingController(
      text: defaultAmount != null && defaultAmount > 0 ? defaultAmount.toStringAsFixed(0) : '',
    );
    String direction = 'you_paid'; // 'you_paid' or 'friend_paid'
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Record Settlement',
                        style: Theme.of(context).textTheme.titleLarge),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: friendCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Friend Name',
                    hintText: 'e.g., Alex Carter',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Settlement Amount (INR)',
                    hintText: 'e.g., 500',
                  ),
                ),
                const SizedBox(height: 16),
                Text('Settlement Direction', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('You paid friend'),
                      selected: direction == 'you_paid',
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: direction == 'you_paid' ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (val) {
                        if (val) setSheetState(() => direction = 'you_paid');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Friend paid you'),
                      selected: direction == 'friend_paid',
                      selectedColor: AppColors.success,
                      labelStyle: TextStyle(
                        color: direction == 'friend_paid' ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (val) {
                        if (val) setSheetState(() => direction = 'friend_paid');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: isSaving ? 'Recording...' : 'Save Settlement',
                  onPressed: isSaving
                      ? null
                      : () async {
                          final friend = friendCtrl.text.trim();
                          final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                          if (friend.isEmpty || amount <= 0) return;

                          setSheetState(() => isSaving = true);
                          try {
                            final payer = direction == 'you_paid' ? 'You' : friend;
                            final payee = direction == 'you_paid' ? friend : 'You';

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
                                content: Text('Settlement recorded successfully'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          } catch (e) {
                            setSheetState(() => isSaving = false);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error recording settlement: $e'),
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
    );
  }

  void _showFriendLedger(FriendBalanceItemModel item) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
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
                      Text(item.friendName,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        item.netBalance > 0
                            ? 'Owes you ₹${item.netBalance.toStringAsFixed(0)}'
                            : (item.netBalance < 0
                                ? 'You owe ₹${item.netBalance.abs().toStringAsFixed(0)}'
                                : 'All settled up'),
                        style: TextStyle(
                          color: item.netBalance > 0
                              ? AppColors.success
                              : (item.netBalance < 0 ? AppColors.danger : AppColors.textSecondary),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showSettleUpDialog(
                        defaultFriendName: item.friendName,
                        defaultAmount: item.netBalance.abs(),
                      );
                    },
                    icon: const Icon(Icons.handshake_outlined, size: 16),
                    label: const Text('Settle'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Financial Breakdown with ${item.friendName}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 12),
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
                    const Divider(height: 24),
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
                    const Divider(height: 24),
                    _buildLedgerRow(
                      'Net Balance',
                      item.netBalance >= 0
                          ? '+₹${item.netBalance.toStringAsFixed(0)}'
                          : '-₹${item.netBalance.abs().toStringAsFixed(0)}',
                      item.netBalance >= 0 ? AppColors.success : AppColors.danger,
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

  Widget _buildLedgerRow(String title, String val, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: isBold ? FontWeight.w700 : FontWeight.normal)),
          Text(val, style: TextStyle(fontSize: 15, color: color, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final net = _userBalance?.netBalance ?? 0.0;
    final totalOwedToYou = _userBalance?.totalOwedToUser ?? 0.0;
    final totalYouOwe = _userBalance?.totalUserOwes ?? 0.0;
    final balances = _userBalance?.friendBalances ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Shared Expenses & Splits'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Add Friend',
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: _showAddFriendDialog,
          ),
          IconButton(
            tooltip: 'Settle Up',
            icon: const Icon(Icons.handshake_outlined),
            onPressed: () => _showSettleUpDialog(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Balances'),
            Tab(text: 'Settlements'),
            Tab(text: 'Friends'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // ─── TAB 1: BALANCES ─────────────────────────────────────────
                RefreshIndicator(
                  onRefresh: _loadAllData,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    children: [
                      // Net Balance Overview Banner
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: net >= 0 ? AppColors.successGradient : AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: (net >= 0 ? AppColors.success : AppColors.primary).withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              net >= 0 ? 'You are overall owed' : 'You overall owe',
                              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              currencyFormatter.format(net.abs()),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text('Owed to You', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text(
                                      currencyFormatter.format(totalOwedToYou),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                                  ],
                                ),
                                Container(width: 1, height: 28, color: Colors.white24),
                                Column(
                                  children: [
                                    const Text('You Owe', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text(
                                      currencyFormatter.format(totalYouOwe),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
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
                          Text('Contacts & Balances', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          TextButton.icon(
                            onPressed: () => _showSettleUpDialog(),
                            icon: const Icon(Icons.handshake_outlined, size: 16),
                            label: const Text('Settle Up'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (balances.isEmpty)
                        _buildEmptyBalances()
                      else
                        ...balances.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _FriendBalanceCard(
                                item: item,
                                onTap: () => _showFriendLedger(item),
                              ),
                            )),
                    ],
                  ),
                ),

                // ─── TAB 2: SETTLEMENTS HISTORY ──────────────────────────────
                RefreshIndicator(
                  onRefresh: _loadAllData,
                  child: _settlements.isEmpty
                      ? _buildEmptySettlements()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                          itemCount: _settlements.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final s = _settlements[index];
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceCard,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${s.payerName} paid ${s.payeeName}',
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat('dd MMM yyyy, hh:mm a').format(s.createdAt),
                                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    s.formattedAmount,
                                    style: const TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
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
                  onRefresh: _loadAllData,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('All Contacts (${_friends.length})', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          ElevatedButton.icon(
                            onPressed: _showAddFriendDialog,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Friend'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_friends.isEmpty)
                        _buildEmptyFriends()
                      else
                        ..._friends.map((f) => Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceCard,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.primaryLight,
                                    child: Text(
                                      f.name.isNotEmpty ? f.name[0].toUpperCase() : '?',
                                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                        if (f.email != null)
                                          Text(f.email!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                        if (f.phone != null)
                                          Text(f.phone!, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
                                    onPressed: () async {
                                      try {
                                        await ApiService.deleteFriend(f.id);
                                        _loadAllData();
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.danger),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyBalances() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.group_outlined, color: AppColors.primary, size: 30),
            ),
            const SizedBox(height: 14),
            const Text('No Active Shared Balances', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Add friends or split an expense to start tracking debts.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _showAddFriendDialog,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
              label: const Text('Add Friend Contact'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySettlements() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.handshake_outlined, size: 48, color: AppColors.textTertiary),
            SizedBox(height: 14),
            Text('No Settlements Recorded', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('When participants settle their shared balances, records will show up here.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFriends() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(Icons.contacts_outlined, size: 44, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            const Text('No Contacts Added Yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Add friends to easily split expenses and track shared debts.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
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
    final color = owesYou ? AppColors.success : (youOwe ? AppColors.danger : AppColors.textSecondary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Text(
                item.friendName.isNotEmpty ? item.friendName[0].toUpperCase() : '?',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.friendName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                    owesYou ? 'Owes you' : (youOwe ? 'You owe' : 'Settled up'),
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'View Ledger >',
                  style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
