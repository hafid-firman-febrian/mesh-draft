extension DateTimeFormatting on DateTime {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  String get formattedDate => '$day ${_months[month - 1]} $year';

  String get formattedDateTime {
    final hh = hour.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    return '$formattedDate, $hh:$mm';
  }
}
