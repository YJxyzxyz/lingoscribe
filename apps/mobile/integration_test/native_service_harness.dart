import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Native service tests have no widget tree or WidgetTester-owned semantics.
/// Keep integration_test's real assertion/error reporting without treating an
/// OS accessibility request during decoding as a leaked widget-test handle.
void nativeTest(
  String description,
  Future<void> Function() body, {
  Timeout? timeout,
}) {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test(description, () {
    addTearDown(binding.postTest);
    return binding.runTest(body, () {}, description: description);
  }, timeout: timeout);
}
