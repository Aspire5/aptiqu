import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/onboarding/presentation/screens/signup_screen.dart';
import '../../features/lesson/views/lesson_feed_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import 'app_routes.dart';

/// Centralized GoRouter with Auth & Onboarding Guards
class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: AppRoutes.home,
    redirect: (BuildContext context, GoRouterState state) {
      final authController = Get.find<AuthController>();
      final isLoggedIn = authController.isLoggedIn;
      final isRegComplete = authController.isRegistrationComplete;

      final isGoingToLogin = state.matchedLocation == AppRoutes.login;
      final isGoingToSignup = state.matchedLocation == AppRoutes.signup;

      // 1. Not logged in -> must go to Login
      if (!isLoggedIn) {
        return isGoingToLogin ? null : AppRoutes.login;
      }

      // 2. Logged in, but registration not complete -> must go to Sign-Up
      if (!isRegComplete) {
        return isGoingToSignup ? null : AppRoutes.signup;
      }

      // 3. Logged in and registration complete -> prevent visiting Login or SignUp
      if (isGoingToLogin || isGoingToSignup) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        name: 'signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        name: 'profile',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ProfileScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(-1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;
            final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.lesson,
        name: 'lesson',
        builder: (context, state) => LessonFeedScreen(
          slug: state.pathParameters['slug'],
          roadmapStepId: state.uri.queryParameters['stepId'],
        ),
      ),
      GoRoute(
        path: AppRoutes.lessonStep,
        name: 'lessonStep',
        builder: (context, state) => LessonFeedScreen(
          roadmapStepId: state.pathParameters['stepId'],
        ),
      ),
    ],
  );
}
