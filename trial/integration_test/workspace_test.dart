import 'package:integration_test/integration_test.dart';
import 'package:test_api/scaffolding.dart' show Timeout;

import '../test/workspace_test.dart' as flows;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.defaultTestTimeout = const Timeout(Duration(minutes: 3));
  flows.main();
}
