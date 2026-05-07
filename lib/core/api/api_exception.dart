class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() {
    return message;
  }

  static ApiException fromResponse(dynamic response, int statusCode) {
    if (response is Map && response.containsKey('message')) {
      return ApiException(response['message'], statusCode: statusCode);
    }
    return ApiException('Unexpected server error', statusCode: statusCode);
  }
}
