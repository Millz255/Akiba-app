import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import '../models/transaction_model.dart';
import '../models/savings_goal_model.dart';
import '../screens/dashboard_screen.dart'; // Import DashboardScreen
import '../screens/transactions_screen.dart';
import '../screens/savings_goals_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/about_screen.dart';
import '../screens/reminders_screen.dart'; // Import RemindersScreen
import '../models/user_profile.dart'; // Import UserProfile model

enum ReportType { transactions, savings }

class ReportsExportScreen extends StatefulWidget {
  final Box reportSettingsBox;
  const ReportsExportScreen({super.key, required this.reportSettingsBox});

  @override
  _ReportsExportScreenState createState() => _ReportsExportScreenState();
}

class _ReportsExportScreenState extends State<ReportsExportScreen>
    with SingleTickerProviderStateMixin {
  late DateTimeRange _selectedDateRange;
  late Box _settingsBox;
  bool _isGenerating = false;
  List<TransactionModel> _transactions = []; // Initialize with an empty list
  List<SavingsGoalModel> _savings = []; // Initialize with an empty list
  late AnimationController _controller;
  late Animation<double> _animation;
  String? _selectedCategoryFilter;
  final List<String> _transactionCategories = [
    "Food", "Transport", "Entertainment", "Bills", "House Expenses", "Drinks",
    "Clothes shopping", "Other", "Income", "Salary", "Business Income",
    "Other Income", "Miscellaneous Income"
  ];
  ReportType _selectedReportType = ReportType.transactions;
  String _reportContent = "";
  int _currentIndex = 4; // Index for Reports in _navigationItems
  final DraggableScrollableController _draggableController =
      DraggableScrollableController();
  bool _isSheetExpanded = false; // Add this flag

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
    _settingsBox = widget.reportSettingsBox;

    final startDate = DateTime.fromMillisecondsSinceEpoch(
        _settingsBox.get('startDate') ?? DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch);
    final endDate = DateTime.now();
    _selectedDateRange = DateTimeRange(start: startDate, end: endDate);

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);

    _fetchInitialData();
  }

  Future<void> _pickDateRange() async {
    final DateTime now = DateTime.now();
    final DateTimeRange initialRange = _selectedDateRange ??
        DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);

    final DateTimeRange? result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: initialRange,
    );

    if (result != null) {
      setState(() {
        _selectedDateRange = DateTimeRange(start: result.start, end: result.end);
      });

      await _settingsBox.put('startDate', _selectedDateRange.start.millisecondsSinceEpoch);
      await _settingsBox.put('endDate', _selectedDateRange.end.millisecondsSinceEpoch);

      await _fetchInitialData();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    await Future.wait([_fetchSavingsData(), _fetchTransactionData()]);
  }

  Future<void> _fetchSavingsData() async {
    debugPrint('_fetchSavingsData: Starting');
    try {
      final savingsBox = await Hive.openBox<SavingsGoalModel>('savingsBox');
      final allSavings = savingsBox.values.toList();
      debugPrint('_fetchSavingsData: allSavings.length = ${allSavings.length}');
      final filteredSavings = allSavings.where((saving) {
        return saving.dateTime.isAfter(_selectedDateRange.start) &&
            saving.dateTime.isBefore(_selectedDateRange.end);
      }).toList();
      debugPrint('_fetchSavingsData: filteredSavings.length = ${filteredSavings.length}');
      debugPrint('_fetchSavingsData: _selectedDateRange = ${_selectedDateRange}');

      if (mounted) {
        setState(() {
          _savings = filteredSavings;
        });
      }
      savingsBox.close();
    } catch (e) {
      debugPrint('Error fetching savings data: $e');
    }
    debugPrint('_fetchSavingsData: Ending');
  }

  Future<void> _fetchTransactionData() async {
    try {
      final transactionsBox = Hive.box<TransactionModel>('transactions');
      final allTransactions = transactionsBox.values.toList();
      final filteredTransactions = allTransactions.where((transaction) {
        bool dateFilter = transaction.date.isAfter(_selectedDateRange.start) && transaction.date.isBefore(_selectedDateRange.end);
        bool categoryFilter = _selectedCategoryFilter == null || _selectedCategoryFilter == "All Categories" ||
            transaction.category == _selectedCategoryFilter;
        return dateFilter && categoryFilter;
      }).toList();

      if (mounted) {
        setState(() {
          _transactions = filteredTransactions;
        });
      }
    } catch (e) {
      debugPrint('Error fetching transaction data: $e');
    }
  }

  Future<void> _generateReport() async {
    debugPrint('_generateReport: Starting');
    if (mounted) {
      setState(() {
        _isGenerating = true;
        _reportContent = "";
      });
    }

    String reportText = "Akiba Financial Report\n";
    reportText += "Date Range: ${DateFormat.yMMMd().format(_selectedDateRange.start)} - ${DateFormat.yMMMd().format(_selectedDateRange.end)}\n\n";

    if (_selectedReportType == ReportType.savings) {
      reportText += "Savings Goals\n";
      reportText += _generateSavingsTable();
      reportText += "\n";
      reportText += "Total Savings Progress: Tzs ${_calculateTotalSavings().toStringAsFixed(2)}\n";
    }

    if (_selectedReportType == ReportType.transactions) {
      reportText += "Transactions\n";
      reportText += _generateTransactionsTable();
      reportText += "\n";
      reportText += "Total Income: Tzs ${_calculateTotalIncome().toStringAsFixed(2)}\n";
      reportText += "Total Expenses: Tzs ${_calculateTotalExpenses().toStringAsFixed(2)}\n";
      double _calculateTotalBalance() => _calculateTotalIncome() - _calculateTotalExpenses();
      reportText += "Total Balance: Tzs ${_calculateTotalBalance().toStringAsFixed(2)}\n";
    }
    debugPrint('_generateReport: reportText before setState = \n$reportText');

    if (mounted) {
      setState(() {
        _isGenerating = false;
        _reportContent = reportText;
      });

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => _generatePdfContent(format, reportText),
      );

      _showReportDialog(reportText);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report sent to printer!')),
      );
    }
    debugPrint('_generateReport: Ending');
  }

  String _generateSavingsTable() {
    String table = "";
    table += "--------------------------------------------------------------------\n";
    table += "| Goal Title                 | Saved Amount      | Target Amount    | Progress         |\n";
    table += "--------------------------------------------------------------------\n";
    for (var saving in _savings) {
      double progress = (saving.savedAmount / saving.targetAmount) * 100;
      table += "| ${saving.title.padRight(20)} | Tzs ${saving.savedAmount.toStringAsFixed(2).padLeft(13)} | Tzs ${saving.targetAmount.toStringAsFixed(2).padLeft(13)} | ${progress.toStringAsFixed(2)}%${''.padLeft(5)}|\n";
    }
    table += "--------------------------------------------------------------------\n";
    return table;
  }

  String _generateTransactionsTable() {
    String table = "";
    table += "---------------------------------------------------------------------------------------\n";
    table += "| Date             | Category        | Notes                            | Amount           |\n";
    table += "---------------------------------------------------------------------------------------\n";
    for (var transaction in _transactions) {
      table += "| ${DateFormat.yMMMd().format(transaction.date).padRight(16)} | ${transaction.category.padRight(15)} | ${transaction.notes.padRight(30)} | Tzs ${transaction.amount.toStringAsFixed(2).padLeft(12)} |\n";
    }
    table += "---------------------------------------------------------------------------------------\n";
    return table;
  }

  Future<Uint8List> _generatePdfContent(PdfPageFormat format, String reportText) async {
    final pdfDoc = pw.Document();

    pdfDoc.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Financial Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Date Range: ${DateFormat.yMMMd().format(_selectedDateRange.start)} - ${DateFormat.yMMMd().format(_selectedDateRange.end)}'), // Date range
              pw.SizedBox(height: 20),

              if (_selectedReportType == ReportType.savings && _savings.isNotEmpty) ...[
                pw.Text('Savings Goals', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Table.fromTextArray(
                  border: pw.TableBorder.all(),
                  headers: ['Goal Title', 'Saved Amount', 'Target Amount', 'Progress'],
                  data: _savings.map((saving) {
                    double progress = (saving.savedAmount / saving.targetAmount) * 100;
                    return [
                      saving.title,
                      'Tzs ${saving.savedAmount.toStringAsFixed(2)}',
                      'Tzs ${saving.targetAmount.toStringAsFixed(2)}',
                      '${progress.toStringAsFixed(2)}%',
                    ];
                  }).toList(),
                ),
                pw.SizedBox(height: 10),
                pw.Text('Total Savings Progress: Tzs ${_calculateTotalSavings().toStringAsFixed(2)}'),
              ],

              if (_selectedReportType == ReportType.transactions && _transactions.isNotEmpty) ...[
                pw.Text('Transactions', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Table.fromTextArray(
                  border: pw.TableBorder.all(),
                  headers: ['Date', 'Category', 'Notes', 'Amount'],
                  data: _transactions.map((transaction) => [
                    DateFormat.yMMMd().format(transaction.date),
                    transaction.category,
                    transaction.notes,
                    'Tzs ${transaction.amount.toStringAsFixed(2)}',
                  ]).toList(),
                ),
                pw.SizedBox(height: 10),
                pw.Text('Total Income: Tzs ${_calculateTotalIncome().toStringAsFixed(2)}'),
                pw.Text('Total Expenses: Tzs ${_calculateTotalExpenses().toStringAsFixed(2)}'),
                pw.Text('Total Balance: Tzs ${_calculateTotalBalance().toStringAsFixed(2)}\n'),
              ],
            ],
          );
        },
      ),
    );
    return await pdfDoc.save();
  }

  void _showReportDialog(String content) {
    debugPrint('_showReportDialog: content = \n$content');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 500),
          child: AlertDialog(
            title: Text('Financial Report', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            content: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(content, style: TextStyle(fontSize: 14)),
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text('Close', style: TextStyle(color: Colors.blue)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  double _calculateTotalSavings() => _savings.fold(0, (sum, saving) => sum + saving.savedAmount);
  double _calculateTotalIncome() => _transactions.where((t) => t.isIncome).fold(0, (sum, t) => sum + t.amount);
  double _calculateTotalExpenses() => _transactions.where((t) => !t.isIncome).fold(0, (sum, t) => sum - t.amount);
  double _calculateTotalBalance() => _calculateTotalIncome() + _calculateTotalExpenses();

  @override
Widget build(BuildContext context) {
  final screenHeight = MediaQuery.of(context).size.height;
  final bottomNavBarHeight = kBottomNavigationBarHeight;
  final quarterScreenHeight = screenHeight / 4;

  double _initialChildSizeFactor = bottomNavBarHeight / screenHeight;
  double _minChildSizeFactor = bottomNavBarHeight / screenHeight;
  double _quarterScreenFactor = quarterScreenHeight / screenHeight;

  return Scaffold(
    body: Stack(

      children: [
        SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints viewportConstraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 70.0, top: 20.0),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height - 70.0 - 20.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                ElevatedButton(
                                  onPressed: _pickDateRange,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                                  ),
                                  child: const Text("Select Date Range"),
                                ),
                                Text(
                                  "${DateFormat.yMMMd().format(_selectedDateRange.start)} - ${DateFormat.yMMMd().format(_selectedDateRange.end)}",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Report Type", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Row(
                                  children: [
                                    Radio<ReportType>(
                                      value: ReportType.transactions,
                                      groupValue: _selectedReportType,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedReportType = value!;
                                          _fetchTransactionData();
                                        });
                                      },
                                    ),
                                    const Text('Transactions'),
                                    const SizedBox(width: 20),
                                    Radio<ReportType>(
                                      value: ReportType.savings,
                                      groupValue: _selectedReportType,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedReportType = value!;
                                          _fetchSavingsData();
                                        });
                                      },
                                    ),
                                    const Text('Savings'),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Visibility(
                                  visible: _selectedReportType == ReportType.transactions,
                                  child: Row(
                                    children: [
                                      const Text("Category:", style: TextStyle(fontWeight: FontWeight.w500)),
                                      const SizedBox(width: 10),
                                      DropdownButton<String>(
                                        value: _selectedCategoryFilter,
                                        onChanged: (String? newValue) {
                                          setState(() {
                                            _selectedCategoryFilter = newValue;
                                          });
                                          _fetchTransactionData();
                                        },
                                        items: [
                                          'All Categories',
                                          ..._transactionCategories,
                                        ].map<DropdownMenuItem<String>>((String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _generateReport,
                          child: _isGenerating
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("Generate Report", style: TextStyle(color: Colors.white, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          color: Colors.grey[50],
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: _reportContent.isEmpty
                                ? const Text("Select a date range and report type, then click 'Generate Report'.",
                                    style: TextStyle(fontSize: 16, color: Colors.black54, fontStyle: FontStyle.italic))
                                : Text(
                                    _reportContent,
                                    style: const TextStyle(fontSize: 15, fontFamily: 'Roboto', color: Colors.black87),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
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
                              setState(() {
                                _currentIndex = index;
                              });
                              if (item['route'] == '/dashboard') {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => DashboardScreen()),
                                );
                              } else if (item['route'] == '/transactions') {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => TransactionsScreen()),
                                );
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
                                _draggableController.animateTo(
                                  _minChildSizeFactor,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                                setState(() {
                                  _isSheetExpanded = false;
                                });
                              } else if (item['route'] == '/about') {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => AboutScreen(
                                          settingsBox: widget.reportSettingsBox as Box<UserProfile>)),
                                );
                              } else if (item['route'] == '/settings') {
                                final onboardingBox = Hive.box('onboarding');
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => SettingsScreen(
                                          settingsBox: widget.reportSettingsBox as Box<UserProfile>,
                                          onboardingBox: onboardingBox)),
                                );
                              }
                            }
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(item['icon'] as IconData,
                                  color: _currentIndex == index
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey),
                              const SizedBox(height: 5),
                              Text(
                                item['label'] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _currentIndex == index
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey,
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
}