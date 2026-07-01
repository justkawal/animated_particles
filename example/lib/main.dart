import 'dart:ui' as ui show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:animated_particles/animated_particles.dart';

const bool kLogFrameStats = false;

void main() {
  if (kLogFrameStats) {
    WidgetsFlutterBinding.ensureInitialized();
    _FrameStats().attach();
  }
  runApp(const ParticleApp());
}

class _FrameStats {
  static const double _budgetMs = 16.7;
  int _frames = 0;
  int _jankUi = 0;
  int _jankRaster = 0;
  double _maxUi = 0;
  double _maxRaster = 0;
  double _sumUi = 0;
  double _sumRaster = 0;

  void attach() {
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      final ui = t.buildDuration.inMicroseconds / 1000.0;
      final raster = t.rasterDuration.inMicroseconds / 1000.0;
      _frames++;
      _sumUi += ui;
      _sumRaster += raster;
      if (ui > _maxUi) _maxUi = ui;
      if (raster > _maxRaster) _maxRaster = raster;
      if (ui > _budgetMs) _jankUi++;
      if (raster > _budgetMs) _jankRaster++;
    }
    if (_frames >= 120) {
      debugPrint(
        'FRAMESTATS frames=$_frames '
        'uiAvg=${(_sumUi / _frames).toStringAsFixed(2)} uiMax=${_maxUi.toStringAsFixed(2)} '
        'rasterAvg=${(_sumRaster / _frames).toStringAsFixed(2)} rasterMax=${_maxRaster.toStringAsFixed(2)} '
        'jankUI=$_jankUi jankRaster=$_jankRaster (budget ${_budgetMs}ms)',
      );
      _frames = 0;
      _jankUi = 0;
      _jankRaster = 0;
      _maxUi = 0;
      _maxRaster = 0;
      _sumUi = 0;
      _sumRaster = 0;
    }
  }
}

const Color _kCanvas = Color(0xFF07080B);

const Color _kParticleIce = Color(0xFFEAF2FF);

const Color _kAccent = Color(0xFF4DE3C2);

const Color _kGlassFill = Color(0x14FFFFFF);
const Color _kGlassHairline = Color(0x24FFFFFF);
const Color _kTextSecondary = Color(0x99FFFFFF);

const Color _kTextTertiary = Color(0x66FFFFFF);
const Color _kShadow = Color(0x66000000);

const List<String> _kMonoFallback = <String>[
  'SF Mono',
  'Menlo',
  'Roboto Mono',
  'monospace',
];

class ParticleApp extends StatelessWidget {
  const ParticleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: 'animated_particles',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: _kAccent,
          surfaceTint: _kAccent,
        ),
      ),
      home: const ParticleDemoPage(),
    );
  }
}

class ParticleDemoPage extends StatefulWidget {
  const ParticleDemoPage({super.key});

  @override
  State<ParticleDemoPage> createState() => _ParticleDemoPageState();
}

class _ParticleDemoPageState extends State<ParticleDemoPage> {
  late final ParticleFieldController _controller;

  EscapePosition _escape = EscapePosition.bottom;

  static const TextStyle _textStyle = TextStyle(
    fontSize: 130,
    fontWeight: FontWeight.w800,
    letterSpacing: 2,
    height: 1.0,
  );

  static const List<_GalleryEntry> _entries = <_GalleryEntry>[
    _GalleryEntry(key: 'flutter', label: 'Flutter'),
    _GalleryEntry(key: 'impeller', label: 'impeller'),
    _GalleryEntry(key: 'render', label: 'render'),
    _GalleryEntry(key: 'dash', icon: Icons.flutter_dash),
    _GalleryEntry(key: 'heart', icon: Icons.favorite),
    _GalleryEntry(key: 'bolt', icon: Icons.bolt),
    _GalleryEntry(key: 'snow', icon: CupertinoIcons.snow),
  ];

  @override
  void initState() {
    super.initState();
    _controller = ParticleFieldController(
      config: const ParticleFieldConfig(
        color: _kParticleIce,
        particleSize: 1.4,
        maxSpeed: 12,
        maxForce: 3,
        arrivalRadius: 100,
        fleeRadius: 50,
        escapePosition: EscapePosition.bottom,
        shape: ParticleShape.circle,
        antiAlias: true,
        fillFraction: 0.72,
        alignment: Alignment(0.0, -0.35),
      ),
    );

    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    await _controller.addTargets(<String, ParticleTarget>{
      'flutter': ParticleTarget.text('Flutter', style: _textStyle, stride: 2),
      'impeller':
          ParticleTarget.text('impeller', style: _textStyle, stride: 2),
      'render': ParticleTarget.text('render', style: _textStyle, stride: 2),
      'dash': ParticleTarget.icon(Icons.flutter_dash, size: 260, stride: 2),
      'heart': ParticleTarget.icon(Icons.favorite, size: 260, stride: 2),
      'bolt': ParticleTarget.icon(Icons.bolt, size: 260, stride: 2),
      'snow': ParticleTarget.icon(CupertinoIcons.snow, size: 260, stride: 2),
    });
    if (!mounted) return;
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted && _controller.keys.isNotEmpty) {
      setState(() => _controller.changeTarget('flutter'));
    }
  }

  void _select(String key) {
    if (_controller.keys.isEmpty) return;
    setState(() => _controller.changeTarget(key));
  }

  void _next() {
    if (_controller.keys.isEmpty) return;
    final cur = _controller.activeKey;
    final i = cur == null ? -1 : _entries.indexWhere((e) => e.key == cur);
    _select(_entries[(i + 1) % _entries.length].key);
  }

  void _onEscapeChanged(EscapePosition value) {
    setState(() => _escape = value);
    _controller.config =
        _controller.config.copyWith(escapePosition: value);
    if (_controller.keys.isNotEmpty) _controller.escape();
  }

  String _fmt(int n) => n.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]},',
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCanvas,
      body: Stack(
        children: [
          Positioned.fill(
            child: ParticleField(
              controller: _controller,
              handleDrag: false,
              backgroundColor: _kCanvas,
            ),
          ),

          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.35),
                    radius: 1.1,
                    colors: <Color>[Color(0x00000000), Color(0xAA000000)],
                    stops: <double>[0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 14),
                child: _buildHeader(),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildControlDeck(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x44FFFFFF)),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'animated_particles',
          style: TextStyle(
            fontSize: 13,
            fontFamilyFallback: _kMonoFallback,
            color: Color(0xFFEAECEF),
            letterSpacing: 0.2,
          ),
        ),
        const Spacer(),
        _buildCountChip(),
      ],
    );
  }

  Widget _buildCountChip() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kGlassFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kGlassHairline),
          ),
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final count = _controller.particleCount;
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                transitionBuilder: (child, animation) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.4),
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Text(
                  '${_fmt(count)} particles',
                  key: ValueKey<int>(count),
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamilyFallback: _kMonoFallback,
                    color: Color(0xCCFFFFFF),
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildControlDeck() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: _kGlassFill,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _kGlassHairline),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: _kShadow,
                blurRadius: 30,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.62,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGalleryCluster(),
                    const SizedBox(height: 18),
                    _buildEscapeCluster(),
                    const SizedBox(height: 18),
                    _buildNextButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w600,
        color: _kTextSecondary,
      ),
    );
  }

  Widget _buildGalleryCluster() {
    final hasKeys = _controller.keys.isNotEmpty;
    final active = _controller.activeKey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('GALLERY'),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _entries.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final entry = _entries[i];
              return _GalleryChip(
                entry: entry,
                selected: entry.key == active,
                onTap: hasKeys ? () => _select(entry.key) : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEscapeCluster() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('ESCAPE'),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<EscapePosition>(
            showSelectedIcon: false,
            segments: const <ButtonSegment<EscapePosition>>[
              ButtonSegment(
                value: EscapePosition.left,
                icon: Icon(Icons.west),
                tooltip: 'Left',
              ),
              ButtonSegment(
                value: EscapePosition.top,
                icon: Icon(Icons.north),
                tooltip: 'Top',
              ),
              ButtonSegment(
                value: EscapePosition.bottom,
                icon: Icon(Icons.south),
                tooltip: 'Bottom',
              ),
              ButtonSegment(
                value: EscapePosition.right,
                icon: Icon(Icons.east),
                tooltip: 'Right',
              ),
            ],
            selected: {_escape},
            onSelectionChanged: (s) => _onEscapeChanged(s.first),
          ),
        ),
      ],
    );
  }

  Widget _buildNextButton() {
    final hasKeys = _controller.keys.isNotEmpty;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: hasKeys ? _next : null,
        icon: const Icon(Icons.skip_next_rounded, size: 20),
        label: const Text('Next shape'),
        style: FilledButton.styleFrom(
          backgroundColor: _kAccent.withValues(alpha: 0.22),
          foregroundColor: _kAccent,
          disabledBackgroundColor: _kGlassFill,
          disabledForegroundColor: _kTextTertiary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

}

class _GalleryEntry {
  const _GalleryEntry({required this.key, this.label, this.icon})
      : assert(label != null || icon != null);

  final String key;
  final String? label;
  final IconData? icon;
}

class _GalleryChip extends StatelessWidget {
  const _GalleryChip({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final _GalleryEntry entry;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content = entry.icon != null
        ? Icon(
            entry.icon,
            size: 22,
            color: selected ? Colors.white : const Color(0xDDFFFFFF),
          )
        : Text(
            entry.label!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xCCFFFFFF),
            ),
          );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0x1FFFFFFF) : const Color(0x10FFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _kAccent : const Color(0x00000000),
            width: 1.5,
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: _kAccent.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1.0,
          child: content,
        ),
      ),
    );
  }
}
