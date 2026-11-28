import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';
import 'package:omni_route/src/routing/omni_path.dart';

Matcher throwsCode(OmniErrorCode c) =>
    throwsA(isA<OmniRouteException>().having((e) => e.code, 'code', c));

void main() {
  test('valid paths', () {
    for (final p in [
      '/',
      '/students',
      '/students/:id',
      '/a-b/c_d/:userId',
      '/files/*',
      '/docs/*rest',
    ]) {
      expect(
        () => validateRoutePath(p, topLevel: true),
        returnsNormally,
        reason: p,
      );
    }
    expect(() => validateRoutePath(':id', topLevel: false), returnsNormally);
    expect(() => validateRoutePath('daily', topLevel: false), returnsNormally);
    expect(() => validateRoutePath('*tail', topLevel: false), returnsNormally);
  });

  test('invalid paths', () {
    expect(
      () => validateRoutePath('', topLevel: true),
      throwsCode(OmniErrorCode.emptyRoutePath),
    );
    for (final p in [
      'students',
      '/Students',
      '/students/',
      '//a',
      '/#/a',
      '/a?x=1',
      '/a/:1d',
      '/a/:id/:id',
      '/a b',
      '/files/*/more',
      '/files/*bad-name',
    ]) {
      expect(
        () => validateRoutePath(p, topLevel: true),
        throwsCode(OmniErrorCode.invalidRoutePath),
        reason: p,
      );
    }
    expect(
      () => validateRoutePath('/child', topLevel: false),
      throwsCode(OmniErrorCode.invalidRoutePath),
    );
  });

  test('duplicates', () {
    expect(() => checkDuplicatePaths(['/a', '/a/:id', '/b']), returnsNormally);
    expect(
      () => checkDuplicatePaths(['/a', '/a']),
      throwsCode(OmniErrorCode.duplicateRoute),
    );
    expect(
      () => checkDuplicatePaths(['/a/:id', '/a/:slug']),
      throwsCode(OmniErrorCode.duplicateRoute),
    );
    expect(
      () => checkDuplicatePaths(['/files/*a', '/files/*b']),
      throwsCode(OmniErrorCode.duplicateRoute),
    );
  });

  test('exception message has hint', () {
    expect(
      () => validateRoutePath('/Students', topLevel: true),
      throwsA(predicate((e) => e.toString().contains('Use "students"'))),
    );
  });
}
