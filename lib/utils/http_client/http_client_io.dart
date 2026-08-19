import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

http.Client? createHttpClient({
  required bool ignoreCertificateValidation,
}) {
  if (!ignoreCertificateValidation) return null;

  return IOClient(
    HttpClient()
      ..badCertificateCallback = (
        X509Certificate certificate,
        String host,
        int port,
      ) => true,
  );
}
