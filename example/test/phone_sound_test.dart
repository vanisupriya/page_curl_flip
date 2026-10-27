import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_curl_flip/page_curl_flip.dart';
import 'package:page_curl_flip_example/phone_sound.dart';
import 'package:page_curl_flip_example/shared_pages.dart';

/// A one-page book wired the way the LTR and RTL books are.
class _Host extends StatefulWidget {
  const _Host();
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with PhoneSoundWatch {
  @override
  void initState() {
    super.initState();
    startPhoneSoundWatch(every: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    stopPhoneSoundWatch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: FlipBook(
      onClose: () {},
      footer: FlipBookFooter(
        autoHide: false,
        sound: FlipBookSound(
          onFlip: () async {},
          silenced: phone.silent,
          onSilencedTap: () => showPhoneNote('silent note'),
        ),
      ),
      readAloud: FlipBookReadAloud(
        onRead: (_) async => noteVolumeOnce('volume note'),
      ),
      pages: const FlipBookPages(
        items: [
          FlipBookPage(title: 'One', body: Text('page one')),
          FlipBookPage(title: 'Two', body: Text('page two')),
        ],
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var answer = <String, Object?>{'silent': false, 'volumeOff': false};

  setUp(() {
    answer = {'silent': false, 'volumeOff': false};
    messenger.setMockMethodCallHandler(
      kPhoneSoundChannel,
      (call) async => call.method == 'read' ? answer : null,
    );
  });
  tearDown(() => messenger.setMockMethodCallHandler(kPhoneSoundChannel, null));

  test(
    'the platform answer becomes a PhoneSound; a failure reads as sound on',
    () async {
      answer = {'silent': true, 'volumeOff': true};
      expect(
        await readPhoneSound(),
        const PhoneSound(silent: true, volumeOff: true),
      );
      messenger.setMockMethodCallHandler(
        kPhoneSoundChannel,
        (_) async => throw PlatformException(code: 'x'),
      );
      expect(await readPhoneSound(), const PhoneSound());
      messenger.setMockMethodCallHandler(kPhoneSoundChannel, null);
      expect(await readPhoneSound(), const PhoneSound());
    },
  );

  testWidgets(
    'SND-08 SND-09: the phone on silent mutes the speaker live; a tap shows the snack bar',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _Host()));
      await tester.pump();
      expect(find.byIcon(Icons.volume_up), findsOneWidget);

      answer = {'silent': true, 'volumeOff': false};
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(find.byIcon(Icons.volume_off), findsOneWidget);

      await tester.tap(find.byIcon(Icons.volume_off));
      await tester.pump();
      expect(find.text('silent note'), findsOneWidget);
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(
        bar.backgroundColor,
        kPink,
        reason: 'the book\'s accent, not the grey default',
      );
      expect(find.byType(PhoneNote), findsOneWidget);

      answer = {'silent': false, 'volumeOff': false};
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
    },
  );

  testWidgets(
    'a zero volume shows the volume snack bar once when reading starts',
    (tester) async {
      answer = {'silent': false, 'volumeOff': true};
      await tester.pumpWidget(const MaterialApp(home: _Host()));
      await tester.pump();
      final book = tester.widget<FlipBook>(find.byType(FlipBook));
      await book.readAloud!.onRead('a');
      await tester.pump();
      expect(find.text('volume note'), findsOneWidget);
      ScaffoldMessenger.of(
        tester.element(find.byType(FlipBook)),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await book.readAloud!.onRead('b');
      await tester.pump();
      expect(
        find.text('volume note'),
        findsNothing,
        reason: 'once per open book',
      );
    },
  );

  testWidgets('the note fits a 320-wide phone at 2× text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    answer = {'silent': true, 'volumeOff': false};
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2.0)),
          child: child!,
        ),
        home: const _Host(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.byIcon(Icons.volume_off));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneNote), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
