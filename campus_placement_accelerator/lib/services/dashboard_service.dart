import '../models/dashboard_models.dart';
import '../main.dart';

class DashboardService {
  DashboardService(this.api);
  final PlacementApi api;
  Future<DashboardData> load() async => DashboardData.fromJson(await api.dashboard());
}
