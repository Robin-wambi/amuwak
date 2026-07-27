import 'package:amuwak_core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('linkOrCreate', () {
    test('passes p_name/p_phone/p_email and returns the customers id', () async {
      Map<String, dynamic>? params;
      final repo = CustomerProfileRepository.forTest(
        linkOrCreate: (p) async {
          params = p;
          return 'cust-42';
        },
      );

      final id = await repo.linkOrCreate(
        name: 'Ada',
        phone: '+256700123456',
        email: 'ada@example.com',
      );

      expect(id, 'cust-42');
      expect(params, {
        'p_name': 'Ada',
        'p_phone': '+256700123456',
        'p_email': 'ada@example.com',
      });
    });

    test('throws on an unexpected (non-string/blank) RPC result', () async {
      final repo = CustomerProfileRepository.forTest(
        linkOrCreate: (p) async => '   ',
      );
      expect(
        () => repo.linkOrCreate(name: 'A', phone: '0700', email: ''),
        throwsStateError,
      );
    });
  });
}
