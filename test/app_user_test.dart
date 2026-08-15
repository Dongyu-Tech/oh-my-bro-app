import 'package:flutter_test/flutter_test.dart';

import 'package:heymybro/shared/models/app_user_model.dart';
import 'package:heymybro/shared/pages/handle_setup_page.dart';

void main() {
  group('AppUserModel.fromJson', () {
    test('decodes the snake_case shape public.users actually returns', () {
      final user = AppUserModel.fromJson(const {
        'id': 'abc',
        'handle': 'alex_1',
        'display_name': 'Alex',
        'avatar_url': null,
        'provider_avatar_url': 'https://lh3.googleusercontent.com/a/X',
        'gender': 'prefer_not_to_say',
        'birthday': '1998-04-02',
        'bio': 'hi',
      });

      expect(user.displayName, 'Alex');
      expect(user.providerAvatarUrl, endsWith('/a/X'));
      expect(user.gender, Gender.preferNotToSay);
      expect(user.birthday, DateTime(1998, 4, 2));
    });

    test('survives a gender value this build has never heard of', () {
      // An older client must not crash on a row written by a newer server.
      final user = AppUserModel.fromJson(const {
        'id': 'abc',
        'gender': 'something_new',
      });
      expect(user.gender, isNull);
    });

    test('tolerates the trimmed row the search RPC returns', () {
      final user = AppUserModel.fromJson(const {
        'id': 'abc',
        'handle': 'alex_1',
        'display_name': 'Alex',
        'avatar_url': 'https://cdn/x.png',
      });
      expect(user.effectiveAvatarUrl, 'https://cdn/x.png');
    });
  });

  group('avatar precedence', () {
    test('an uploaded avatar wins over the provider mirror', () {
      const user = AppUserModel(
        id: 'a',
        avatarUrl: 'https://storage/mine.png',
        providerAvatarUrl: 'https://google/theirs.png',
      );
      expect(user.effectiveAvatarUrl, 'https://storage/mine.png');
    });

    test('falls back to the provider mirror', () {
      const user = AppUserModel(
        id: 'a',
        providerAvatarUrl: 'https://google/theirs.png',
      );
      expect(user.effectiveAvatarUrl, 'https://google/theirs.png');
    });
  });

  group('bestName', () {
    test('prefers the display name then the handle', () {
      expect(
        const AppUserModel(id: 'a', handle: 'h', displayName: 'D').bestName,
        'D',
      );
      expect(const AppUserModel(id: 'a', handle: 'h').bestName, 'h');
      expect(const AppUserModel(id: 'a').bestName, '');
    });

    test('treats a whitespace-only display name as absent', () {
      expect(
        const AppUserModel(id: 'a', handle: 'h', displayName: '   ').bestName,
        'h',
      );
    });
  });

  group('age', () {
    test('is null without a birthday', () {
      expect(const AppUserModel(id: 'a').age, isNull);
    });

    test('does not count a birthday that has not come round yet this year', () {
      final now = DateTime.now();
      final turnsTomorrow = DateTime(
        now.year - 30,
        now.month,
        now.day,
      ).add(const Duration(days: 1));
      final user = AppUserModel(id: 'a', birthday: turnsTomorrow);
      expect(user.age, 29);
    });
  });

  group('validateHandle — must mirror the server check', () {
    // Server: constraint users_handle_format check (handle ~ '^[a-zA-Z0-9_]{3,20}$')
    test('accepts what the server accepts', () {
      expect(validateHandle('abc'), isNull);
      expect(validateHandle('alex_1'), isNull);
      expect(validateHandle('a' * kHandleMaxLength), isNull);
      expect(validateHandle('  alex  '), isNull, reason: 'trimmed first');
    });

    test('rejects what the server rejects', () {
      expect(validateHandle(''), HandleProblem.empty);
      expect(validateHandle('   '), HandleProblem.empty);
      expect(validateHandle('ab'), HandleProblem.tooShort);
      expect(
        validateHandle('a' * (kHandleMaxLength + 1)),
        HandleProblem.tooLong,
      );
      expect(validateHandle('王小明'), HandleProblem.badChars);
      expect(validateHandle('alex 1'), HandleProblem.badChars);
      expect(validateHandle('alex-1'), HandleProblem.badChars);
      expect(validateHandle('alex@1'), HandleProblem.badChars);
    });

    test('reports bad characters before length', () {
      // "王小" is 2 chars AND non-ASCII. Telling someone to add a character
      // would send them down the wrong path.
      expect(validateHandle('王小'), HandleProblem.badChars);
    });
  });
}
