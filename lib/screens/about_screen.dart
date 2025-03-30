import 'package:Akiba/screens/dashboard_screen.dart';
import 'package:Akiba/screens/reminders_screen.dart';
import 'package:Akiba/screens/reports_screen.dart';
import 'package:Akiba/screens/savings_goals_screen.dart';
import 'package:Akiba/screens/settings_screen.dart';
import 'package:Akiba/screens/transactions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/user_profile.dart'; 

class AboutScreen extends StatefulWidget {
  final Box<UserProfile> settingsBox; 

  const AboutScreen({super.key, required this.settingsBox});

  @override
  _AboutScreenState createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> with SingleTickerProviderStateMixin {
  late Box<UserProfile> _settingsBox;
  String userName = "User";
  final DraggableScrollableController _draggableController = DraggableScrollableController();
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
    // Assign the passed box to a local variable
    _settingsBox = widget.settingsBox;
    // Fetch user information from the passed box
    _loadUserSettings();
  }

  // Fetch user information synchronously using the already opened box
  void _loadUserSettings() {
    final profile = _settingsBox.get('userName');
    setState(() {
      userName = profile?.name ?? 'User';
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomNavBarHeight = kBottomNavigationBarHeight;
    final quarterScreenHeight = screenHeight / 4;

    double initialChildSizeFactor = bottomNavBarHeight / screenHeight;
    double minChildSizeFactor = bottomNavBarHeight / screenHeight;
    double quarterScreenFactor = quarterScreenHeight / screenHeight;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  _buildHeader(context), // Pass context
                  _buildFaqSection(context), // Pass context
                  _buildContactInfo(context), // Pass context
                  _buildVersionNumber(context), // Pass context
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTapDown: (details) {
                _draggableController.animateTo(
                  quarterScreenFactor,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                setState(() {
                  _isSheetExpanded = true;
                });
              },
              child: DraggableScrollableSheet(
                controller: _draggableController,
                initialChildSize: initialChildSizeFactor,
                minChildSize: minChildSizeFactor,
                maxChildSize: quarterScreenFactor,
                snap: true,
                snapSizes: [initialChildSizeFactor, quarterScreenFactor],
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
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => ReportsExportScreen(reportSettingsBox: _settingsBox)),
                                  );
                                } else if (item['route'] == '/about') {
                                  _draggableController.animateTo(
                                    minChildSizeFactor,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                  setState(() {
                                    _isSheetExpanded = false;
                                  });
                                } else if (item['route'] == '/settings') {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => SettingsScreen(settingsBox: _settingsBox, onboardingBox: _settingsBox)),
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to Akiba',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
            fontFamily: 'Noto Sans',
          ),
        ).animate().fadeIn().move(begin: Offset(0, -10), end: Offset(0, 0)),
        SizedBox(height: 10),
        Text(
          'Akiba is your personal assistant for managing savings and tracking expenses. Let us help you achieve your financial goals.',
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontFamily: 'Noto Sans',
          ),
        ).animate().fadeIn().move(begin: Offset(0, 10), end: Offset(0, 0)),
      ],
    );
  }

  Widget _buildFaqSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20),
        Text(
          'Frequently Asked Questions',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
            fontFamily: 'Noto Sans',
          ),
        ).animate().fadeIn().move(begin: Offset(0, -10), end: Offset(0, 0)),
        SizedBox(height: 10),
        _buildFaqItem(
          context: context,
          question: 'How do I add savings?',
          answer: 'To add savings, go to the "Savings" tab, enter the amount, and press "Save".',
        ),
        _buildFaqItem(
          context: context,
          question: 'How can I track my expenses?',
          answer: 'Go to "Expenses" in the menu, where you can view and categorize all your transactions.',
        ),
        _buildFaqItem(
          context: context,
          question: 'How can I set financial goals?',
          answer: 'Navigate to "Goals", create a new goal, and set your savings target.',
        ),
      ],
    );
  }

  Widget _buildFaqItem({required BuildContext context, required String question, required String answer}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 2,
      child: ExpansionTile(
        title: Text(
          question,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        leading: Icon(Icons.help_outline, color: Colors.blue),
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Text(
              answer,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontFamily: 'Noto Sans',
              ),
            ).animate().fadeIn().scale(),
          ),
        ],
      ).animate().fadeIn().move(begin: Offset(0, -10), end: Offset(0, 0)),
    );
  }

  Widget _buildContactInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20),
        Text(
          'Contact Us',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
            fontFamily: 'Noto Sans',
          ),
        ).animate().fadeIn().move(begin: Offset(0, -10), end: Offset(0, 0)),
        SizedBox(height: 10),
        _buildContactItem(context, 'Phone', '+255752751416', Icons.phone),
        _buildContactItem(context, 'Email', 'mgimwaemily@gmail.com', Icons.email),
      ],
    );
  }

  Widget _buildContactItem(BuildContext context, String label, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      subtitle: InkWell(
        onTap: () {
          if (label == 'Phone') {
            _showPhoneActionSheet(context, value);
          } else if (label == 'Email') {
            _showEmailActionSheet(context, value);
          }
        },
        child: Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: Colors.blue, // Make the value tappable
            fontFamily: 'Noto Sans',
            decoration: TextDecoration.underline, // Indicate it's tappable
          ),
        ),
      ),
    ).animate().fadeIn().move(begin: Offset(0, -10), end: Offset(0, 0));
  }

  void _showPhoneActionSheet(BuildContext context, String phoneNumber) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.call),
                title: const Text('Call'),
                onTap: () async {
                  Navigator.pop(context);
                  final Uri launchUri = Uri(
                    scheme: 'tel',
                    path: phoneNumber,
                  );
                  if (await canLaunchUrl(launchUri)) {
                    await launchUrl(launchUri);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not launch phone app.')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy Number'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: phoneNumber));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Phone number copied to clipboard.')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEmailActionSheet(BuildContext context, String email) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('Send Email'),
                onTap: () async {
                  Navigator.pop(context);
                  final Uri launchUri = Uri(
                    scheme: 'mailto',
                    path: email,
                  );
                  if (await canLaunchUrl(launchUri)) {
                    await launchUrl(launchUri);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not launch email app.')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy Email'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: email));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email address copied to clipboard.')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVersionNumber(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20),
        Text(
          'Version',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
            fontFamily: 'Noto Sans',
          ),
        ).animate().fadeIn().move(begin: Offset(0, -10), end: Offset(0, 0)),
        SizedBox(height: 10),
        Text(
          'Version 1.0.0',
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontFamily: 'Noto Sans',
          ),
        ).animate().fadeIn().move(begin: Offset(0, 10), end: Offset(0, 0)),
      ],
    );
  }
}