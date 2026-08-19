import 'package:http/http.dart' as http;

import 'http_client_stub.dart'
    if (dart.library.io) 'http_client_io.dart'
    as platform;

/// Returns a native HTTP client that accepts untrusted certificates when the
/// user has explicitly enabled that setting. Web clients cannot override the
/// browser's certificate validation.
http.Client? createHttpClient({
  required bool ignoreCertificateValidation,
}) => platform.createHttpClient(
  ignoreCertificateValidation: ignoreCertificateValidation,
);
