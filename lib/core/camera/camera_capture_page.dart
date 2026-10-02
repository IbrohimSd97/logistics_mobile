import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../theme/app_palette.dart';

/// Ilova ichidagi kamera: faqat suratga olish (galereya yo'q) va kerakli
/// kamera (old yoki orqa) aniq tanlanadi.
///
/// Tizim kamerasi (`image_picker`) old kamerani faqat "tavsiya" qiladi — ko'p
/// Android qurilmalarda u e'tiborsiz qolib orqa kamera ochiladi. Selfi va
/// mashina rasmlari uchun shu sahifa ishlatiladi.
///
/// Natija: tasdiqlangan rasm (`XFile`) yoki foydalanuvchi bekor qilsa `null`.
Future<XFile?> captureWithCamera(
  BuildContext context, {
  required CameraLensDirection lens,
  required String hint,
}) {
  return Navigator.of(context).push<XFile>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CameraCapturePage(lens: lens, hint: hint),
    ),
  );
}

class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({super.key, required this.lens, required this.hint});

  final CameraLensDirection lens;

  /// Kadr ustida ko'rsatiladigan yo'l-yo'riq ("Mashinaning old tomoni").
  final String hint;

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  XFile? _shot;
  String? _error;
  bool _busy = false;

  /// Kamera ochilmoqda — ruxsat oynasi ilovani "nofaol" holatga o'tkazadi va
  /// qaytganda ikkinchi `_init` boshlanib, ikkita kontroller ochilmasin.
  bool _initializing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  // Ilova fonga o'tganda kamerani bo'shatamiz, qaytganda qayta ochamiz —
  // aks holda Android'da boshqa ilova kamerani ololmaydi yoki preview qotadi.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (_initializing) return;
    if (state == AppLifecycleState.inactive) {
      _controller = null;
      c?.dispose();
    } else if (state == AppLifecycleState.resumed &&
        c == null &&
        _shot == null) {
      _init();
    }
  }

  Future<void> _init() async {
    if (_initializing) return;
    _initializing = true;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _fail(I18n.t('camera.no_camera'));
        return;
      }
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == widget.lens,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        cam,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _error = null;
      });
    } on CameraException catch (e) {
      _fail(
        e.code.contains('Access') || e.code.contains('Permission')
            ? I18n.t('camera.permission_denied')
            : I18n.t('camera.open_failed'),
      );
    } catch (_) {
      _fail(I18n.t('camera.open_failed'));
    } finally {
      _initializing = false;
    }
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() => _error = msg);
  }

  Future<void> _take() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final f = await c.takePicture();
      // Tasdiqlash paytida preview'ni to'xtatamiz — u kadrlarni chizishda
      // davom etib, rasm dekodlanishini va bosishlarni sekinlashtiradi.
      try {
        await c.pausePreview();
      } catch (_) {}
      if (!mounted) return;
      setState(() => _shot = f);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t('camera.capture_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _body()),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                tooltip: I18n.t('common.cancel'),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            if (_error == null)
              Positioned(
                top: 8,
                left: 56,
                right: 56,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.hint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            Positioned(left: 0, right: 0, bottom: 24, child: _controls()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white70,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, height: 1.4),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  setState(() => _error = null);
                  _init();
                },
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                child: Text(I18n.t('common.retry')),
              ),
            ],
          ),
        ),
      );
    }
    final shot = _shot;
    if (shot != null) {
      // Ekran kengligiga mos o'lchamda dekodlaymiz (to'liq 1080p kadrni
      // dekodlash sekin); tayyor bo'lguncha yuklanish belgisi.
      final decodeW =
          (MediaQuery.sizeOf(context).width *
                  MediaQuery.devicePixelRatioOf(context))
              .round();
      Widget loading(BuildContext _, Widget child, int? frame, bool sync) =>
          frame == null && !sync
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : child;
      final img = kIsWeb
          ? Image.network(shot.path, frameBuilder: loading)
          : Image.file(
              File(shot.path),
              cacheWidth: decodeW,
              frameBuilder: loading,
            );
      // Tasdiqlashda aynan serverga ketadigan rasm ko'rsatiladi (old kamera
      // preview'i ko'zgudek, lekin saqlangan surat — yo'q; guvohnoma matni
      // to'g'ri o'qilishi muhim).
      return Center(child: img);
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: 1 / c.value.aspectRatio,
        child: CameraPreview(c),
      ),
    );
  }

  Widget _controls() {
    if (_error != null) return const SizedBox.shrink();
    if (_shot != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() => _shot = null);
                  // Fonga o'tganda kamera bo'shatilgan bo'lishi mumkin.
                  final c = _controller;
                  if (c == null) {
                    _init();
                  } else {
                    c.resumePreview().catchError((_) {});
                  }
                },
                icon: const Icon(Icons.replay_rounded),
                label: Text(I18n.t('camera.retake')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(_shot),
                icon: const Icon(Icons.check_rounded),
                label: Text(I18n.t('camera.use_photo')),
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.orange,
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Semantics(
        button: true,
        label: I18n.t('camera.take_photo'),
        child: GestureDetector(
          onTap: _take,
          child: Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _busy ? Colors.white54 : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
