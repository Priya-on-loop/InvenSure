import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  double _daysPrior = 3.0; // Default is 3 days

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _daysPrior = (prefs.getInt('notification_days') ?? 3).toDouble();
    });
  }

  void _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setInt('notification_days', _daysPrior.toInt());
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("✅ Preference Saved!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Alert Preferences")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Notification Settings",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            Divider(),

            // ENABLE SWITCH
            SwitchListTile(
              title: Text("Enable Expiry Alerts"),
              subtitle: Text("Get notified in status bar"),
              value: _notificationsEnabled,
              onChanged: (val) {
                setState(() => _notificationsEnabled = val);
                _saveSettings();
              },
            ),

            SizedBox(height: 30),

            // DAYS SLIDER
            Text(
              "Alert me when item expires in:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("1 Day", style: TextStyle(color: Colors.grey)),
                Text(
                  "${_daysPrior.toInt()} Days",
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                Text("14 Days", style: TextStyle(color: Colors.grey)),
              ],
            ),
            Slider(
              value: _daysPrior,
              min: 1,
              max: 14,
              divisions: 13,
              label: "${_daysPrior.toInt()} days",
              activeColor: Colors.blue,
              onChanged: _notificationsEnabled
                  ? (val) {
                      setState(() => _daysPrior = val);
                      _saveSettings();
                    }
                  : null,
            ),

            Spacer(),
            Text(
              "Tip: Settings update when you refresh the Dashboard.",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
