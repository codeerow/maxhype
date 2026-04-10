import 'package:flutter/foundation.dart';
import '../../models/monthly_data.dart';
import '../../models/workout.dart';
import '../../repositories/workout_repository.dart';

class HomeViewModel extends ChangeNotifier {
  final WorkoutRepository repository;

  List<Workout> _workouts = [];
  List<MonthlyData> _monthlyData = [];
  bool _isLoading = false;
  String? _error;

  HomeViewModel({required this.repository});

  List<Workout> get workouts => _workouts;
  List<MonthlyData> get monthlyData => _monthlyData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _workouts = await repository.getWorkouts();
      _monthlyData = await repository.getMonthlyData();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
}
