/// Extension on [Duration] to get the elapsed time in a human readable format.
extension ElapsedTime on Duration {
  String toHumanReadable() {
    final seconds = inSeconds;
    if (seconds < 60) {
      return '$seconds seconds';
    }

    final minutes = inMinutes;
    if (minutes < 60) {
      return '$minutes minutes';
    }

    final hours = inHours;
    if (hours < 24) {
      return '$hours hours';
    }

    final days = inDays;
    return '$days days';
  }
}
