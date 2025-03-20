import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:intl/intl.dart'; // Import for NumberFormat
import 'add_savings_goal_screen.dart';
import 'dashboard_screen.dart';
import 'transactions_screen.dart';
import 'reminders_screen.dart';
import 'reports_screen.dart';
import 'about_screen.dart';
import 'settings_screen.dart';
import '../models/savings_goal_model.dart';
import '../models/user_profile.dart';

class SavingsGoalsScreen extends StatefulWidget {
  const SavingsGoalsScreen({super.key});

  @override
  _SavingsGoalsScreenState createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends State<SavingsGoalsScreen>
    with SingleTickerProviderStateMixin {
  late Box<SavingsGoalModel> savingsBox;
  String userName = "User"; // Replace with actual user data
  final DraggableScrollableController _draggableController =
      DraggableScrollableController();
  bool _isSheetExpanded = false;

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
  }

  Future<Box<SavingsGoalModel>> _initializeSavingsBox() async {
    savingsBox = await Hive.openBox<SavingsGoalModel>('savingsBox');
    return savingsBox;
  }

  // Helper function to format numbers with commas
  String _formatNumber(double number) {
    final formatter = NumberFormat("#,###");
    return formatter.format(number);
  }

  void _showAddSavingsDialog(BuildContext context, SavingsGoalModel goal) {
    TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Add Savings",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Enter amount (TZS)",
              hintText: "e.g., ${_formatNumber(10000)}",
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel", style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: Text("Save"),
              onPressed: () {
                double amount = double.tryParse(amountController.text) ?? 0;
                if (amount > 0) {
                  setState(() {
                    goal.savedAmount += amount;
                    goal.savingsEntries.add({
                      "amount": amount,
                      "date": DateTime.now().toString(),
                    });
                    savingsBox.put(goal.key, goal);
                  });
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, SavingsGoalModel goal) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete Savings Goal",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          content: Text("Are you sure you want to delete this savings goal?"),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel", style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text("Delete"),
              onPressed: () {
                savingsBox.delete(goal.key);
                setState(() {});
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var settingsBox = Hive.box<UserProfile>('settings');
    var userProfile = settingsBox.getAt(0) ??
        UserProfile(name: 'User', preferredCurrency: 'USD');

    final screenHeight = MediaQuery.of(context).size.height;
    final bottomNavBarHeight = kBottomNavigationBarHeight;
    final quarterScreenHeight = screenHeight / 4;

    // Adjust these factors to make the icons slightly visible
    double _initialChildSizeFactor = (bottomNavBarHeight + 15) / screenHeight;
    double _minChildSizeFactor = (bottomNavBarHeight + 15) / screenHeight;
    double _quarterScreenFactor = quarterScreenHeight / screenHeight;

    return FutureBuilder<Box<SavingsGoalModel>>(
      future: _initializeSavingsBox(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color.fromARGB(255, 196, 228, 253),
            body: Center(child: CircularProgressIndicator()),
          );
        } else {
          savingsBox = snapshot.data!;
          return Scaffold(
            body: Stack(
              children: [
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 12.0),
                        child: Text(
                          "Savings Goals",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ),
                      Expanded(
                        child: ValueListenableBuilder(
                          valueListenable: savingsBox.listenable(),
                          builder: (context, Box<SavingsGoalModel> box, _) {
                            var savingsList =
                                box.values.toList().reversed.toList();

                            if (savingsList.isEmpty) {
                              return Center(
                                child: Text("No savings added yet!",
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.grey)),
                              );
                            }

                            return ListView.builder(
                              itemCount: savingsList.length,
                              itemBuilder: (context, index) {
                                var saving = savingsList[index];
                                double progress = (saving.savedAmount /
                                        saving.targetAmount)
                                    .clamp(0.0, 1.0) *
                                    100;

                                return Card(
                                  elevation: 6,
                                  margin: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                  shadowColor:
                                      Colors.black.withOpacity(0.15),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(saving.title,
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 22)),
                                        SizedBox(height: 5),
                                        Text(
                                            "Target: ${_formatNumber(saving.targetAmount)} TZS",
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.blue)),
                                        Text(
                                            "Saved: ${_formatNumber(saving.savedAmount)} TZS",
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.green)),
                                        Text(
                                            "Saving Amount: ${_formatNumber(saving.savingAmount)} TZS",
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.blue)),
                                        Text("Frequency: ${saving.frequency}",
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.orange)),
                                        SizedBox(height: 10),
                                        LinearProgressIndicator(
                                          value: progress / 100,
                                          backgroundColor:
                                              const Color.fromARGB(255, 196, 228, 253),
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.blue),
                                        ),
                                        SizedBox(height: 5),
                                        Text(
                                            "Progress: ${progress.toStringAsFixed(2)}%",
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.purple)),
                                        SizedBox(height: 15),
                                        SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            IconButton(
                                                icon: Icon(Icons.add,
                                                    color: Colors.green),
                                                onPressed: () =>
                                                    _showAddSavingsDialog(
                                                        context, saving)),
                                            IconButton(
                                                icon: Icon(Icons.edit,
                                                    color: Colors.blue),
                                                onPressed: () {
                                                  Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              AddSavingsGoalScreen(
                                                                isEdit: true,
                                                                goal: saving,
                                                              )));
                                                }),
                                            IconButton(
                                                icon: Icon(Icons.delete,
                                                    color: Colors.redAccent),
                                                onPressed: () {
                                                  _confirmDelete(
                                                      context, saving);
                                                }),
                                          ],
                                        ),
                                        Text("Recent Savings:",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: Colors.blue)),
                                        ...saving.savingsEntries.reversed.map((entry) {
                                          return Dismissible(
                                            key: ValueKey(entry),
                                            direction:
                                                DismissDirection.startToEnd,
                                            onDismissed: (direction) {
                                              setState(() {
                                                saving.savingsEntries.remove(entry);

                                                double totalSaved = 0;
                                                for (var e in saving.savingsEntries) {
                                                  totalSaved += e['amount'];
                                                }
                                                saving.savedAmount = totalSaved;
                                                savingsBox.put(
                                                    saving.key, saving);
                                              });
                                            },
                                            background:
                                                Container(color: Colors.red),
                                            child: GestureDetector(
                                              onTap: () {
                                                _showEditSavingDialog(
                                                    context, saving, entry);
                                              },
                                              child: ListTile(
                                                leading: Icon(
                                                    Icons.monetization_on,
                                                    color: Colors.green),
                                                title: Text(
                                                    "+${_formatNumber(entry['amount'])} TZS",
                                                    style: TextStyle(
                                                        color: Colors.green,
                                                        fontSize: 16)),
                                                subtitle: Text("${entry['date']}",
                                                    style: TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 14)),
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ).animate().scale();
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
                              return InkWell(
                                onTap: () {
                                  if (item['route'] != null) {
                                    if (item['route'] == '/dashboard') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => DashboardScreen()),
                                      );
                                    } else if (item['route'] == '/transactions') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => TransactionsScreen()),
                                      );
                                    } else if (item['route'] == '/savings') {
                                      // No need to navigate if already on the SavingsGoalsScreen
                                      _draggableController.animateTo(
                                        _minChildSizeFactor,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                      setState(() {
                                        _isSheetExpanded = false;
                                      });
                                    } else if (item['route'] == '/reminders') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => RemindersScreen()),
                                      );
                                    } else if (item['route'] == '/reports') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ReportsExportScreen(reportSettingsBox: settingsBox),
                                        ),
                                      );
                                    } else if (item['route'] == '/about') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AboutScreen(settingsBox: settingsBox),
                                        ),
                                      );
                                    } else if (item['route'] == '/settings') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SettingsScreen(
                                            settingsBox: settingsBox,
                                            onboardingBox: settingsBox,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(item['icon'] as IconData, color: Theme.of(context).primaryColor),
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
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            AddSavingsGoalScreen(isEdit: false)));
              },
              backgroundColor: Colors.blue,
              child: Icon(Icons.add),
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          );
        }
      },
    );
  }

  void _showEditSavingDialog(
      BuildContext context, SavingsGoalModel goal, Map<String, dynamic> entry) {
    TextEditingController amountController =
        TextEditingController(text: entry['amount'].toString());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Edit Savings Entry",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Edit amount (TZS)",
              hintText: "e.g., ${_formatNumber(10000)}",
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel", style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: Text("Save"),
              onPressed: () {
                double newAmount = double.tryParse(amountController.text) ?? 0;
                if (newAmount > 0) {
                  setState(() {
                    entry['amount'] = newAmount;
                    double totalSaved = 0;
                    for (var entry in goal.savingsEntries) {
                      totalSaved += entry['amount'];
                    }
                    goal.savedAmount = totalSaved;
                    savingsBox.put(goal.key, goal);
                  });
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
}