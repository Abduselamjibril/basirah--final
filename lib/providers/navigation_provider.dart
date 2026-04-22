import 'package:flutter/material.dart';

class NavigationProvider with ChangeNotifier {
  int _mainIndex = 0;
  int _libraryTabIndex = 0;

  int get mainIndex => _mainIndex;
  int get libraryTabIndex => _libraryTabIndex;

  void setMainIndex(int index) {
    _mainIndex = index;
    notifyListeners();
  }

  void setLibraryTab(int index) {
    _libraryTabIndex = index;
    // When we set library tab, we usually want to be on the Library page too
    _mainIndex = 1; 
    notifyListeners();
  }
}
