import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/reminders_model.dart'; // Import your ReminderModel
import '../screens/add_reminder_screen.dart'; // Import your AddReminderScreen
import '../models/user_profile.dart'; // Import User Profile Model
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:async'; // Import dart:async for Timer
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:google_fonts/google_fonts.dart'; // Add google_fonts package
import '../screens/transactions_screen.dart';
import '../screens/savings_goals_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/reports_screen.dart'; // Import ReportsScreen
import '../screens/about_screen.dart';
import '../screens/dashboard_screen.dart'; // Import DashboardScreen

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  _RemindersScreenState createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with SingleTickerProviderStateMixin {
  late Box<ReminderModel> remindersBox;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  late Box<UserProfile> userProfileBox;
  String userName = "User";
  late AnimationController _animationController;
  Timer? _randomNotificationTimer; // Timer for random notifications
  int _currentIndex = 2; // Index for Reminders in _navigationItems
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

  final List<String> reminderMessages = [
    "Save a little, smile a lot! 😊",
    "Money saved today is happiness tomorrow! 💸",
    "Every penny counts, don’t forget to save! 💪",
    "A penny saved is a penny earned! 🏦",
    "Budget now, enjoy later! 🥳",
    "Save smart, live happy! 🏖️",
    "Your future self will thank you for saving! 🌟",
    "Don’t spend it all! Think before you spend! 🤔",
    "Saving today is investing in tomorrow! 💰",
    "Be wise, save the prize! 🏆"
  ];

  @override
void initState() {
  super.initState();

  // Set the correct index for the current screen
  _currentIndex = _navigationItems.indexWhere((item) => item['route'] == '/reminders');

  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  _initializeNotifications().then((_) {
    setState(() {});
  });

  remindersBox = Hive.box<ReminderModel>('reminders');
  userProfileBox = Hive.box<UserProfile>('settings');
  _animationController = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 300),
  );
  _loadUserProfile();

  _scheduleRandomNotifications();
  _scheduleReminderNotifications(); // Schedule reminder notifications
}

  @override
  void dispose() {
    _randomNotificationTimer?.cancel(); // Cancel timer when screen is disposed
    _animationController.dispose();
    super.dispose();
  }

  Future<bool> checkNotificationPermission() async {
    final androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final bool? granted = await androidImplementation?.areNotificationsEnabled();
    return granted ?? false;
  }

  Future<void> _initializeNotifications() async {
    try {
      const AndroidInitializationSettings androidInitializationSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      final InitializationSettings initializationSettings =
          InitializationSettings(android: androidInitializationSettings);

      await flutterLocalNotificationsPlugin.initialize(initializationSettings);

      // Get Android SDK version
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

      // Request permission for notifications (Android 13+)
      if (androidInfo.version.sdkInt >= 33) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }

      print("Notifications Initialized Successfully");
    } catch (e) {
      print("Error initializing notifications: $e");
    }

    tzdata.initializeTimeZones(); // Initialize timezones
    tz.setLocalLocation(tz.getLocation('Africa/Dar_es_Salaam'));
  }

  Future<void> _sendRandomReminderNotification() async {
    final randomMessage = reminderMessages[
        DateTime.now().millisecondsSinceEpoch % reminderMessages.length];

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'encouragement_channel', // Changed channel ID
      'Encouragement', // Changed channel Name
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await flutterLocalNotificationsPlugin.show(
      1, // Changed notification ID to avoid conflict with reminder notifications if you have any in future
      'Words of Encouragement!', // Changed title
      'Hello $userName, $randomMessage', // Added username to the message
      notificationDetails,
    );
  }

  void _scheduleReminderNotifications() {
    Timer.periodic(Duration(minutes: 1), (timer) {
      final now = tz.TZDateTime.now(tz.local);
      for (var reminder in remindersBox.values) {
        if (reminder.isEnabled) {
          final reminderTime = tz.TZDateTime(
            tz.local,
            now.year,
            now.month,
            now.day,
            reminder.time.hour,
            reminder.time.minute,
          );
          if (reminderTime.isBefore(now)) {
            reminderTime.add(Duration(days: 1)); // If the time has passed today, set it to tomorrow.
          }
          if (reminderTime.difference(now).inMinutes <= 1) {
            _showReminderNotification(reminder);
          }
        }
      }
    });
  }

  void _scheduleRandomNotifications() {
    // Set the interval for random notifications (e.g., daily at noon)
    final now = DateTime.now();
    final noonToday = DateTime(now.year, now.month, now.day, 12, 0, 0); // Noon today
    DateTime nextNotificationTime;

    if (now.isAfter(noonToday)) {
      // If it's already past noon, schedule for noon tomorrow
      nextNotificationTime = noonToday.add(Duration(days: 1));
    } else {
      // Otherwise, schedule for noon today
      nextNotificationTime = noonToday;
    }

    final initialDelay = nextNotificationTime.difference(now);

    _randomNotificationTimer = Timer(initialDelay, () {
      _sendRandomReminderNotification(); // Send notification at the scheduled time

      // Schedule the next notification for the next day
      _randomNotificationTimer = Timer.periodic(Duration(days: 1), (timer) {
        _sendRandomReminderNotification(); // Send notification daily
      });
    });
  }

  Future<void> _showReminderNotification(ReminderModel reminder) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'reminder_channel',
      'Reminders',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await flutterLocalNotificationsPlugin.show(
      reminder.id.hashCode, // Use a unique ID
      'Reminder',
      reminder.message,
      notificationDetails,
    );
  }

  void _loadUserProfile() {
    if (userProfileBox.isNotEmpty) {
      setState(() {
        userName = userProfileBox.getAt(0)?.name ?? "User";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomNavBarHeight = kBottomNavigationBarHeight;
    final quarterScreenHeight = screenHeight / 4;

    double _initialChildSizeFactor = bottomNavBarHeight / screenHeight;
    double _minChildSizeFactor = bottomNavBarHeight / screenHeight;
    double _quarterScreenFactor = quarterScreenHeight / screenHeight;

    return Scaffold(
      // Removed the appBar here
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 70.0, top: 20.0), // Adjust top and bottom padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      "Reminders",
                      style: GoogleFonts.notoSans(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder(
                      valueListenable: remindersBox.listenable(),
                      builder: (context, Box<ReminderModel> box, _) {
                        if (box.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 50.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "No reminders set. Tap the '+' button below to add one.",
                                    style: GoogleFonts.notoSans(fontSize: 16, color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    "Once you add reminders:",
                                    style: GoogleFonts.notoSans(fontSize: 14, color: Colors.grey[600]),
                                    textAlign: TextAlign.center,
                                  ),
                                  Text(
                                    "- Tap a reminder to edit it.",
                                    style: GoogleFonts.notoSans(fontSize: 14, color: Colors.grey[600]),
                                    textAlign: TextAlign.center,
                                  ),
                                  Text(
                                    "- Swipe left or right on a reminder to delete it.",
                                    style: GoogleFonts.notoSans(fontSize: 14, color: Colors.grey[600]),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.all(12),
                          shrinkWrap: true, // Important for SingleChildScrollView
                          physics: NeverScrollableScrollPhysics(), // Disable scrolling of ListView
                          itemCount: box.length,
                          itemBuilder: (context, index) {
                            final ReminderModel reminder = box.getAt(index)!;

                            return Dismissible(
                              key: Key(reminder.id),
                              direction: DismissDirection.endToStart,
                              onDismissed: (direction) {
                                reminder.delete();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Reminder deleted")),
                                );
                              },
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: EdgeInsets.symmetric(horizontal: 20),
                                color: Colors.red,
                                child: Icon(Icons.delete, color: Colors.white),
                              ),
                              child: GestureDetector(
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          AddReminderScreen(reminder: reminder),
                                    ),
                                  );
                                  setState(() {});
                                },
                                child: AnimatedContainer(
                                  duration: Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  margin: EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.2),
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    title: Text(reminder.message,
                                        style: GoogleFonts.notoSans(fontSize: 16)),
                                    subtitle: Text(
                                      DateFormat.jm().format(reminder.time),
                                      style: GoogleFonts.notoSans(color: Colors.grey[600]),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTapDown: (details) {
                // Animate the sheet to expand when tapped
                _draggableController.animateTo(
                  _quarterScreenFactor,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                setState(() {
                  _isSheetExpanded = true; // Update the flag
                });
              },
              child: DraggableScrollableSheet(
                controller: _draggableController,
                initialChildSize: _initialChildSizeFactor,
                minChildSize: _minChildSizeFactor,
                maxChildSize: _quarterScreenFactor,
                snap: true, // Enable snapping to defined sizes
                snapSizes: [_initialChildSizeFactor, _quarterScreenFactor],
                builder: (BuildContext context, ScrollController scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
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
                        crossAxisCount: 4, // Adjust as needed for layout
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
                              _currentIndex = index; // Update the current index
                            });

                            if (item['route'] == '/dashboard') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DashboardScreen(),
                                ),
                              );
                            } else if (item['route'] == '/transactions') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TransactionsScreen(),
                                ),
                              );
                            } else if (item['route'] == '/savings') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SavingsGoalsScreen(),
                                ),
                              );
                            } else if (item['route'] == '/reminders') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RemindersScreen(),
                                ),
                              );
                            } else if (item['route'] == '/reports') {
                              final settingsBox = Hive.box('settings');
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
                                  builder: (context) => AboutScreen(
                                    settingsBox: userProfileBox, // Pass settingsBox
                                  ),
                                ),
                              );
                            } else if (item['route'] == '/settings') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SettingsScreen(
                                    settingsBox: userProfileBox, // Pass settingsBox
                                    onboardingBox: Hive.box('onboarding'), // Pass onboardingBox
                                  ),
                                ),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        child: Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddReminderScreen()),
          );
          setState(() {}); // Refresh the list after adding a reminder
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}