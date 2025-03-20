import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../screens/transactions_screen.dart';
import '../screens/savings_goals_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/reminders_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/about_screen.dart';
import '../models/transaction_model.dart';
import '../models/savings_goal_model.dart';
import '../models/user_profile.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Box<TransactionModel> _transactionBox;
  late Future<Box<SavingsGoalModel>> _savingsBoxFuture;
  Box<SavingsGoalModel>? _savingsBox;
  bool _isBalanceVisible = false;
  bool _isSavingsVisible = false;
  final LocalAuthentication _localAuth = LocalAuthentication();
  String userName = "Guest";
  String _selectedTimeFrame = "3M";
  int _currentIndex = 0;
  File? _profileImage;
  UserProfile? _userProfile;

  final List<Map<String, dynamic>> _navigationItems = [
    {'icon': Icons.dashboard, 'label': 'Dashboard', 'route': '/dashboard'},
    {'icon': Icons.swap_horiz, 'label': 'Transactions', 'route': '/transactions'},
    {'icon': Icons.savings, 'label': 'Savings Goals', 'route': '/savings'},
    {'icon': Icons.alarm, 'label': 'Reminders', 'route': '/reminders'},
    {'icon': Icons.bar_chart, 'label': 'Reports', 'route': '/reports'},
    {'icon': Icons.info, 'label': 'About', 'route': '/about'},
    {'icon': Icons.settings, 'label': 'Settings', 'route': '/settings'},
  ];

  final DraggableScrollableController _draggableController = DraggableScrollableController();
  bool _isSheetExpanded = false;

  @override
void initState() {
  super.initState();
  _transactionBox = Hive.box<TransactionModel>('transactions');
  _savingsBoxFuture = _openSavingsBox().then((box) {
    if (mounted) {
      setState(() {
        _savingsBox = box;
      });
    }
    return box;
  });
  _checkBiometricSetting();
  _loadUserProfile();
}

  Future<Box<SavingsGoalModel>> _openSavingsBox() async {
    try {
      return await Hive.openBox<SavingsGoalModel>('savingsBox');
    } catch (e) {
      print("Error opening savingsGoal box: $e");
      rethrow;
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      var settingsBox = await Hive.openBox<UserProfile>('settings');
      if (settingsBox.isNotEmpty) {
        setState(() {
          _userProfile = settingsBox.getAt(0)!;
          userName = _userProfile?.name ?? "Guest";
          if (_userProfile!.profileImagePath != null) {
            _profileImage = File(_userProfile!.profileImagePath!);
          }
        });
      } else {
        setState(() {
          _userProfile = UserProfile(
            name: 'User',
            preferredCurrency: 'TZS',
            isDarkMode: false,
            language: 'en',
          );
          userName = 'User';
        });
        await settingsBox.add(_userProfile!);
      }
    } catch (e) {
      print("Error loading user profile: $e");
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final newFile = File('${appDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await File(pickedFile.path).copy(newFile.path);
        setState(() {
          _profileImage = newFile;
          _userProfile!.profileImagePath = newFile.path;
          Hive.box<UserProfile>('settings').putAt(0, _userProfile!);
        });
      } catch (e) {
        debugPrint("Error saving image: $e");
      }
    }
  }

  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SizedBox(
        height: 150,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                _pickImage(ImageSource.camera);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Choose from Gallery'),
              onTap: () {
                _pickImage(ImageSource.gallery);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _checkBiometricSetting() async {
    var box = await Hive.openBox('userSettings');
    bool isBiometricEnabled = box.get('biometricEnabled', defaultValue: false);

    if (isBiometricEnabled) {
      bool canAuthenticate = await _localAuth.canCheckBiometrics;
      if (canAuthenticate) {
        setState(() {
          _isBalanceVisible = false;
        });
      }
    } else {
      setState(() {
        _isBalanceVisible = true;
      });
    }
  }

  void _authenticateForSavings() async {
    bool authenticated = false;
    try {
      authenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to view your savings',
        options: AuthenticationOptions(
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      print('Error during authentication: $e');
    }

    if (authenticated) {
      setState(() {
        _isSavingsVisible = true;
      });
    }
  }

  double getBalance() {
    double balance = 0;
    for (var transaction in _transactionBox.values) {
      balance += transaction.amount;
    }
    return balance;
  }

  double getSavingsBalance() {
    final savingsBox = _savingsBox;
    if (savingsBox == null) {
      return 0;
    }

    double totalSavings = 0;
    for (var savings in savingsBox.values) {
      totalSavings += savings.savedAmount;
    }
    return totalSavings;
  }

  List<FlSpot> _getSavingsSpots() {
  final savingsBox = _savingsBox;
  if (savingsBox?.isEmpty ?? true) {
    print("Savings box is empty or not initialized! in _getSavingsSpots");
    return [FlSpot(0, 0)];
  }

  List<FlSpot> spots = [];
  double cumulativeSavings = 0;

  var savingsGoals = savingsBox?.values.toList() ?? [];
  savingsGoals.sort((a, b) => a.dateTime.compareTo(b.dateTime));

  if (savingsGoals.isNotEmpty) {
    final double minX = savingsGoals.first.dateTime.millisecondsSinceEpoch.toDouble();
    double maxXValue = savingsGoals.last.dateTime.millisecondsSinceEpoch.toDouble();

    // Avoid division by zero
    double range = maxXValue - minX;
    if (range == 0) {
      // If all dates are the same, use index as xValue
      for (int i = 0; i < savingsGoals.length; i++) {
        cumulativeSavings += savingsGoals[i].savedAmount;
        spots.add(FlSpot(i.toDouble(), cumulativeSavings));
      }
    } else {
      // Normalize xValue between 0 and 1
      for (final goal in savingsGoals) {
        cumulativeSavings += goal.savedAmount;
        double xValue = (goal.dateTime.millisecondsSinceEpoch.toDouble() - minX) / range;
        spots.add(FlSpot(xValue, cumulativeSavings));
      }
    }
  } else {
    print("savingsGoals is empty after fetching from savingsBox.");
  }

  print("Generated spots: $spots");
  return spots;
}

  List<TransactionModel> getTransactions() {
    var transactions = _transactionBox.values.toList();
    transactions.sort((a, b) => b.date.compareTo(a.date));
    return transactions;
  }

  List<PieChartSectionData> getPieChartSections() {
    List<PieChartSectionData> sections = [];
    Map<String, double> categoryTotals = {};
    double totalExpenses = 0;

    for (var transaction in _transactionBox.values) {
      if (!transaction.isIncome) {
        String category = transaction.category ?? 'Other';
        categoryTotals[category] =
            (categoryTotals[category] ?? 0) + transaction.amount.abs();
        totalExpenses += transaction.amount.abs();
      }
    }

    if (categoryTotals.isNotEmpty && totalExpenses > 0) {
      categoryTotals.forEach((category, total) {
        double percentage = (total / totalExpenses) * 100;
        sections.add(
          PieChartSectionData(
            value: total,
            color: _getRandomColor(),
            title: '$category\n${percentage.toStringAsFixed(1)}%',
            radius: 70,
            titleStyle: const TextStyle(
              fontSize: 12,
              color: Colors.black,
              fontFamily: 'Noto Sans',
            ),
          ),
        );
      });
    }

    return sections;
  }

  Color _getRandomColor() {
    return Color(0xFF000000 + Random().nextInt(0xFFFFFF));
  }

  Future<void> _authenticate() async {
    if (_isBalanceVisible) {
      setState(() {
        _isBalanceVisible = false;
      });
      return;
    }

    bool authenticated = false;
    try {
      bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      bool isDeviceSupported = await _localAuth.isDeviceSupported();

      if (canCheckBiometrics && isDeviceSupported) {
        authenticated = await _localAuth.authenticate(
          localizedReason: 'Please authenticate to view your balance',
          options: AuthenticationOptions(
            stickyAuth: true,
            useErrorDialogs: true,
          ),
        );
      } else {
        authenticated = true;
      }
    } catch (e) {
      print('Error during authentication: $e');
      authenticated = true;
    }

    if (authenticated) {
      setState(() {
        _isBalanceVisible = true;
      });
    }
  }

  String _getGreeting() {
  var hour = DateTime.now().hour;

  if (hour >= 0 && hour < 4) {
    return "It's Midnight 🌃";
  } else if (hour >= 4 && hour < 5) {
    return "Still Late Night 🥱";
  } else if (hour >= 5 && hour < 12) {
    return "Good Morning ☀️";
  } else if (hour >= 12 && hour < 17) {
    return "Good Afternoon 🌤️";
  } else if (hour >= 17 && hour < 20) {
    return "Good Evening 🌇";
  } else {
    return "Good Night 🌙";
  }
}

  Widget _buildUserProfileCard(BuildContext context) {
    final greeting = _getGreeting();
    final formattedUsername = userName;
    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontFamily: 'Noto Sans',
                    ),
                  ),
                  Text(
                    formattedUsername,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Noto Sans',
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _showImagePickerDialog,
              child: CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey[300],
                backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                child: _profileImage == null
                    ? Icon(Icons.person, color: Theme.of(context).primaryColor, size: 30)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat("#,##0.00", "en_US");
    List<PieChartSectionData> pieChartSections = getPieChartSections();

    final screenHeight = MediaQuery.of(context).size.height;
    final bottomNavBarHeight = kBottomNavigationBarHeight;
    final quarterScreenHeight = screenHeight / 4;

    double _initialChildSizeFactor = bottomNavBarHeight / screenHeight;
    double _minChildSizeFactor = bottomNavBarHeight / screenHeight;
    double _quarterScreenFactor = quarterScreenHeight / screenHeight;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 196, 228, 253),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserProfileCard(context),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: _buildBalanceCard(currencyFormat),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: FutureBuilder<Box<SavingsGoalModel>>(
                            future: _savingsBoxFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const CircularProgressIndicator();
                              } else if (snapshot.hasError) {
                                return Text("Error loading savings box: ${snapshot.error}");
                              } else if (snapshot.hasData) {
                                _savingsBox = snapshot.data!;
                                return _buildSavingsCard(currencyFormat);
                              } else {
                                return const Text("No data available");
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildRecentTransactions(currencyFormat),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildSpendingPieChart(pieChartSections),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: FutureBuilder<Box<SavingsGoalModel>>(
                      future: _savingsBoxFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        } else if (snapshot.hasError) {
                          return Text("Error loading savings box: ${snapshot.error}");
                        } else if (snapshot.hasData) {
                          _savingsBox = snapshot.data!;
                          return _buildSavingsProgressChart();
                        } else {
                          return const Text("No savings data available");
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildMotivationalMessage(),
                  ),
                  SizedBox(height: quarterScreenHeight),
                ],
              ),
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
                    decoration: BoxDecoration(
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
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                                Navigator.pushReplacementNamed(context, item['route']);
                              }
                              setState(() {
                                _currentIndex = index;
                              });
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(item['icon'] as IconData,
                                    color: _currentIndex == index ? Theme.of(context).primaryColor : Colors.grey),
                                const SizedBox(height: 5),
                                Text(
                                  item['label'] as String,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _currentIndex == index ? Theme.of(context).primaryColor : Colors.grey,
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
    );
  }

  Widget _buildBalanceCard(NumberFormat currencyFormat) {
    double balance = getBalance();
    return _buildCard(
      title: "Your Balance",
      balance: balance,
      isVisible: _isBalanceVisible,
      onVisibilityToggle: _authenticate,
      currencyFormat: currencyFormat,
    );
  }

  Widget _buildSavingsCard(NumberFormat currencyFormat) {
    double savingsBalance = getSavingsBalance();
    return _buildCard(
      title: "Your Savings",
      balance: savingsBalance,
      isVisible: _isSavingsVisible,
      onVisibilityToggle: () {
        setState(() {
          _isSavingsVisible = !_isSavingsVisible;
        });
      },
      currencyFormat: currencyFormat,
    );
  }

  Widget _buildCard({
    required String title,
    required double balance,
    required bool isVisible,
    required VoidCallback onVisibilityToggle,
    required NumberFormat currencyFormat,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double maxWidth = constraints.maxWidth;
        double cardWidth = maxWidth > 600 ? 300 : maxWidth * 0.45;
        double fontSize = maxWidth > 600 ? 18 : maxWidth * 0.04;

        return SizedBox(
          width: cardWidth,
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, fontFamily: 'Noto Sans'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      isVisible
                          ? AnimatedDefaultTextStyle(
                              style: TextStyle(
                                fontSize: fontSize * 0.9,
                                fontWeight: FontWeight.bold,
                                color: balance >= 0 ? Colors.green : Colors.red,
                                fontFamily: 'Noto Sans',
                              ),
                              duration: const Duration(milliseconds: 300),
                              child: Text("TZS ${currencyFormat.format(balance)}"),
                            )
                          : Text(
                              "TZS ****",
                              style: TextStyle(
                                fontSize: fontSize * 0.9,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                fontFamily: 'Noto Sans',
                              ),
                            ),
                      IconButton(
                        icon: Icon(
                          isVisible ? Icons.visibility : Icons.visibility_off,
                          color: Theme.of(context).primaryColor,
                        ),
                        onPressed: onVisibilityToggle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentTransactions(NumberFormat currencyFormat) {
    List<TransactionModel> transactions = getTransactions();
    List<TransactionModel> recentTransactions = transactions.take(5).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Recent Transactions",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Noto Sans'),
            ),
            const SizedBox(height: 8),
            recentTransactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "No transactions yet.",
                          style: TextStyle(fontSize: 16, color: Colors.grey, fontFamily: 'Noto Sans'),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          "To start adding transactions, please go to the",
                          style: TextStyle(fontSize: 14, color: Colors.grey[600], fontFamily: 'Noto Sans'),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          "'Transactions' option in the menu below.",
                          style: TextStyle(fontSize: 14, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Noto Sans'),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          "(It's the icon with the horizontal arrows).",
                          style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: 'Noto Sans'),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: recentTransactions.length,
                        itemBuilder: (context, index) {
                          final transaction = recentTransactions[index];
                          String formattedTime = DateFormat('HH:mm').format(transaction.date);
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              leading: Icon(
                                transaction.isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                                color: transaction.isIncome ? Colors.green : Colors.red,
                              ),
                              title: Text(transaction.category, style: const TextStyle(fontFamily: 'Noto Sans')),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(DateFormat('yyyy-MM-dd').format(transaction.date)),
                                  Text(formattedTime),
                                ],
                              ),
                              trailing: Text(
                                "TZS ${currencyFormat.format(transaction.amount.abs())}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Noto Sans'),
                              ),
                            ),
                          );
                        },
                      ),
                      if (transactions.length > 5)
                        AnimatedOpacity(
                          opacity: 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TransactionsScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                "See More",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Noto Sans',
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpendingPieChart(List<PieChartSectionData> pieChartSections) {
    int touchedIndex = -1;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Spending Breakdown",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Noto Sans',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 300,
              child: pieChartSections.isEmpty
                  ? Center(
                      child: Text(
                        "No expenses recorded yet.",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          fontFamily: 'Noto Sans',
                        ),
                      ),
                    )
                  : PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                touchedIndex = -1;
                                return;
                              }
                              touchedIndex =
                                  pieTouchResponse.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        sections: pieChartSections.asMap().map((index, section) {
                          final isTouched = index == touchedIndex;
                          return MapEntry(
                            index,
                            section.copyWith(
                              radius: isTouched ? 130 : 120,
                              titleStyle: TextStyle(
                                fontSize: isTouched ? 18 : 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                fontFamily: 'Noto Sans',
                              ),
                            ),
                          );
                        }).values.toList(),
                        borderData: FlBorderData(show: false),
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                      swapAnimationDuration: const Duration(milliseconds: 300),
                      swapAnimationCurve: Curves.easeInOut,
                    ),
            ),
          ],
        ),
      ),
    );
  }

    Widget _buildSavingsProgressChart() {
    final savingsBox = _savingsBox;
    if (savingsBox?.isEmpty ?? true) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.bar_chart, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No savings data available',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[600], fontFamily: 'Noto Sans'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Start saving to see your progress here!',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500], fontFamily: 'Noto Sans'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'To start tracking your savings progress, please go to the',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600], fontFamily: 'Noto Sans'),
                  textAlign: TextAlign.center,
                ),
                Text(
                  "'Savings Goals' option in the menu below.",
                  style: TextStyle(fontSize: 14, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Noto Sans'),
                  textAlign: TextAlign.center,
                ),
                Text(
                  "(It's the icon with the piggy bank).",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: 'Noto Sans'),
                  textAlign: TextAlign.center,
                ),
              ],
            )
          ),
        ),
      );
    }

    final savingsData = savingsBox!.values.toList();
    savingsData.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    List<BarChartGroupData> barChartData = [];
    double cumulativeSavings = 0;

    for (int i = 0; i < savingsData.length; i++) {
      cumulativeSavings += savingsData[i].savedAmount;
      barChartData.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: cumulativeSavings,
              color: Colors.blue,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Savings Progress",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[800], fontFamily: 'Noto Sans'),
            ),
            const SizedBox(height: 8),
            Text(
              "Track your cumulative savings over time",
              style: TextStyle(fontSize: 14, color: Colors.grey[600], fontFamily: 'Noto Sans'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: barChartData,
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            DateFormat('MMM').format(savingsData[value.toInt()].dateTime),
                            style: TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Noto Sans'),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Noto Sans'),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget leftTitleWidgetsSavings(double value, TitleMeta meta, double maxY, NumberFormat currencyFormat) {
  const style = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 12,
    color: Colors.black87,
    fontFamily: 'Noto Sans',
  );

  String text;
  if (value == 0) {
    text = currencyFormat.format(0);
  } else if (value == (maxY * 1 / 3)) {
    text = currencyFormat.format((maxY * 1 / 3).toInt());
  } else if (value == (maxY * 2 / 3)) {
    text = currencyFormat.format((maxY * 2 / 3).toInt());
  } else if (value == maxY) {
    text = currencyFormat.format(maxY.toInt());
  } else {
    return Container();
  }

  return SideTitleWidget(
    meta: meta,
    child: Text(text, style: style, textAlign: TextAlign.left),
  );
}

  Widget _buildMotivationalMessage() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Motivational Message", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Noto Sans')),
            SizedBox(height: 8),
            Text(
              "You're doing great! Keep track of your finances, and you'll reach your goals in no time.",
              style: TextStyle(fontSize: 16, fontFamily: 'Noto Sans'),
            ),
          ],
        ),
      ),
    );
  }
}