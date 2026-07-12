/// Breakdown of a child's age into whole years, months, and days — used
/// for the emotional "Today she is / X Years / Y Months / Z Days old"
/// hero copy on the Home screen.
///
/// This is separate from [ChildProfile.formattedAge], which produces a
/// compact single-line age (e.g. "1 year 2 months") used elsewhere. That
/// existing logic is untouched by this sprint.
class AgeBreakdown {
  final int years;
  final int months;
  final int days;

  const AgeBreakdown({
    required this.years,
    required this.months,
    required this.days,
  });
}

/// Calculates a calendar-accurate years/months/days breakdown between
/// [birthday] and now.
AgeBreakdown calculateAgeBreakdown(DateTime birthday) {
  final now = DateTime.now();

  int years = now.year - birthday.year;
  int months = now.month - birthday.month;
  int days = now.day - birthday.day;

  if (days < 0) {
    months -= 1;
    // Day count of the month before `now`'s month.
    final daysInPrevMonth = DateTime(now.year, now.month, 0).day;
    days += daysInPrevMonth;
  }
  if (months < 0) {
    years -= 1;
    months += 12;
  }
  if (years < 0) years = 0;

  return AgeBreakdown(years: years, months: months, days: days);
}
