import 'dart:async';

class SessionService {
  static final _controller = StreamController<void>.broadcast();

  static Stream<void> get sessionExpiredStream => _controller.stream;

  static void signalExpired() {
    if (!_controller.isClosed) _controller.add(null);
  }
}
