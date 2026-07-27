class AllTimeStats {
  final int totalWorkouts;
  final double totalKcal;
  final double totalVolume;
  final int currentStreak;
  final int longestStreak;

  /// Unit label for [totalVolume] ('lb' / 'kg'). The repository converts volume
  /// to the user's chosen unit at the data boundary and stamps the label here,
  /// so stat views render it without doing conversion themselves.
  final String weightUnitLabel;

  AllTimeStats({
    required this.totalWorkouts,
    required this.totalKcal,
    required this.totalVolume,
    required this.currentStreak,
    required this.longestStreak,
    this.weightUnitLabel = 'lb',
  });
}
