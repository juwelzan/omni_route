// Measures native OmniRoute engine startup, push/pop latency, instant
// no-transition navigation, and memory growth across hundreds of cycles.
// Run in profile mode:
//   flutter run --profile -d macos -t benchmark/benchmark_main.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_route/omni_route.dart';

const cycles = int.fromEnvironment('CYCLES', defaultValue: 300);

class ItemBloc extends Bloc<int, int> {
  ItemBloc(super.id) {
    on<int>((e, emit) => emit(e));
  }
}

class ListBloc extends Bloc<int, int> {
  ListBloc() : super(0);
}

Widget itemBody(int id, BuildContext context) => Scaffold(
  appBar: AppBar(title: Text('Item $id')),
  body: ListView.builder(
    itemCount: 30,
    itemBuilder: (_, i) =>
        ListTile(title: Text('Row $i of ${context.read<ItemBloc>().state}')),
  ),
);

Widget homeBody() => Scaffold(
  appBar: AppBar(title: const Text('Home')),
  body: ListView.builder(
    itemCount: 30,
    itemBuilder: (_, i) => ListTile(title: Text('Item $i')),
  ),
);

class OHome extends OmniStatelessWidget {
  const OHome({super.key});
  @override
  String get routePath => '/';
  @override
  List<Provide> get provide => const [Provide<ListBloc>()];
  @override
  Widget build(BuildContext context) => homeBody();
}

class OItem extends OmniStatelessWidget {
  const OItem(this.id, {super.key});
  final int id;
  @override
  String get routePath => '/item/:id';
  @override
  List<Provide> get provide => [Provide<ItemBloc>.create((_) => ItemBloc(id))];
  @override
  Widget build(BuildContext context) => itemBody(id, context);
}

Widget omniApp({OmniPageType transition = OmniPages.material}) => OmniApp(
  transition: transition,
  blocs: [OmniBloc<ListBloc>((_) => ListBloc())],
  routes: [
    OmniPage('/', (_) => const OHome()),
    OmniPage('/item/:id', (p) => OItem(p.pathInt('id'))),
  ],
  builder: (_, r) => MaterialApp.router(routerConfig: r),
);

/// Drives frames manually so benchmarks run accurately without vsync.
class FrameDriver {
  FrameDriver(this.binding);
  final WidgetsBinding binding;
  Duration _clock = Duration.zero;
  final uiFrameUs = <int>[];

  int frame() {
    final sw = Stopwatch()..start();
    _clock += const Duration(microseconds: 16667);
    binding.handleBeginFrame(_clock);
    binding.handleDrawFrame();
    final us = sw.elapsedMicroseconds;
    uiFrameUs.add(us);
    return us;
  }

  /// Steps frames until animations settle. Returns total UI thread time in us.
  int settle() {
    var total = 0;
    for (var i = 0; i < 300 && (i == 0 || binding.hasScheduledFrame); i++) {
      total += frame();
    }
    return total;
  }

  void show(Widget w) {
    binding.attachRootWidget(binding.wrapWithDefaultView(w));
    binding.scheduleFrame();
  }
}

int pct(List<int> xs, double p) {
  final s = [...xs]..sort();
  return s[((s.length - 1) * p).round()];
}

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  await Future<void>.delayed(const Duration(seconds: 2));

  void run(
    String key,
    Widget app,
    void Function(String) push,
    void Function() pop,
  ) {
    final d = FrameDriver(binding);
    d.show(const SizedBox());
    d.settle();
    final rssStart = ProcessInfo.currentRss;

    final sw = Stopwatch()..start();
    d.show(app);
    d.settle();
    final startupUs = sw.elapsedMicroseconds;

    for (var i = 0; i < 20; i++) {
      push('/item/$i');
      d.settle();
      pop();
      d.settle();
    }
    d.uiFrameUs.clear();

    final pushUs = <int>[], popUs = <int>[], pushTotalUs = <int>[];
    for (var i = 0; i < cycles; i++) {
      push('/item/$i');
      pushUs.add(d.frame());
      pushTotalUs.add(pushUs.last + d.settle());
      pop();
      popUs.add(d.frame());
      d.settle();
    }
    final rssEnd = ProcessInfo.currentRss;
    final metrics = {
      'startup_to_settled_us': startupUs,
      'push_first_frame_ui_us_p50': pct(pushUs, .5),
      'push_first_frame_ui_us_p90': pct(pushUs, .9),
      'push_all_frames_ui_us_p50': pct(pushTotalUs, .5),
      'pop_first_frame_ui_us_p50': pct(popUs, .5),
      'pop_first_frame_ui_us_p90': pct(popUs, .9),
      'ui_frame_us_p50': pct(d.uiFrameUs, .5),
      'ui_frame_us_p99': pct(d.uiFrameUs, .99),
      'ui_frame_us_max': pct(d.uiFrameUs, 1),
      'frames_measured': d.uiFrameUs.length,
      'rss_growth_kb': (rssEnd - rssStart) ~/ 1024,
    };
    // ignore: avoid_print
    print('BENCH ${jsonEncode({key: metrics})}');
    d.show(const SizedBox());
    d.settle();
  }

  const rounds = int.fromEnvironment('ROUNDS', defaultValue: 3);
  for (var round = 1; round <= rounds; round++) {
    run(
      'omni_material_$round',
      omniApp(),
      (l) => OmniRoute.push(l),
      OmniRoute.pop,
    );
    run(
      'omni_instant_$round',
      omniApp(transition: OmniPages.none),
      (l) => OmniRoute.push(l, animated: false),
      OmniRoute.pop,
    );
  }
  // ignore: avoid_print
  print('BENCH done');
  exit(0);
}
