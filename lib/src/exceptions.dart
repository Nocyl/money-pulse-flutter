/// Exception thrown when the Money-Pulse API returns an error.
class MoneyPulseException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? details;

  MoneyPulseException(this.message, {this.statusCode, this.details});

  @override
  String toString() => 'MoneyPulseException($statusCode): $message';
}

/// Exception thrown when authentication fails.
class MoneyPulseAuthException extends MoneyPulseException {
  MoneyPulseAuthException(String message) : super(message, statusCode: 401);
}

/// Exception thrown when a resource is not found.
class MoneyPulseNotFoundException extends MoneyPulseException {
  MoneyPulseNotFoundException(String message) : super(message, statusCode: 404);
}
