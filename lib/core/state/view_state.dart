/// Standardized explicit view state models for the EBIC User App.
/// Adheres to Section 8.1 (Explicit State Management Principle).
sealed class ViewState<T> {
  const ViewState();

  bool get isInitial => this is ViewInitial<T>;
  bool get isLoading => this is ViewLoading<T>;
  bool get isLoaded => this is ViewLoaded<T>;
  bool get isEmpty => this is ViewEmpty<T>;
  bool get isFailure => this is ViewFailure<T>;
  bool get isSubmitting => this is ViewSubmitting<T>;
  bool get isSuccess => this is ViewSuccess<T>;
  bool get isConflict => this is ViewConflict<T>;

  T? get dataOrNull {
    if (this is ViewLoaded<T>) return (this as ViewLoaded<T>).data;
    if (this is ViewSuccess<T>) return (this as ViewSuccess<T>).data;
    return null;
  }
}

class ViewInitial<T> extends ViewState<T> {
  const ViewInitial();
}

class ViewLoading<T> extends ViewState<T> {
  final String? message;
  const ViewLoading([this.message]);
}

class ViewLoaded<T> extends ViewState<T> {
  final T data;
  const ViewLoaded(this.data);
}

class ViewEmpty<T> extends ViewState<T> {
  final String? message;
  const ViewEmpty([this.message]);
}

class ViewFailure<T> extends ViewState<T> {
  final String message;
  final String? code;
  final dynamic details;
  const ViewFailure(this.message, {this.code, this.details});
}

class ViewSubmitting<T> extends ViewState<T> {
  final String? message;
  const ViewSubmitting([this.message]);
}

class ViewSuccess<T> extends ViewState<T> {
  final T? data;
  final String? message;
  const ViewSuccess({this.data, this.message});
}

class ViewConflict<T> extends ViewState<T> {
  final String message;
  final dynamic conflictData;
  const ViewConflict(this.message, {this.conflictData});
}
