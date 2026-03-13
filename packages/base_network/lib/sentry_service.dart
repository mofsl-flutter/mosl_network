import 'package:sentry_flutter/sentry_flutter.dart';

class SentryService {
  final bool shouldStartSentry;
  late ISentrySpan _transaction;

  SentryService({required this.shouldStartSentry});

  Future<void> addBreadcrumb(final Map<String, Object?> errorData) async {
    if (shouldStartSentry) {
      final Breadcrumb breadcrumb = Breadcrumb(
        category: 'dio-error', // Optional category for grouping breadcrumbs
        data: errorData,
      );
      await Sentry.addBreadcrumb(breadcrumb);
    }
  }

  void captureException(final dynamic exception, final int statusCode) async {
    if (shouldStartSentry) {
      _transaction.throwable = exception;
      await Sentry.captureException(exception);
      final SpanStatus spanStatus = statusCode != -1
          ? SpanStatus.fromHttpStatusCode(statusCode)
          : const SpanStatus.internalError();
      _transaction.status = spanStatus;
    }
  }

  Future<void> finish() async {
    if (shouldStartSentry) {
      await _transaction.finish();
    }
  }

  Future<ISentrySpan?> startTransaction(final String name, final String operation,
      {final bool bindToScope = false}) async {
    if (shouldStartSentry) {
      return _transaction = Sentry.getSpan() ??
          Sentry.startTransaction(
            name,
            operation,
            bindToScope: true,
          );
    }
    return null;
  }

  void startChildTransaction(final String name, final String operation) {
    if (shouldStartSentry) {
      _transaction = _transaction.startChild(
        name,
        description: operation,
      );
    }
  }

  void setStatus(
    final SpanStatus status,
  ) {
    if (shouldStartSentry) {
      _transaction.status = status;
    }
  }
}
