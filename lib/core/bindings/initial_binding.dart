import 'package:get/get.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../network/dio_client.dart';

/// Global Application Bindings
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // 1. Core Network Client
    Get.put<DioClient>(DioClient(), permanent: true);

    // 2. Global Authentication Controller
    Get.put<AuthController>(AuthController(), permanent: true);
  }
}
