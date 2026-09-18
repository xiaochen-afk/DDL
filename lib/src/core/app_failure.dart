class AppFailure implements Exception {
  const AppFailure({required this.code, required this.message, this.cause});

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'AppFailure($code): $message';
}
