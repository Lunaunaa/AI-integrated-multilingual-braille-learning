import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:resonant_braille/tutor/http_tutor_gateway.dart';
import 'package:resonant_braille/tutor/voice_tutor_controller.dart';

void main() {
  test(
    'gateway sends only question, lesson context, history and verified cells',
    () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'answer': 'Verified by Resonant.',
            'source': 'verified_engine',
            'verified_examples': [
              {
                'text': 'a',
                'cells': [1],
              },
            ],
            'letter_examples': [
              {
                'letter': 'a',
                'cells': [1],
                'dots': [1],
                'capitalization': 'lowercase',
              },
            ],
            'sources': [
              {'title': 'ICEB UEB', 'url': 'https://iceb.org/rules.pdf'},
            ],
          }),
          200,
        );
      });
      final gateway = HttpTutorGateway(
        client: client,
        baseUri: Uri.parse('http://localhost:8000'),
      );
      final response = await gateway.ask(
        question: 'What is this letter?',
        history: const [TutorMessage('user', 'Hello')],
        lessonContext: 'Letter practice',
        verifiedExamples: const [
          VerifiedBrailleExample('a', [1]),
        ],
      );
      final payload = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(captured.url.path, '/ask');
      expect(payload['lesson_context'], 'Letter practice');
      expect(payload['history'], [
        {'role': 'user', 'content': 'Hello'},
      ]);
      expect(payload['verified_examples'], [
        {
          'text': 'a',
          'cells': [1],
        },
      ]);
      expect(response.verifiedExamples.single.cells, [1]);
      expect(response.letterExamples.single.spoken, 'a: dot 1 at top-left');
      expect(response.sources.single.title, 'ICEB UEB');
      client.close();
    },
  );

  test(
    'gateway reports HTTP failures without leaking response content',
    () async {
      final client = MockClient(
        (_) async => http.Response('secret backend details', 503),
      );
      final gateway = HttpTutorGateway(
        client: client,
        baseUri: Uri.parse('http://localhost:8000'),
      );
      await expectLater(
        gateway.ask(
          question: 'Explain Braille',
          history: const [],
          lessonContext: '',
          verifiedExamples: const [],
        ),
        throwsA(isA<TutorGatewayException>()),
      );
      client.close();
    },
  );

  test('gateway preserves deterministic multi-cell word examples', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'answer': 'The uncontracted spelling has three cells.',
          'source': 'verified_engine',
          'verified_examples': [
            {
              'text': 'cat',
              'cells': [9, 1, 30],
            },
          ],
          'letter_examples': [
            {
              'letter': 'c',
              'cells': [9],
              'dots': [1, 4],
              'capitalization': 'lowercase',
            },
            {
              'letter': 'a',
              'cells': [1],
              'dots': [1],
              'capitalization': 'lowercase',
            },
            {
              'letter': 't',
              'cells': [30],
              'dots': [2, 3, 4, 5],
              'capitalization': 'lowercase',
            },
          ],
          'sources': [
            {'title': 'ICEB UEB', 'url': 'https://iceb.org/publications/ueb/'},
          ],
        }),
        200,
      ),
    );
    final gateway = HttpTutorGateway(
      client: client,
      baseUri: Uri.parse('http://localhost:8000'),
    );
    final response = await gateway.ask(
      question: 'Show cat in Braille',
      history: const [],
      lessonContext: '',
      verifiedExamples: const [],
    );

    expect(response.verifiedExamples.single.text, 'cat');
    expect(response.verifiedExamples.single.cells, [9, 1, 30]);
    expect(response.letterExamples.map((letter) => letter.letter), [
      'c',
      'a',
      't',
    ]);
    expect(response.sources.single.title, 'ICEB UEB');
    client.close();
  });
}
