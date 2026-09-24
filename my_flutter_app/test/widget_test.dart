import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_app/core/constants.dart';
import 'package:my_flutter_app/models/models.dart';

void main() {
  group('role contract', () {
    test('contains every live backend app role', () {
      expect(
        AppRoles.all,
        containsAll(<String>[
          AppRoles.superAdmin,
          AppRoles.schoolAdmin,
          AppRoles.teacher,
          AppRoles.student,
          AppRoles.parent,
          AppRoles.financeManager,
          AppRoles.registrar,
        ]),
      );
      expect(AppRoles.all.toSet().length, AppRoles.all.length);
    });

    test('renders finance and registrar role names', () {
      expect(AppRoles.displayName(AppRoles.financeManager), 'Finance Manager');
      expect(AppRoles.displayName(AppRoles.registrar), 'Registrar');
    });
  });

  group('profile contract', () {
    test('parses real profile columns and nested school', () {
      final profile = ProfileModel.fromMap(<String, dynamic>{
        'id': 'profile-1',
        'user_id': 'user-1',
        'school_id': 'school-1',
        'role': AppRoles.teacher,
        'first_name': 'Tariro',
        'last_name': 'Moyo',
        'email': 'teacher@example.test',
        'status': 'active',
        'created_at': '2026-09-24T08:00:00Z',
        'updated_at': '2026-09-24T08:00:00Z',
        'schools': <String, dynamic>{
          'id': 'school-1',
          'name': 'Contract Test School',
          'subdomain': 'contract-test',
          'settings': <String, dynamic>{},
          'status': 'active',
          'created_at': '2026-09-24T08:00:00Z',
          'updated_at': '2026-09-24T08:00:00Z',
        },
      });

      expect(profile.fullName, 'Tariro Moyo');
      expect(profile.role, AppRoles.teacher);
      expect(profile.school?.name, 'Contract Test School');
      expect(profile.isActive, isTrue);
    });
  });

  group('multi-currency finance contract', () {
    test('derives outstanding without mixing currency identity', () {
      final summary = FinanceCurrencySummary.fromMap(<String, dynamic>{
        'currency': 'USD',
        'total_invoiced': 1250,
        'total_paid': 900,
        'overdue_count': 2,
      });

      expect(summary.currency, 'USD');
      expect(summary.totalInvoiced, 1250);
      expect(summary.totalPaid, 900);
      expect(summary.outstanding, 350);
      expect(summary.formattedOutstanding, 'USD 350.00');
      expect(summary.overdueCount, 2);
    });
  });

  group('direct message contract', () {
    test('identifies current-profile messages and normalized sender data', () {
      final message = DirectMessageItem.fromMap(
        <String, dynamic>{
          'id': 'message-1',
          'school_id': 'school-1',
          'sender_profile_id': 'profile-me',
          'recipient_profile_id': 'profile-other',
          'message': 'Hello',
          'created_at': '2026-09-24T08:15:00Z',
          'sender': <String, dynamic>{
            'full_name': 'Current User',
            'role': AppRoles.schoolAdmin,
          },
        },
        'profile-me',
      );

      expect(message.isMe, isTrue);
      expect(message.senderName, 'Current User');
      expect(message.senderRole, AppRoles.schoolAdmin);
      expect(message.schoolId, 'school-1');
      expect(message.message, 'Hello');
    });

    test('does not mark a received message as mine', () {
      final message = DirectMessageItem.fromMap(
        <String, dynamic>{
          'id': 'message-2',
          'school_id': 'school-1',
          'sender_profile_id': 'profile-other',
          'recipient_profile_id': 'profile-me',
          'message': 'Received',
          'created_at': '2026-09-24T08:16:00Z',
          'sender': <String, dynamic>{
            'full_name': 'Other User',
            'role': AppRoles.teacher,
          },
        },
        'profile-me',
      );

      expect(message.isMe, isFalse);
      expect(message.recipientProfileId, 'profile-me');
    });
  });
}
