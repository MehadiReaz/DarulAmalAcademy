import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/support_contact.dart';

class SupportRepository {
  final ApiClient _client;

  SupportRepository(this._client);

  /// GET /api/student/support
  /// Returns the Admin Support and Help Center WhatsApp contacts.
  Future<List<SupportContact>> contacts() async {
    final data = await _client.get(ApiEndpoints.studentSupportContacts);
    return SupportContact.listFrom(data);
  }
}
