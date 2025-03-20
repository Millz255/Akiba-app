import '../models/reminders_model.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

class AddReminderScreen extends StatefulWidget {
  final ReminderModel? reminder;

  const AddReminderScreen({super.key, this.reminder});

  @override
  _AddReminderScreenState createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  TimeOfDay? _selectedTime;
  bool _isEnabled = true;
  bool _repeatDaily = false; // New state for daily repetition
  List<bool> _selectedDays = [false, false, false, false, false, false, false]; // Monday to Sunday
  late Box<ReminderModel> remindersBox;

  @override
  void initState() {
    super.initState();
    remindersBox = Hive.box<ReminderModel>('reminders');
    if (widget.reminder != null) {
      _messageController.text = widget.reminder!.message;
      _selectedTime = TimeOfDay(
        hour: widget.reminder!.time.hour,
        minute: widget.reminder!.time.minute,
      );
      _isEnabled = widget.reminder!.isEnabled;
      _selectedDays = widget.reminder!.repeatDays;
      _repeatDaily = _selectedDays.every((day) => day); // If all days are true, consider it daily
      if (_repeatDaily) {
        _selectedDays = [false, false, false, false, false, false, false]; // Reset individual days if daily is selected
      }
    } else {
      _selectedTime = TimeOfDay.now();
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime!,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _saveReminder() {
    if (_formKey.currentState!.validate() && _selectedTime != null) {
      final DateTime now = DateTime.now();
      final DateTime reminderTime = DateTime(
        now.year,
        now.month,
        now.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      List<bool> finalRepeatDays = List.from(_selectedDays);
      if (_repeatDaily) {
        finalRepeatDays = [true, true, true, true, true, true, true];
      }

      if (widget.reminder == null) {
        remindersBox.add(
          ReminderModel(
            id: Uuid().v4(),
            time: reminderTime,
            message: _messageController.text,
            isEnabled: _isEnabled,
            repeatDays: finalRepeatDays,
          ),
        );
      } else {
        widget.reminder!.time = reminderTime;
        widget.reminder!.message = _messageController.text;
        widget.reminder!.isEnabled = _isEnabled;
        widget.reminder!.repeatDays = finalRepeatDays;
        widget.reminder!.save();
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reminder == null ? "Add Reminder" : "Edit Reminder"),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickTime,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.blue),
                      SizedBox(width: 16),
                      Text(
                        _selectedTime!.format(context),
                        style: TextStyle(fontSize: 18),
                      ),
                      Spacer(),
                      Icon(Icons.edit, color: Colors.blue),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                decoration: InputDecoration(
                  labelText: "Reminder Message",
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? "Enter a message" : null,
              ),
              SizedBox(height: 16),
              SwitchListTile(
                title: Text(
                  "Enable Reminder",
                  style: TextStyle(color: Colors.blue),
                ),
                value: _isEnabled,
                activeColor: Colors.blue,
                onChanged: (value) {
                  setState(() {
                    _isEnabled = value;
                  });
                },
              ),
              SizedBox(height: 16),
              CheckboxListTile(
                title: Text("Repeat Daily", style: TextStyle(color: Colors.blue)),
                value: _repeatDaily,
                activeColor: Colors.blue,
                onChanged: (value) {
                  setState(() {
                    _repeatDaily = value!;
                    if (_repeatDaily) {
                      _selectedDays = [false, false, false, false, false, false, false]; // Uncheck individual days
                    }
                  });
                },
              ),
              if (!_repeatDaily)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Repeat On:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    Wrap(
                      spacing: 8.0,
                      children: [
                        _buildDayCheckbox("Mon", 0),
                        _buildDayCheckbox("Tue", 1),
                        _buildDayCheckbox("Wed", 2),
                        _buildDayCheckbox("Thu", 3),
                        _buildDayCheckbox("Fri", 4),
                        _buildDayCheckbox("Sat", 5),
                        _buildDayCheckbox("Sun", 6),
                      ],
                    ),
                  ],
                ),
              Spacer(),
              ElevatedButton(
                onPressed: _saveReminder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  textStyle:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text("Save Reminder"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayCheckbox(String day, int index) {
    return FilterChip(
      label: Text(day),
      selected: _selectedDays[index],
      onSelected: (bool selected) {
        setState(() {
          _selectedDays[index] = selected;
          if (selected && _repeatDaily) {
            _repeatDaily = false; // Uncheck daily if a specific day is selected
          }
        });
      },
    );
  }
}