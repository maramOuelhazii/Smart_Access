import 'package:flutter/material.dart';

class HistoryProvider with ChangeNotifier {
  List<Map<String, dynamic>> _history = [
    {'user': 'User A', 'time': '10:00', 'status': true},
    {'user': 'User B', 'time': '10:05', 'status': false},
  ];

  List<Map<String, dynamic>> get history => _history;

  void addEntry(Map<String, dynamic> entry) {
    _history.add(entry);
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    notifyListeners();
  }
}
