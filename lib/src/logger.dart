import 'dart:io' as io;

enum Verbosity implements Comparable<Verbosity> {
  /// Hides all non-fatal log messages.
  fatal,

  /// Shows only error messages, including fatal errors.
  error,

  /// Shows only warning and error messages.
  warning,

  /// Shows only informational, warning, and error messages.
  info,

  /// Shows all log messages, including debug messages.
  debug;

  @override
  int compareTo(Verbosity other) {
    return index.compareTo(other.index);
  }
}

final class FatalError extends Error {
  final String message;

  FatalError(this.message);

  @override
  String toString() => message;
}

final class Logger {
  /// The verbosity level this logged produces messages for.
  ///
  /// Messages with a lower priority than this level will be ignored.
  final Verbosity verbosity;

  const Logger(this.verbosity);

  void _log(String message, Verbosity level) {
    if (level.compareTo(verbosity) <= 0) {
      io.stderr.writeln(message);
    }
  }

  void debug(String message) {
    _log(message, Verbosity.debug);
  }

  void info(String message) {
    _log(message, Verbosity.info);
  }

  void warning(String message) {
    _log(message, Verbosity.warning);
  }

  void error(String message) {
    _log(message, Verbosity.error);
  }

  Never fatal(String message) {
    _log(message, Verbosity.fatal);
    io.exitCode = 1;
    throw FatalError(message);
  }
}
