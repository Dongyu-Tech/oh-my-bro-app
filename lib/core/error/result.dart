/// Sealed `Result<T>` = `Ok<T>` | `Error<T>`.
///
/// Domain layer (services / repositories) should return Result so call sites
/// can switch on success/error without try/catch noise:
///
/// ```dart
/// switch (await repo.fetchSomething()) {
///   case Ok(value: final data): handle(data);
///   case Error(error: final e): showErrorSnakeBar(e.toString());
/// }
/// ```
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok._;
  const factory Result.error(Exception error) = Error._;
}

final class Ok<T> extends Result<T> {
  const Ok._(this.value);
  final T value;

  @override
  String toString() => 'Result<$T>.ok($value)';
}

final class Error<T> extends Result<T> {
  const Error._(this.error);
  final Exception error;

  @override
  String toString() => 'Result<$T>.error($error)';
}
