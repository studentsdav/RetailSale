import '../../core/auth/token_storage.dart';
import '../../models/security/app_user_model.dart';

Future<UserProfile?> load() async {
  final data = await TokenStorage.getUser();

  if (data == null) return null;

  return UserProfile.fromJson(data);
}
