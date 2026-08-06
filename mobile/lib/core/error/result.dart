import 'failure.dart';

/// A minimal Either-style result type: either a [Failure] or a success
/// value of type [T]. Every repository and use case in the app returns
/// `Future<Result<T>>` instead of throwing — this makes error handling
/// explicit and forces the presentation layer to handle both branches.
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(Failure failure) = FailureResult<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is FailureResult<T>;

  /// Returns the success value or null.
  T? get valueOrNull => switch (this) {
        Success<T>(value: final v) => v,
        FailureResult<T>() => null,
      };

  /// Returns the failure or null.
  Failure? get failureOrNull => switch (this) {
        Success<T>() => null,
        FailureResult<T>(failure: final f) => f,
      };

  /// Pattern-match helper for concise handling in the UI layer.
  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) failure,
  }) {
    return switch (this) {
      Success<T>(value: final v) => success(v),
      FailureResult<T>(failure: final f) => failure(f),
    };
  }
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);
  final Failure failure;
}
