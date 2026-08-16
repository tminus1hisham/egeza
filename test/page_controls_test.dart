import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:egesha/widgets/app_widgets.dart';

/// Screens carry no titles or headers any more, so these bare controls are the
/// only chrome left on a page. They are shared by every non-home screen.
void main() {
  Widget host(Widget child, {double width = 320}) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [child],
            ),
          ),
        ),
      ),
    );
  }

  group('PageAction', () {
    testWidgets('renders no surface, border or shadow of its own',
        (tester) async {
      await tester.pumpWidget(host(
        PageAction(
          icon: Icons.search_rounded,
          tooltip: 'Search history',
          onTap: () {},
        ),
      ));

      // The point of the rework: controls are bare. Any filled or bordered
      // decoration would be a button chrome sneaking back in.
      final decorations = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(PageAction),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>();

      for (final d in decorations) {
        expect(d.color, anyOf(isNull, Colors.transparent));
        expect(d.gradient, isNull);
        expect(d.border, isNull);
        expect(d.boxShadow, anyOf(isNull, isEmpty));
      }
    });

    testWidgets('keeps a 44px minimum tap target', (tester) async {
      await tester.pumpWidget(host(
        PageAction(icon: Icons.add_rounded, tooltip: 'Add', onTap: () {}),
      ));

      final size = tester.getSize(
        find
            .descendant(
              of: find.byType(PageAction),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('carries a semantic label, since it has no visible text',
        (tester) async {
      await tester.pumpWidget(host(
        PageAction(
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh',
          onTap: () {},
        ),
      ));

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.semanticLabel, 'Refresh');
    });

    testWidgets('fires its callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(
        PageAction(
          icon: Icons.search_rounded,
          tooltip: 'Search',
          onTap: () => taps++,
        ),
      ));

      await tester.tap(find.byType(PageAction));
      expect(taps, 1);
    });
  });

  group('PageBackButton', () {
    testWidgets('pops the route when tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(
                      body: SafeArea(child: PageBackButton()),
                    ),
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byType(PageBackButton), findsOneWidget);

      // Tap the control itself, not PageBackButton: the Align it uses spans
      // the full row width, so the row's centre is empty space.
      await tester.tap(find.byType(PageAction));
      await tester.pumpAndSettle();
      expect(find.text('go'), findsOneWidget);
    });

    testWidgets('prefers an explicit onBack over popping', (tester) async {
      var custom = 0;
      await tester.pumpWidget(host(PageBackButton(onBack: () => custom++)));

      await tester.tap(find.byType(PageAction));
      expect(custom, 1);
    });

    testWidgets('sits flush against the left page gutter', (tester) async {
      await tester.pumpWidget(host(PageBackButton(onBack: () {})));

      // Nudged out by 10px so the arrow's optical edge lands on the gutter
      // rather than the edge of its 44px tap target.
      final left = tester.getTopLeft(find.byType(PageAction)).dx;
      expect(left, 20 - 10);
    });

    testWidgets('names the page when given a label', (tester) async {
      await tester.pumpWidget(host(
        PageBackButton(label: 'Security', onBack: () {}),
      ));

      expect(find.text('Security'), findsOneWidget);
    });

    testWidgets('the label adds no surface of its own', (tester) async {
      await tester.pumpWidget(host(
        PageBackButton(label: 'Security', onBack: () {}),
      ));

      // The label is chrome attached to a control, not a header band. Any
      // fill, border or shadow would be the rejected title block returning.
      final decorations = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(PageBackButton),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>();

      for (final d in decorations) {
        expect(d.color, anyOf(isNull, Colors.transparent));
        expect(d.gradient, isNull);
        expect(d.border, isNull);
        expect(d.boxShadow, anyOf(isNull, isEmpty));
      }
    });

    testWidgets('keeps the arrow on the gutter with a label', (tester) async {
      await tester.pumpWidget(host(
        PageBackButton(label: 'Security', onBack: () {}),
      ));

      expect(tester.getTopLeft(find.byType(PageAction)).dx, 20 - 10);
    });
  });

  group('PageHero', () {
    PageHero hero({VoidCallback? onBack, VoidCallback? onTap}) => PageHero(
          eyebrow: 'Registered fleet',
          value: '4 vehicles',
          onBack: onBack,
          onTap: onTap,
          pill: const PageHeroPill(
            icon: Icons.camera_alt_outlined,
            label: 'ANPR ready',
          ),
          metrics: const [
            PageHeroMetric('AutoPay on', '3'),
            PageHeroMetric('Manual', '1'),
            PageHeroMetric('Parked now', '1'),
          ],
        );

    testWidgets('renders eyebrow, value, pill and metrics', (tester) async {
      await tester.pumpWidget(host(hero()));

      // The eyebrow is what names the page now that headers are gone.
      expect(find.text('Registered fleet'), findsOneWidget);
      expect(find.text('4 vehicles'), findsOneWidget);
      expect(find.text('ANPR ready'), findsOneWidget);
      for (final label in ['AutoPay on', 'Manual', 'Parked now']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('carries no back control on a root screen', (tester) async {
      await tester.pumpWidget(host(hero()));

      expect(find.byType(PageAction), findsNothing);
    });

    testWidgets('inlines a back control on a pushed route', (tester) async {
      var backs = 0;
      await tester.pumpWidget(host(hero(onBack: () => backs++)));

      expect(find.byType(PageAction), findsOneWidget);
      await tester.tap(find.byType(PageAction));
      expect(backs, 1);
    });

    testWidgets('fires onTap when the whole card is a link', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(hero(onTap: () => taps++)));

      await tester.tap(find.text('4 vehicles'));
      expect(taps, 1);
    });

    testWidgets('is inert when it is not a link', (tester) async {
      await tester.pumpWidget(host(hero()));

      final inkWell = tester.widget<InkWell>(
        find.descendant(
          of: find.byType(PageHero),
          matching: find.byType(InkWell),
        ),
      );
      expect(inkWell.onTap, isNull);
    });
  });

  group('AdaptiveStatusBar', () {
    testWidgets('sets dark status bar icons under a light theme',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: const AdaptiveStatusBar(child: Scaffold(body: SizedBox())),
        ),
      );

      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(region.value.statusBarIconBrightness, Brightness.dark);
    });

    testWidgets('sets light status bar icons under a dark theme',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: const AdaptiveStatusBar(child: Scaffold(body: SizedBox())),
        ),
      );

      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(region.value.statusBarIconBrightness, Brightness.light);
    });
  });
}
