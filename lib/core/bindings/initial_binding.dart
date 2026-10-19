import '../../features/social/social_controller.dart';
import '../theme/appearance_controller.dart';
import 'package:get/get.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../network/dio_client.dart';
import '../progression/controllers/xp_controller.dart';

/// Global Application Bindings
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<AppearanceController>(AppearanceController(), permanent: true);

    // 1. Core Network Client
    Get.put<DioClient>(DioClient(), permanent: true);

    // 2. Global Authentication Controller
    Get.put<AuthController>(AuthController(), permanent: true);

    Get.put<SocialController>(SocialController(), permanent: true);

    // 3. Global XP & Progression Controller
    Get.put<XpController>(XpController(), permanent: true);
  }
}
