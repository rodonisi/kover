import 'package:chopper/chopper.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:kover/utils/http_client/http_client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'client.g.dart';

ChopperClient getChopperClient(
  Uri uri,
  String apiKey, {
  Map<String, String> customHeaders = const {},
  bool ignoreCertificateValidation = false,
}) {
  return ChopperClient(
    baseUrl: uri,
    client: createHttpClient(
      ignoreCertificateValidation: ignoreCertificateValidation,
    ),
    interceptors: [
      HeadersInterceptor({
        'x-api-key': apiKey,
        "Content-Type": "application/json",
        ...customHeaders,
      }),
    ],
    converter: $JsonSerializableConverter(),
  );
}

@Riverpod(keepAlive: true)
ChopperClient authenticatedClient(Ref ref) {
  final settings = ref.watch(credentialsProvider).value;
  final key = ref.watch(apiKeyProvider);

  if (settings?.url == null || settings?.apiKey == null) {
    throw Exception('Credentials not set in settings');
  }

  final uri = Uri.tryParse(settings!.url!);
  if (uri == null) {
    throw Exception('Invalid URL in settings');
  }

  final httpClient = createHttpClient(
    ignoreCertificateValidation: settings.ignoreCertificateValidation,
  );
  if (httpClient != null) ref.onDispose(httpClient.close);

  final client = ChopperClient(
    baseUrl: uri,
    client: httpClient,
    interceptors: [
      HeadersInterceptor({
        'x-api-key': key!,
        "Content-Type": "application/json",
        ...settings.customHeaders,
      }),
    ],
    converter: $JsonSerializableConverter(),
  );

  return client;
}

@Riverpod(keepAlive: true)
Openapi restClient(Ref ref) {
  final client = ref.watch(authenticatedClientProvider);
  return Openapi.create(client: client);
}
