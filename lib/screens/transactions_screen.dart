import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../models/user_profile.dart';
import '../screens/add_transaction_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/savings_goals_screen.dart';
import '../screens/reminders_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/about_screen.dart';
import '../screens/settings_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  _TransactionsScreenState createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late Box<TransactionModel> transactionBox;
  late AnimationController _fabAnimationController;
  final DraggableScrollableController _draggableController = DraggableScrollableController();
  bool _isSheetExpanded = false;

  // State variables for filters
  String? selectedCategory;
  DateTime? startDate;
  DateTime? endDate;
  bool _isFilterExpanded = false; // Controls filter section visibility

  final List<Map<String, dynamic>> _navigationItems = [
    {'icon': Icons.dashboard, 'label': 'Dashboard', 'route': '/dashboard'},
    {'icon': Icons.swap_horiz, 'label': 'Transactions', 'route': '/transactions'},
    {'icon': Icons.savings, 'label': 'Savings Goals', 'route': '/savings'},
    {'icon': Icons.alarm, 'label': 'Reminders', 'route': '/reminders'},
    {'icon': Icons.bar_chart, 'label': 'Reports', 'route': '/reports'},
    {'icon': Icons.info, 'label': 'About', 'route': '/about'},
    {'icon': Icons.settings, 'label': 'Settings', 'route': '/settings'},
  ];

  @override
  void initState() {
    super.initState();
    transactionBox = Hive.box<TransactionModel>('transactions');
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  // Helper function to format numbers with commas
  String _formatNumber(double number) {
    final formatter = NumberFormat("#,###");
    return formatter.format(number);
  }

  @override
  Widget build(BuildContext context) {
    var settingsBox = Hive.box<UserProfile>('settings');
    var userProfile = settingsBox.getAt(0) ?? UserProfile(name: 'User', preferredCurrency: 'USD');

    // Get unique categories from transactions
    var categories = transactionBox.values.map((t) => t.category).toSet().toList();
    categories.insert(0, 'All'); // Add 'All' option

    final screenHeight = MediaQuery.of(context).size.height;
    final bottomNavBarHeight = kBottomNavigationBarHeight;
    final quarterScreenHeight = screenHeight / 4;

    double _initialChildSizeFactor = bottomNavBarHeight / screenHeight;
    double _minChildSizeFactor = bottomNavBarHeight / screenHeight;
    double _quarterScreenFactor = quarterScreenHeight / screenHeight;

    return Scaffold(
      backgroundColor: Colors.blue.shade200,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Spendings & Income Transactions",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                // Filter Section
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: _isFilterExpanded ? 150 : 0,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: Offset(0, 3), // Shadow position
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [


                        // Category Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          hint: Text('Select Category'),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedCategory = newValue;
                            });
                          },
                          items: categories.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.blue.shade50,
                          ),
                        ),
                        SizedBox(height: 10),
                        // Date Range Picker
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final DateTimeRange? picked = await showDateRangePicker(
                                    context: context,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2101),
                                    initialDateRange: DateTimeRange(
                                      start: startDate ?? DateTime.now(),
                                      end: endDate ?? DateTime.now(),
                                    ),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      startDate = picked.start;
                                      endDate = picked.end;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text(
                                        startDate == null || endDate == null
                                            ? "Select Date Range"
                                            : "${DateFormat.yMMMd().format(startDate!)} - ${DateFormat.yMMMd().format(endDate!)}",
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Toggle Filter Button
                InkWell(
                  onTap: () {
                    setState(() {
                      _isFilterExpanded = !_isFilterExpanded;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    color: Colors.blue.shade50,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isFilterExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: Colors.blue.shade200,
                        ),
                        SizedBox(width: 8),
                        Text(
                          _isFilterExpanded ? "Hide Filters" : "Show Filters",
                          style: TextStyle(color: Colors.blue.shade200, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                // Transaction List
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: transactionBox.listenable(),
                    builder: (context, Box<TransactionModel> box, _) {
                      if (box.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.money_off, size: 60, color: Colors.grey),
                              SizedBox(height: 16),
                              Text("No transactions yet. Add some!",
                                  style: TextStyle(fontSize: 18, color: Colors.grey)),
                            ],
                          ),
                        );
                      }

                      // Apply filters
                      var filteredTransactions = box.values.toList().where((transaction) {
                        bool categoryMatch = selectedCategory == null || selectedCategory == 'All' || transaction.category == selectedCategory;
                        bool dateMatch = startDate == null || endDate == null ||
                            (transaction.date.isAfter(startDate!) && transaction.date.isBefore(endDate!));
                        return categoryMatch && dateMatch;
                      }).toList();

                      var reversedTransactions = filteredTransactions.reversed.toList();

                      return ListView.builder(
                        padding: EdgeInsets.all(12),
                        itemCount: reversedTransactions.length,
                        itemBuilder: (context, index) {
                          TransactionModel transaction = reversedTransactions[index];
                          return _buildTransactionItem(transaction);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTapDown: (details) {
                _draggableController.animateTo(
                  _quarterScreenFactor,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                setState(() {
                  _isSheetExpanded = true;
                });
              },
              child: DraggableScrollableSheet(
                controller: _draggableController,
                initialChildSize: _initialChildSizeFactor,
                minChildSize: _minChildSizeFactor,
                maxChildSize: _quarterScreenFactor,
                snap: true,
                snapSizes: [_initialChildSizeFactor, _quarterScreenFactor],
                builder: (BuildContext context, ScrollController scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10.0,
                          spreadRadius: 0.5,
                          offset: Offset(0.0, -2.0),
                        ),
                      ],
                    ),
                    child: GridView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(10),
                      itemCount: _navigationItems.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.2,
                      ),
                      itemBuilder: (context, index) {
                        final item = _navigationItems[index];
                        return IgnorePointer(
                          ignoring: !_isSheetExpanded,
                          child: InkWell(
                            onTap: () {
                              if (item['route'] != null) {
                                if (item['route'] == '/dashboard') {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => DashboardScreen()),
                                  );
                                } else if (item['route'] == '/transactions') {
                                  _draggableController.animateTo(
                                    _minChildSizeFactor,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                  setState(() {
                                    _isSheetExpanded = false;
                                  });
                                } else if (item['route'] == '/savings') {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => SavingsGoalsScreen()),
                                  );
                                } else if (item['route'] == '/reminders') {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => RemindersScreen()),
                                  );
                                } else if (item['route'] == '/reports') {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => ReportsExportScreen(reportSettingsBox: settingsBox)),
                                  );
                                } else if (item['route'] == '/about') {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => AboutScreen(settingsBox: settingsBox)),
                                  );
                                } else if (item['route'] == '/settings') {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => SettingsScreen(settingsBox: settingsBox, onboardingBox: settingsBox)),
                                  );
                                }
                              }
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(item['icon'] as IconData,
                                    color: Theme.of(context).primaryColor),
                                const SizedBox(height: 5),
                                Text(
                                  item['label'] as String,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          _fabAnimationController.forward();
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddTransactionScreen()),
          );
          _fabAnimationController.reverse();
          setState(() {}); // Refresh the UI after adding a transaction
        },
        backgroundColor: Colors.blue.shade200,
        elevation: 6,
        child: Icon(Icons.add, size: 30),
      ),
    );
  }

  Widget _buildTransactionItem(TransactionModel transaction) {
    String formattedTime = DateFormat('h:mm a').format(transaction.date);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddTransactionScreen(
              transaction: transaction,
              transactionIndex: transactionBox.values.toList().indexWhere((t) => t.id == transaction.id),
            ),
          ),
        );
        setState(() {});
      },
      child: Card(
        elevation: 5,
        margin: EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: Offset(0, 3), // Shadow position
              ),
            ],
          ),
          child: Dismissible(
            key: Key(transaction.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: EdgeInsets.only(right: 20),
              child: Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (direction) {
              transactionBox.deleteAt(transactionBox.values.toList().indexWhere((t) => t.id == transaction.id));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Transaction deleted")));
            },
            confirmDismiss: (direction) async {
              return await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text("Confirm Delete"),
                    content: Text("Are you sure you want to delete this transaction?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text("Cancel")),
                      TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text("Delete", style: TextStyle(color: Colors.red))),
                    ],
                  );
                },
              );
            },
            child: ListTile(
              leading: Icon(
                transaction.isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                color: transaction.isIncome ? Colors.green : Colors.red,
                size: 30,
              ),
              title: Text(
                transaction.category,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        DateFormat.yMMMd().format(transaction.date),
                        style: TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(width: 8),
                      Text(
                        formattedTime,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    transaction.notes,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              trailing: Text(
                'Tsh ${_formatNumber(transaction.amount.abs())}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: transaction.isIncome ? Colors.green : Colors.red),
              ),
            ),
          ),
        ),
      ),
    );
  }
}