@Skip('Online-only mode: this smoke test round-tripped a mutation through the '
    'outbox worker and sync puller against a local Drift DB — the offline sync '
    'engine, which is disabled in online-only mode. Original preserved in git '
    'history; restore alongside the offline engine when re-enabling offline.')
library;

import 'package:flutter_test/flutter_test.dart';

void main() {}
