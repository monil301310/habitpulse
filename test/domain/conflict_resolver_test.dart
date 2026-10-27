import 'package:flutter_test/flutter_test.dart';
import 'package:habitpulse/domain/sync/conflict_resolver.dart';

void main() {
  final base = DateTime.utc(2026, 10, 26, 12, 0, 0);

  group('newest wins', () {
    test('applies when there is no local copy', () {
      expect(
        shouldApplyRemote(remoteUpdatedAt: base, localUpdatedAt: null),
        isTrue,
      );
    });

    test('applies a newer remote row', () {
      expect(
        shouldApplyRemote(
          localUpdatedAt: base,
          remoteUpdatedAt: base.add(const Duration(minutes: 1)),
        ),
        isTrue,
      );
    });

    test('ignores an older remote row', () {
      expect(
        shouldApplyRemote(
          localUpdatedAt: base,
          remoteUpdatedAt: base.subtract(const Duration(minutes: 1)),
        ),
        isFalse,
      );
    });

    test('ignores an equal timestamp for non-log rows', () {
      expect(
        shouldApplyRemote(localUpdatedAt: base, remoteUpdatedAt: base),
        isFalse,
      );
    });
  });

  group('done wins for logs inside the window', () {
    test('remote done beats a slightly older local missed', () {
      expect(
        shouldApplyRemote(
          localUpdatedAt: base,
          remoteUpdatedAt: base.subtract(const Duration(seconds: 2)),
          isLog: true,
          localStatus: 'missed',
          remoteStatus: 'done',
        ),
        isTrue,
      );
    });

    test('local done is not replaced by a slightly newer remote missed', () {
      expect(
        shouldApplyRemote(
          localUpdatedAt: base,
          remoteUpdatedAt: base.add(const Duration(seconds: 2)),
          isLog: true,
          localStatus: 'done',
          remoteStatus: 'missed',
        ),
        isFalse,
      );
    });

    test('remote done wins even at the same timestamp', () {
      expect(
        shouldApplyRemote(
          localUpdatedAt: base,
          remoteUpdatedAt: base,
          isLog: true,
          localStatus: 'partial',
          remoteStatus: 'done',
        ),
        isTrue,
      );
    });

    test('both done: newest timestamp decides', () {
      expect(
        shouldApplyRemote(
          localUpdatedAt: base,
          remoteUpdatedAt: base.add(const Duration(seconds: 1)),
          isLog: true,
          localStatus: 'done',
          remoteStatus: 'done',
        ),
        isTrue,
      );
    });

    test('outside the window, newest wins even for done/missed', () {
      expect(
        shouldApplyRemote(
          localUpdatedAt: base,
          remoteUpdatedAt: base.subtract(const Duration(seconds: 10)),
          isLog: true,
          localStatus: 'missed',
          remoteStatus: 'done',
        ),
        isFalse,
      );

      expect(
        shouldApplyRemote(
          localUpdatedAt: base,
          remoteUpdatedAt: base.add(const Duration(seconds: 10)),
          isLog: true,
          localStatus: 'done',
          remoteStatus: 'missed',
        ),
        isTrue,
      );
    });
  });
}
