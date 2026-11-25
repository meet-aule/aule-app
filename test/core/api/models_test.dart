import 'dart:convert';

import 'package:aule/core/api/json.dart';
import 'package:aule/core/api/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// The platform's own JSON shapes (SPEC §7, from apps/platform/src).
Json decode(String text) => jsonDecode(text) as Json;

void main() {
  test('Me from GET /v1/me', () {
    final me = Me.fromJson(
      decode(
        '{"guardian":{"id":"g1","email":"ana@example.com","name":"Ana",'
        '"language":"es","notices_by_email":true,"notices_by_push":true},'
        '"family_id":"f1","children":[{"id":"c1","nickname":"Mati"}],'
        '"unread_notices":1,"subjects":["matematica","comunicacion",'
        '"ciencia","personal_social","ingles"]}',
      ),
    );
    expect(me.guardian.id, 'g1');
    expect(me.guardian.email, 'ana@example.com');
    expect(me.guardian.name, 'Ana');
    expect(me.guardian.language, 'es');
    expect(me.guardian.noticesByEmail, isTrue);
    expect(me.familyId, 'f1');
    expect(me.children.single.nickname, 'Mati');
    expect(me.unreadNotices, 1);
    expect(me.subjects, hasLength(5));
  });

  test('Guardian defaults: Spanish, notices on', () {
    final guardian = Guardian.fromJson(
      decode('{"id":"g","email":"e@example.com","name":"N"}'),
    );
    expect(guardian.language, 'es');
    expect(guardian.noticesByEmail, isTrue);
    expect(guardian.noticesByPush, isTrue);
    final changed = guardian.copyWith(language: 'en', noticesByEmail: false);
    expect(changed.language, 'en');
    expect(changed.noticesByEmail, isFalse);
    expect(changed.email, 'e@example.com');
  });

  test('ChildDetail from GET /v1/children/{id}', () {
    final detail = ChildDetail.fromJson(
      decode(
        '{"child":{"id":"c1","family_id":"f1","nickname":"Mati",'
        '"birth_year":2018,"grade":"P3","language":"es",'
        '"interests":["fútbol"],"subjects":["matematica"],'
        '"notes":"from the team","tutor_name":"Aule",'
        '"tutor_persona":"jugueton","tutor_persona_note":"va despacio",'
        '"created_at":"2026-10-01T12:00:00Z"},'
        '"consent":{"memory":true,"transcripts":false,"voice":true},'
        '"relationship":"MTH"}',
      ),
    );
    expect(detail.child.nickname, 'Mati');
    expect(detail.child.birthYear, 2018);
    expect(detail.child.grade, 'P3');
    expect(detail.child.notes, 'from the team');
    expect(detail.child.tutorPersona, 'jugueton');
    expect(detail.child.tutorPersonaNote, 'va despacio');
    expect(detail.consent.voice, isTrue);
    expect(detail.consent.memory, isTrue);
    expect(detail.consent.transcripts, isFalse);
    expect(detail.relationship, 'MTH');
  });

  test('a child with no consent rows counts as none granted', () {
    final detail = ChildDetail.fromJson(
      decode(
        '{"child":{"id":"c1","family_id":"f1","nickname":"Lu",'
        '"created_at":"2026-10-01T12:00:00Z"}}',
      ),
    );
    expect(detail.consent.of(ConsentPurpose.voice), isFalse);
    expect(detail.child.language, 'es');
    expect(detail.child.tutorName, 'Aule');
    expect(detail.child.tutorPersona, ChildCodes.defaultPersona);
    expect(detail.relationship, isNull);
  });

  test('TokenGrant never prints its token', () {
    final grant = TokenGrant.fromJson(
      decode(
        '{"token":"${'a' * 64}","guardian_id":"g","family_id":"f",'
        '"new_account":true}',
      ),
    );
    expect(grant.newAccount, isTrue);
    expect(grant.expiresInDays, 30);
    expect(grant.toString(), isNot(contains('aaaa')));
  });

  test('ConsentAnswer as the platform takes it', () {
    const answer = ConsentAnswer(
      purpose: ConsentPurpose.transcripts,
      granted: false,
      policyVersion: 'app-2026-11-v1',
      locale: 'es-PE',
    );
    expect(answer.toJson(), <String, dynamic>{
      'purpose': 'transcripts',
      'granted': false,
      'policy_version': 'app-2026-11-v1',
      'locale': 'es-PE',
    });
  });

  test('Review, SkillReport and SkillInfo', () {
    final review = Review.fromJson(
      decode(
        '{"session_id":"s1","summary":"Practicó sumas.",'
        '"next_step":"Seguir.","flags":["struggling"],'
        '"created_at":"2026-11-20T10:00:00Z"}',
      ),
    );
    expect(review.sessionId, 's1');
    expect(review.flags, <String>['struggling']);

    final report = SkillReport.fromJson(
      decode(
        '{"ability":0.4,"skills":['
        '{"skill_id":"a","attempts":3,"p_known":0.9,"p_now":0.9,"p_7d":0.8,'
        '"half_life_days":10,"mastered":true,"target_difficulty":0.5,'
        '"corrected":false},'
        '{"skill_id":"b","attempts":2,"p_known":0.4,"p_now":0.4,"p_7d":0.3,'
        '"half_life_days":2,"review_at":"2026-11-26T00:00:00Z",'
        '"mastered":false,"target_difficulty":0.5,"corrected":true},'
        '{"skill_id":"c","attempts":0,"p_known":0.1,"p_now":0.1,"p_7d":0.1,'
        '"half_life_days":1,"mastered":false,"target_difficulty":0.5,'
        '"corrected":false}],'
        '"next":[{"skill_id":"b","name":"Tabla del 4","reason":"in_progress",'
        '"p_now":0.4}]}',
      ),
    );
    // Counted as the web counts them: only skills with an attempt.
    expect(report.worked, hasLength(2));
    expect(report.masteredCount, 1);
    expect(report.practisingCount, 1);
    expect(report.skills[1].reviewAt, isNotNull);
    expect(report.next.single.name, 'Tabla del 4');
    expect(report.next.single.targetDifficulty, isNull);

    final info = SkillInfo.fromJson(
      decode(
        '{"id":"tabla-4","subject":"matematica","name":"Tabla del 4",'
        '"grade":"P3","prerequisites":["tabla-2"]}',
      ),
    );
    expect(info.prerequisites, <String>['tabla-2']);
    expect(info.description, isNull);
  });

  test('SessionFact (gap 3) and SessionStatus', () {
    final fact = SessionFact.fromJson(
      decode(
        '{"id":"s1","status":"ended","created_at":"2026-11-20T10:00:00Z",'
        '"started_at":"2026-11-20T10:00:30Z","ended_at":"2026-11-20T10:18:30Z",'
        '"end_reason":"budget_reached","engine":true,"language":"es",'
        '"objective":{"kind":"homework","subject":"matematica",'
        '"topic":"fracciones","due":"2026-11-21"},"on_device":false,'
        '"reviewed":true}',
      ),
    );
    expect(fact.isLive, isFalse);
    expect(fact.duration, const Duration(minutes: 18));
    expect(fact.objective!.topic, 'fracciones');

    final live = SessionFact.fromJson(
      decode(
        '{"id":"s2","status":"active","created_at":"2026-11-25T10:00:00Z",'
        '"objective":null,"on_device":true}',
      ),
    );
    expect(live.isLive, isTrue);
    expect(live.duration, isNull);
    expect(live.objective, isNull);

    final status = SessionStatus.fromJson(
      decode(
        '{"status":"created","remaining_seconds":840,"can_resume":false,'
        '"language":"es","engine":true}',
      ),
    );
    expect(status.isLive, isTrue);
    expect(status.remainingSeconds, 840);
  });

  test('Memory and Notice', () {
    final memory = Memory.fromJson(
      decode(
        '{"id":"m1","kind":"preference","content":"Le encanta el fútbol.",'
        '"created_at":"2026-11-20T10:00:00Z"}',
      ),
    );
    expect(memory.kind, 'preference');

    final notice = Notice.fromJson(
      decode(
        '{"id":"n1","child_id":"c1","session_id":null,"kind":"attention",'
        '"title":"Mati puede necesitarte","body":"Durante una sesión…",'
        '"created_at":"2026-11-24T10:00:00Z","read_at":null}',
      ),
    );
    expect(notice.unread, isTrue);
    expect(notice.sessionId, isNull);
    final read = notice.markedRead(DateTime.utc(2026, 11, 25));
    expect(read.unread, isFalse);
    // Marking twice keeps the first time.
    expect(read.markedRead(DateTime.utc(2027)).readAt, read.readAt);
  });

  test('a malformed answer is a FormatException', () {
    expect(
      () => Notice.fromJson(decode('{"id":"n1","kind":"attention"}')),
      throwsFormatException,
    );
  });
}
