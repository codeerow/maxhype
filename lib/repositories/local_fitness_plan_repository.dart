import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/generator/fitness_plan.dart';
import 'fitness_plan_repository.dart';

/// Local filesystem implementation of [FitnessPlanRepository].
///
/// Storage: `fitness_plan.json` in the app documents directory, holding a
/// single serialized [FitnessPlan]. Uses the same durability approach as the
/// other local repositories — a write-lock plus write-temp-then-rename so a
/// crash mid-write can't corrupt the plan — and falls back to
/// [FitnessPlan.defaults] on a missing or corrupt store.
class LocalFitnessPlanRepository implements FitnessPlanRepository {
  /// Test seam — production leaves this null and uses
  /// `getApplicationDocumentsDirectory`. Tests pass a temp directory.
  final Future<Directory> Function()? _directoryResolver;

  LocalFitnessPlanRepository({
    Future<Directory> Function()? directoryResolver,
  }) : _directoryResolver = directoryResolver;

  static const _fileName = 'fitness_plan.json';

  /// Reactive display unit (see [FitnessPlanRepository.units]). Seeded on the
  /// first [load] and refreshed on every [save].
  final ValueNotifier<WeightUnit> _units =
      ValueNotifier<WeightUnit>(FitnessPlan.defaults().units);

  @override
  ValueListenable<WeightUnit> get units => _units;

  Future<void> _writeLock = Future.value();

  Future<T> _enqueueWrite<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _writeLock = _writeLock.then((_) async {
      try {
        completer.complete(await task());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<Directory> _dir() async =>
      _directoryResolver?.call() ?? getApplicationDocumentsDirectory();

  Future<File> _file() async {
    final dir = await _dir();
    return File('${dir.path}/$_fileName');
  }

  @override
  Future<FitnessPlan> load() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return FitnessPlan.defaults();
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return FitnessPlan.defaults();
      final plan = FitnessPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _units.value = plan.units;
      return plan;
    } on Object {
      // Corrupt store — reset to defaults rather than crash. Best-effort
      // cleanup of the bad file so the next save starts clean.
      try {
        final file = await _file();
        if (file.existsSync()) await file.delete();
      } on FileSystemException {
        // best-effort
      }
      return FitnessPlan.defaults();
    }
  }

  @override
  Future<void> save(FitnessPlan plan) => _enqueueWrite(() async {
        final file = await _file();
        await file.parent.create(recursive: true);
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(jsonEncode(plan.toJson()), flush: true);
        await tmp.rename(file.path);
        // Publish the unit so weight-rendering screens rebuild reactively.
        _units.value = plan.units;
      });
}
