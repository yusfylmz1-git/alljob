import 'package:flutter_test/flutter_test.dart';
import 'package:usta_cepte/features/auth/data/mock_auth_repository.dart';
import 'package:usta_cepte/features/auth/data/phone_verification_repository.dart';

void main() {
  group('MockPhoneVerificationRepository', () {
    late MockPhoneVerificationRepository repo;

    setUp(() => repo = MockPhoneVerificationRepository());

    test('geçersiz numara sendCode reddeder', () async {
      expect(
        () => repo.sendCode('123'),
        throwsA(isA<PhoneVerificationException>()),
      );
    });

    test('geçerli numara oturum döner, doğru kod numarayı doğrular', () async {
      final session = await repo.sendCode('+905551112233');
      expect(session.phoneE164, '+905551112233');
      final phone = await repo.confirmCode(session, '123456');
      expect(phone, '+905551112233');
    });

    test('yanlış kod confirmCode reddeder', () async {
      final session = await repo.sendCode('+905551112233');
      expect(
        () => repo.confirmCode(session, '000000'),
        throwsA(isA<PhoneVerificationException>()),
      );
    });
  });

  test('doğrulama sonrası setPhoneVerified kullanıcıyı doğrulanmış yapar',
      () async {
    final auth = MockAuthRepository();
    await auth.login(email: 'usta@test.com', password: '123456');
    expect(auth.currentUser!.phoneVerified, isFalse);

    final repo = MockPhoneVerificationRepository();
    final session = await repo.sendCode('+905551112233');
    final phone = await repo.confirmCode(session, '123456');
    final user = await auth.setPhoneVerified(phone);

    expect(user.phoneVerified, isTrue);
    expect(auth.currentUser!.phoneVerified, isTrue);
    auth.dispose();
  });
}
