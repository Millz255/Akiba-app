import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/currency_model.dart';
import '../models/user_profile.dart';
import '../screens/dashboard_screen.dart';
import '../screens/transactions_screen.dart';
import '../screens/savings_goals_screen.dart';
import '../screens/reminders_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/about_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Box<UserProfile> settingsBox;
  final Box onboardingBox;

  const SettingsScreen({super.key, required this.settingsBox, required this.onboardingBox});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  UserProfile _userProfile = UserProfile(
    name: 'Username',
    preferredCurrency: 'TZS',
    isDarkMode: false,
    biometricEnabled: false,
    language: 'en',
  );

  late CurrencyModel _currentCurrency;
  final _nameController = TextEditingController();
  final _jobController = TextEditingController();
  final _incomeController = TextEditingController();
  String _selectedCurrencyDropdown = 'TZS';
  final List<String> currencies = ['TZS'];
  bool _isLoading = true;
  int _currentIndex = 6; // Index for Settings in _navigationItems
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
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    var userProfileBox = widget.settingsBox;
    var onboardBox = widget.onboardingBox;

    String? fullName = onboardBox.get('fullName');
    String? job = onboardBox.get('job');
    String? income = onboardBox.get('income');
    String? preferredCurrencyOnboarding = onboardBox.get('preferredCurrencyOnboarding');

    UserProfile? fetchedProfile = userProfileBox.get('currentUserProfile');

    if (fetchedProfile != null) {
      _userProfile = fetchedProfile;
    }

    _nameController.text = fullName ?? _userProfile.name;
    _jobController.text = job ?? '';
    _incomeController.text = income ?? '';
    _selectedCurrencyDropdown = preferredCurrencyOnboarding ?? _userProfile.preferredCurrency;
    _currentCurrency = CurrencyModel(code: _selectedCurrencyDropdown, exchangeRate: 1.0);

    setState(() {
      _isLoading = false;
    });
  }

  void _saveSettings() {
    _userProfile.name = _nameController.text;
    _userProfile.preferredCurrency = _selectedCurrencyDropdown;

    widget.onboardingBox.put('fullName', _nameController.text);
    widget.onboardingBox.put('job', _jobController.text);
    widget.onboardingBox.put('income', _incomeController.text);
    widget.onboardingBox.put('preferredCurrencyOnboarding', _selectedCurrencyDropdown);

    widget.settingsBox.put('currentUserProfile', _userProfile);

    print('Settings saved (key-based):');
    print('Saved Username in Settings: ${_userProfile.name}');
    print('Preferred Currency: ${_userProfile.preferredCurrency}');
    print('Saved Job: ${_jobController.text}');
    print('Saved Income: ${_incomeController.text}');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
                          Text(
                            'Settings',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          _buildProfileSection(),
                          const Divider(),
                          _buildThemeSection(_userProfile.isDarkMode),
                          const Divider(),
                          _buildBiometricSecuritySection(_userProfile.biometricEnabled),
                          const Divider(),
                          _buildLanguageSection(_userProfile.language),
                          const Divider(),
                          _buildCurrencySection(),
                          const Divider(),
                          ElevatedButton(
                            onPressed: _saveSettings,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            child: const Text("Save Settings", style: TextStyle(color: Colors.white)),
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
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => ReportsExportScreen(reportSettingsBox: widget.settingsBox)),
                                  );
                                } else if (item['route'] == '/about') {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => AboutScreen(settingsBox: widget.settingsBox)),
                                  );
                                } else if (item['route'] == '/settings') {
                                  _draggableController.animateTo(
                                    _minChildSizeFactor,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                  setState(() {
                                    _isSheetExpanded = false;
                                  });
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

  Widget _buildProfileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile Management',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person, color: Colors.blue),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _jobController,
          decoration: const InputDecoration(
            labelText: 'Job / Business (Optional)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.work, color: Colors.blue),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _incomeController,
          decoration: const InputDecoration(
            labelText: 'Another Source of Income (Optional)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.attach_money, color: Colors.blue),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeSection(bool isDarkMode) {
    return ListTile(
      title: const Text('Theme Selection'),
      subtitle: Text(isDarkMode ? 'Dark Mode' : 'Light Mode'),
      leading: const Icon(Icons.color_lens, color: Colors.blue),
      trailing: Switch(
        value: isDarkMode,
        onChanged: (bool value) {
          setState(() {
            _userProfile.isDarkMode = value;
          });
        },
      ),
    );
  }

  Widget _buildBiometricSecuritySection(bool isBiometricEnabled) {
    return ListTile(
      title: const Text('Biometric Security'),
      subtitle: Text(isBiometricEnabled ? 'Enabled' : 'Disabled'),
      leading: const Icon(Icons.fingerprint, color: Colors.blue),
      trailing: Switch(
        value: isBiometricEnabled,
        onChanged: (bool value) {
          setState(() {
            _userProfile.biometricEnabled = value;
          });
        },
      ),
    );
  }

  Widget _buildLanguageSection(String currentLanguage) {
    return ListTile(
      title: const Text('Language'),
      subtitle: Text(currentLanguage == 'en' ? 'English' : 'Swahili'),
      leading: const Icon(Icons.language, color: Colors.blue),
      trailing: DropdownButton<String>(
        value: currentLanguage,
        onChanged: (String? newValue) {
          setState(() {
            _userProfile.language = newValue ?? 'en';
          });
        },
        items: <String>['en', 'sw'].map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value == 'en' ? 'English' : 'Swahili'),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCurrencySection() {
    return ListTile(
      title: const Text('Preferred Currency'),
      subtitle: Text(_selectedCurrencyDropdown),
      leading: const Icon(Icons.monetization_on, color: Colors.blue),
      trailing: SizedBox(
        width: 150.0,
        child: DropdownButtonFormField<String>(
          value: _selectedCurrencyDropdown,
          onChanged: (String? newValue) {
            setState(() {
              _selectedCurrencyDropdown = newValue ?? 'TZS';
              _currentCurrency = CurrencyModel(code: _selectedCurrencyDropdown, exchangeRate: 1.0);
            });
          },
          items: currencies.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }
}