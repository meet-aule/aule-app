import 'package:aule/core/api/models/models.dart';
import 'package:aule/core/l10n/labels.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

void main() {
  test('every code of the platform has a Spanish label', () {
    for (final code in ChildCodes.grades) {
      expect(es.grade(code), isNot(code), reason: code);
    }
    expect(es.grade('P3'), '3.º de primaria');
    expect(es.subject('personal_social'), 'Personal Social');
    expect(es.subject('other'), es.subjectOther);
    expect(es.personaTitle('jugueton'), 'Juguetón');
    expect(es.personaHint('tranquilo'), 'pausado, sin apuro');
    expect(es.relationship('MTH'), 'Mamá');
    expect(en.relationship('GUARD'), 'Legal guardian');
  });

  test('end reasons: both errors read the same, unknown is just ended', () {
    expect(es.endReason('error', 'Mati'), es.endReasonError);
    expect(es.endReason('provider_error', 'Mati'), es.endReasonError);
    expect(es.endReason('child_ended', 'Mati'), 'La terminó Mati');
    expect(es.endReason('something_new', 'Mati'), es.endReasonOther);
  });

  test('unknown flags, reasons and memory kinds show nothing', () {
    expect(es.flag('struggling'), 'Le costó');
    expect(es.flag('unheard_of'), isNull);
    expect(es.nextReason('ready'), 'Lo siguiente');
    expect(es.nextReason(''), isNull);
    expect(es.memoryKind('success'), 'Un logro');
    expect(es.memoryKind('dream'), isNull);
  });

  test('an unknown notice kind is a plain notice', () {
    expect(es.noticeKind('attention'), 'Necesita tu atención');
    expect(es.noticeKind('newsletter'), es.noticeKindOther);
  });

  test('objectives read as kind and subject', () {
    expect(
      es.objective(const Objective(kind: 'homework', subject: 'matematica')),
      'Tarea de Matemática',
    );
    expect(
      en.objective(const Objective(kind: 'exam_prep', subject: 'ingles')),
      'Preparing for a test: English',
    );
    expect(es.objective(const Objective(kind: 'explore')), 'Explorar');
    expect(
      es.objective(const Objective(kind: 'explore', subject: 'comunicacion')),
      'Explorar Comunicación',
    );
    expect(
      es.objective(const Objective(kind: 'exam_review', subject: 'ingles')),
      'Revisar un examen de Inglés',
    );
    expect(
      es.objective(const Objective(kind: 'mystery', subject: 'ciencia')),
      'Ciencia y Tecnología',
    );
    expect(es.objective(const Objective(kind: 'mystery')), '');
  });

  test('the skills line has a form for every case', () {
    expect(
      es.skillsLine(3, 2),
      'Domina 3 habilidades y está practicando 2 más.',
    );
    expect(es.skillsLine(1, 0), 'Domina 1 habilidad.');
    expect(es.skillsLine(0, 3), 'Está practicando 3 habilidades.');
    expect(en.skillsLine(0, 1), 'Is practicing 1 skill.');
    expect(
      en.skillsLine(2, 1),
      'Has mastered 2 skills and is practicing 1 more.',
    );
  });
}
