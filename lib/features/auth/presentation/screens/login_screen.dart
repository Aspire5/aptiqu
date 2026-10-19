import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import 'package:aptiqu/core/routing/app_routes.dart';
import 'package:aptiqu/core/theme/appearance_theme.dart';
import 'package:aptiqu/core/theme/aptiqu_tokens.dart';
import 'package:aptiqu/shared/widgets/buttons/aptiqu_button.dart';
import '../controllers/auth_controller.dart';

class _LoginSlideData {
  final String imageAsset;
  final String caption;

  const _LoginSlideData({
    required this.imageAsset,
    required this.caption,
  });
}

const _kSlides = [
  _LoginSlideData(
    imageAsset: 'assets/images/login/aptiqu_onboarding_learn.webp',
    caption: 'Master every concept with step-by-step visual lessons',
  ),
  _LoginSlideData(
    imageAsset: 'assets/images/login/aptiqu_onboarding_practice.webp',
    caption: 'Build speed and accuracy with bite-sized daily drills',
  ),
  _LoginSlideData(
    imageAsset: 'assets/images/login/aptiqu_onboarding_compete.webp',
    caption: 'Challenge peers head-to-head in live 1v1 duels',
  ),
];

class LoginScreen extends StatefulWidget {
  final bool? autoPlay;

  const LoginScreen({
    super.key,
    this.autoPlay,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const int _kInitialPage = 3000;
  late final PageController _pageController;
  Timer? _autoPlayTimer;
  // ignore: unused_field
  int _activeSlideIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _kInitialPage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startAutoPlayIfNeeded();
      }
    });
  }

  void _startAutoPlayIfNeeded() {
    _stopAutoPlay();
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    final enabled = widget.autoPlay ?? !isTest;
    if (!enabled) return;
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) return;

    _autoPlayTimer = Timer.periodic(const Duration(milliseconds: 4200), (_) {
      if (!_pageController.hasClients || !mounted) return;
      final nextPage = (_pageController.page?.round() ?? _kInitialPage) + 1;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _stopAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _stopAutoPlay();
    }
  }

  @override
  void dispose() {
    _stopAutoPlay();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildSlide(
    BuildContext context,
    _LoginSlideData slide,
    bool isCompact,
  ) {
    final imageWidget = Image.asset(
      slide.imageAsset,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => Icon(
        Icons.school_outlined,
        size: isCompact ? 48 : 64,
        color: context.colors.primary,
      ),
    );

    final textWidget = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Text(
        slide.caption,
        textAlign: TextAlign.center,
        style: (context.type.titleMedium ?? const TextStyle()).copyWith(
          fontFamily: 'Outfit',
          fontSize: isCompact ? 16 : 18,
          fontWeight: FontWeight.w700,
          height: 1.35,
          color: context.colors.onSurface,
        ),
      ),
    );

    if (isCompact) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final imgHeight = (constraints.maxHeight * 0.40).clamp(60.0, 130.0);
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: imgHeight, child: imageWidget),
                  const SizedBox(height: 5), // Reduced by 50% from 10px
                  textWidget,
                ],
              ),
            ),
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: imageWidget,
            ),
          ),
          const SizedBox(height: 5), // Reduced by 50% from 10px
          textWidget,
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildCarousel(
    BuildContext context,
    bool isCompact,
    double maxHeight,
  ) {
    final carousel = NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.direction != ScrollDirection.idle) {
          _stopAutoPlay();
        } else {
          _startAutoPlayIfNeeded();
        }
        return false;
      },
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (page) {
          setState(() {
            _activeSlideIndex = page % _kSlides.length;
          });
        },
        itemBuilder: (context, index) {
          final slide = _kSlides[index % _kSlides.length];
          return _buildSlide(context, slide, isCompact);
        },
      ),
    );

    if (isCompact) {
      final fixedHeight = max(240.0, maxHeight * 0.45);
      return SizedBox(
        height: fixedHeight,
        child: carousel,
      );
    }

    return Expanded(child: carousel);
  }

  Widget _buildBottomLoginCard(BuildContext context, AuthController auth) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: dark ? context.colors.surfaceContainer : context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(
          top: BorderSide(
            color: context.colors.outlineVariant
                .withValues(alpha: dark ? 0.7 : 0.5),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        14,
        22,
        max(20.0, MediaQuery.paddingOf(context).bottom + 10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/main_logo.webp',
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
                errorBuilder: (_, __, ___) => Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.school_outlined,
                    size: 32,
                    color: context.colors.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            label: 'AptiQu, Sign in to continue',
            child: Text(
              'AptiQu',
              textAlign: TextAlign.center,
              style:
                  (context.type.headlineMedium ?? const TextStyle()).copyWith(
                fontFamily: 'Outfit',
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: context.colors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Build your aptitude and reasoning skills,\none step at a time.',
            textAlign: TextAlign.center,
            style: (context.type.bodySmall ?? const TextStyle()).copyWith(
              color: context.colors.onSurfaceVariant,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          Obx(
            () => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (auth.authErrorMessage.value.isNotEmpty) ...[
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.colors.errorContainer,
                        borderRadius:
                            BorderRadius.circular(AptiquRadius.control),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: context.colors.onErrorContainer,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              auth.authErrorMessage.value,
                              style: (context.type.bodyMedium ??
                                      const TextStyle())
                                  .copyWith(
                                color: context.colors.onErrorContainer,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                AptiquButton.google(
                  label: 'Continue with Google',
                  isLoading: auth.isLoading.value,
                  width: double.infinity,
                  onPressed: () async {
                    final success = await auth.signInWithGoogle();
                    if (success && context.mounted) {
                      context.go(
                        auth.isRegistrationComplete
                            ? AppRoutes.home
                            : AppRoutes.signup,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'By continuing, you agree to our Terms of\nService and Privacy Policy.',
            textAlign: TextAlign.center,
            style: (context.type.bodySmall ?? const TextStyle()).copyWith(
              color: context.colors.onSurfaceVariant,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              TextButton(
                onPressed: null,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  disabledForegroundColor: context.colors.primary,
                  foregroundColor: context.colors.primary,
                  textStyle:
                      (context.type.labelMedium ?? const TextStyle()).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                child: const Text('Terms of Service'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  '•',
                  style: TextStyle(
                    color: context.colors.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: null,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  disabledForegroundColor: context.colors.primary,
                  foregroundColor: context.colors.primary,
                  textStyle:
                      (context.type.labelMedium ?? const TextStyle()).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                child: const Text('Privacy Policy'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AppearanceTheme(
        builder: (context) {
          final auth = Get.find<AuthController>();
          return Scaffold(
            backgroundColor: context.colors.surfaceDim,
            body: SafeArea(
              top: true,
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final media = MediaQuery.of(context);
                  final textScale = media.textScaler.scale(1.0);
                  final isCompact =
                      constraints.maxHeight < 600 || textScale >= 1.5;

                  final content = isCompact
                      ? SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildCarousel(
                                  context,
                                  true,
                                  constraints.maxHeight,
                                ),
                                _buildBottomLoginCard(context, auth),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildCarousel(
                              context,
                              false,
                              constraints.maxHeight,
                            ),
                            _buildBottomLoginCard(context, auth),
                          ],
                        );

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: content,
                    ),
                  );
                },
              ),
            ),
          );
        },
      );
}
