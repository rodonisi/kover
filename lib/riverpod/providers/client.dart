import 'package:chopper/chopper.dart';
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'client.g.dart';

ChopperClient getChopperClient(Uri uri, String apiKey) {
  return ChopperClient(
    baseUrl: uri,
    interceptors: [
      HeadersInterceptor({
        'x-api-key': apiKey,
        "Content-Type": "application/json",
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

  final client = ChopperClient(
    baseUrl: uri,
    interceptors: [
      HeadersInterceptor({
        'x-api-key': key!,
        "Content-Type": "application/json",
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
