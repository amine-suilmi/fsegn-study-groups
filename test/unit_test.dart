import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsegn_study_groups/core/constants/subjects.dart';
import 'package:fsegn_study_groups/data/models/profile_model.dart';
import 'package:fsegn_study_groups/data/models/study_group_model.dart';
import 'package:fsegn_study_groups/data/services/local_demo_service.dart';

void main() {
  group('Timetable Subjects & Cohort Tests (Directive #6)', () {
    test('Contains exactly 12 subjects matching timetable wording', () {
      expect(Subjects.list.length, 12);
      expect(Subjects.list, contains('Statistique et probabilité'));
      expect(Subjects.list, contains('Comptabilité générale'));
      expect(Subjects.list, contains('Culture de l’IA'));
      expect(
        Subjects.list,
        contains('Systèmes logiques, architecture et ordinateurs'),
      );
      expect(Subjects.list, contains('Algorithmique et structures'));
      expect(Subjects.list, contains('Systèmes d’exploitation'));
      expect(Subjects.list, contains('Analyse'));
      expect(Subjects.list, contains('Principes de gestion 1'));
      expect(Subjects.list, contains('Technologie Web et programmation'));
      expect(Subjects.list, contains('Study Skills 1'));
      expect(Subjects.list, contains('Anglais fondamental'));
      expect(Subjects.list, contains('Digital Skills'));
    });

    test('Subject validator correctly identifies valid subjects', () {
      expect(Subjects.isValid('Algorithmique et structures'), isTrue);
      expect(Subjects.isValid('Physique Quantique'), isFalse);
    });
  });

  group('Student Privacy & Safe Profile Tests (Directive #1 & Security)', () {
    test('ProfileModel does not expose email in serialization', () {
      final profile = ProfileModel(
        id: 'test-user-id',
        displayName: 'Nour Ben Ali',
        bio: 'Passionnée de tech',
        reliabilityScore: 100,
        createdAt: DateTime.now(),
      );

      final json = profile.toJson();
      expect(json.containsKey('email'), isFalse);
      expect(json['display_name'], 'Nour Ben Ali');
      expect(json['reliability_score'], 100);
    });

    test(
      'Updating profile modifies ONLY displayName and bio, never reliabilityScore',
      () async {
        final service = LocalDemoService.instance;
        final initialScore = service.currentProfile.reliabilityScore;

        // Update display name and bio
        await service.updateProfile(
          displayName: 'Amine Ben Salem (Modifié)',
          bio: 'Nouvelle bio mise à jour',
        );

        final updatedProfile = service.getProfile();
        expect(updatedProfile.displayName, 'Amine Ben Salem (Modifié)');
        expect(updatedProfile.bio, 'Nouvelle bio mise à jour');
        // Score MUST remain unchanged
        expect(updatedProfile.reliabilityScore, initialScore);
      },
    );
  });

  group('Capacity & Time Logic Tests (Directive #2 & #3)', () {
    test('StudyGroupModel computes remaining spots and ended status', () {
      final now = DateTime.now();
      final group = StudyGroupModel(
        id: 'g-test',
        creatorId: 'c-test',
        subject: 'Algorithmique et structures',
        topic: 'Complexité et tris',
        meetingLocation: 'Bibliothèque',
        startTime: now.add(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 4)),
        capacity: 5,
        memberCount: 3,
        createdAt: now,
      );

      expect(group.isEnded, isFalse);
      expect(group.isFull, isFalse);
      expect(group.remainingSpots, 2);
    });

    test(
      'LocalDemoService enforces capacity and prevents over-joining',
      () async {
        final service = LocalDemoService.instance;
        // Group 3 has capacity 4 and 4 members already
        expect(service.joinGroup('group-3'), throwsA(isA<Exception>()));
      },
    );
  });

  group('Reliability Score & Idempotency Tests (Directive #4)', () {
    test(
      'Attending confirmed session increases score and clamps to 100',
      () async {
        final service = LocalDemoService.instance;

        // Group 4 is past and user was confirmed
        final result = await service.recordMyAttendance('group-4', true);
        expect(result['success'], isTrue);
        expect(result['attended'], isTrue);
        expect(result['score_delta'], 5);
        expect(result['new_score'], 100); // Clamped at 100

        // Duplicate attendance recording must be rejected (Idempotency)
        expect(
          service.recordMyAttendance('group-4', true),
          throwsA(isA<Exception>()),
        );
      },
    );
  });

  group('SQL Migration & Environment Security Invariants', () {
    test(
      'SQL schema completely blocks direct profile updates and enforces update_my_profile',
      () {
        final sqlFile = File('supabase/migrations/20261018_initial_schema.sql');
        expect(sqlFile.existsSync(), isTrue);

        final content = sqlFile.readAsStringSync();

        // Must NOT have direct update policy
        expect(
          content.contains(
            'CREATE POLICY "Users can update their own profile"',
          ),
          isFalse,
        );

        // Must explicitly revoke direct mutation on profiles
        expect(
          content.contains(
            'REVOKE INSERT, UPDATE, DELETE ON public.profiles FROM authenticated, anon;',
          ),
          isTrue,
        );

        // Must contain secure update_my_profile RPC
        expect(content.contains('FUNCTION public.update_my_profile'), isTrue);

        // Must contain transactional join function
        expect(content.contains('FUNCTION public.join_study_group'), isTrue);

        // Must contain attendance scoring function
        expect(
          content.contains('FUNCTION public.record_my_attendance'),
          isTrue,
        );
      },
    );

    test(
      '.env and .env.example contain ONLY public client keys, never service-role secrets',
      () {
        final envFile = File('.env');
        final envExample = File('.env.example');

        expect(envFile.existsSync(), isTrue);
        expect(envExample.existsSync(), isTrue);

        final envContent = envFile.readAsStringSync();
        final exampleContent = envExample.readAsStringSync();

        for (final text in [envContent, exampleContent]) {
          expect(text.contains('service_role'), isFalse);
          expect(text.contains('SUPABASE_SERVICE_ROLE_KEY'), isFalse);
          expect(text.contains('SUPABASE_URL'), isTrue);
          expect(text.contains('SUPABASE_ANON_KEY'), isTrue);
        }
      },
    );
  });
}
