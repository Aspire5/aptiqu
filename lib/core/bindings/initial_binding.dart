import 'package:get/get.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../network/dio_client.dart';
import '../progression/controllers/xp_controller.dart';

/// Global Application Bindings
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // 1. Core Network Client
    Get.put<DioClient>(DioClient(), permanent: true);

    // 2. Global Authentication Controller
    Get.put<AuthController>(AuthController(), permanent: true);

    // 3. Global XP & Progression Controller
    Get.put<XpController>(XpController(), permanent: true);
  }
}
