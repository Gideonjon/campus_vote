import 'package:campus_vote/services/election_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matric numbers are normalised to safe document ids', () {
    expect(ElectionService.normalizeMatric(' 18/cs/1001 '), '18-CS-1001');
    expect(ElectionService.normalizeMatric('18 CS 1001'), '18-CS-1001');
    expect(ElectionService.normalizeMatric('/18//cs/'), '18-CS');
  });
}
