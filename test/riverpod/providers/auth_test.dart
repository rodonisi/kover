import 'dart:convert';

import 'package:chopper/chopper.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/models/user_model.dart';
import 'package:kover/riverpod/providers/auth.dart';
import 'package:kover/riverpod/providers/client.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:kover/riverpod/repository/storage_repository.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<Openapi>()])
import 'auth_test.mocks.dart';

void main() {
  setUpAll(() {
    final dummyUser = const UserDto();
    provideDummy<Response<UserDto>>(
      Response(http.Response('', 200), dummyUser),
    );
  });

  group('CurrentUser', () {
    test(
      'when no credentials are set, should throw NoCredentialsException',
      () {
        fakeAsync((async) {
          final container = ProviderContainer.test(
            overrides: [
              storageProvider.overrideWith(
                (ref) => Storage<String, String>.inMemory(),
              ),
              credentialsProvider.overrideWithBuild(
                (_, _) => const CredentialsState(),
              ),
            ],
          );

          expectLater(
            container.read(currentUserProvider.future),
            throwsA(isA<NoCredentialsException>()),
          );
          async.flushMicrotasks();
        });
      },
    );

    test('when api key not set, should throw NoCredentialsException', () {
      fakeAsync((async) {
        final container = ProviderContainer.test(
          overrides: [
            storageProvider.overrideWith(
              (ref) => Storage<String, String>.inMemory(),
            ),
            credentialsProvider.overrideWithBuild(
              (_, _) => const CredentialsState(url: 'https://example.com'),
            ),
          ],
        );

        expectLater(
          container.read(currentUserProvider.future),
          throwsA(isA<NoCredentialsException>()),
        );
        async.flushMicrotasks();
      });
    });

    test('when credentials set, should fetch user successfully', () {
      fakeAsync((async) {
        final mockOpenapi = MockOpenapi();
        final container = ProviderContainer.test(
          overrides: [
            storageProvider.overrideWith(
              (ref) => Storage<String, String>.inMemory(),
            ),
            credentialsProvider.overrideWithBuild(
              (_, _) => const CredentialsState(
                url: 'https://example.com',
                apiKey: 'valid_api_key',
              ),
            ),
            restClientProvider.overrideWith((_) => mockOpenapi),
          ],
        );

        final userDto = const UserDto(
          id: 0,
          username: 'test_user',
        );

        when(
          mockOpenapi.apiPluginAuthenticatePost(
            apiKey: anyNamed('apiKey'),
            pluginName: anyNamed('pluginName'),
          ),
        ).thenAnswer(
          (_) async => Response(http.Response('', 200), userDto),
        );

        final user = container.read(currentUserProvider.future);
        expect(
          user,
          completion(equals(UserModel.fromUserDto(userDto))),
        );
        async.flushMicrotasks();
      });
    });

    test(
      'when stored user is available and fetching fails, should return stored user',
      () {
        fakeAsync((async) {
          final mockOpenapi = MockOpenapi();
          final storedUser = const UserModel(id: 0, username: 'stored_user');
          final container = ProviderContainer.test(
            overrides: [
              storageProvider.overrideWith(
                (ref) {
                  final storage = Storage<String, String>.inMemory();
                  storage.write(
                    CurrentUser().key,
                    jsonEncode(storedUser.toJson()),
                    const StorageOptions(
                      cacheTime: StorageCacheTime.unsafe_forever,
                    ),
                  );
                  return storage;
                },
              ),
              credentialsProvider.overrideWithBuild(
                (_, _) => const CredentialsState(
                  url: 'https://example.com',
                  apiKey: 'valid_api_key',
                ),
              ),
              restClientProvider.overrideWith((_) => mockOpenapi),
            ],
          );
          when(
            mockOpenapi.apiPluginAuthenticatePost(
              apiKey: anyNamed('apiKey'),
              pluginName: anyNamed('pluginName'),
            ),
          ).thenAnswer(
            (_) async => Response(http.Response('', 500), null),
          );

          final user = container.read(currentUserProvider.future);
          expect(user, completion(equals(storedUser)));
          async.flushMicrotasks();
        });
      },
    );

    test(
      'when stored user is available, should return stored user and refresh in background',
      () {
        fakeAsync((async) {
          final mockOpenapi = MockOpenapi();
          final storedUser = const UserModel(id: 0, username: 'stored_user');
          final container = ProviderContainer.test(
            overrides: [
              storageProvider.overrideWith(
                (ref) {
                  final storage = Storage<String, String>.inMemory();
                  storage.write(
                    CurrentUser().key,
                    jsonEncode(storedUser.toJson()),
                    const StorageOptions(
                      cacheTime: StorageCacheTime.unsafe_forever,
                    ),
                  );
                  return storage;
                },
              ),
              credentialsProvider.overrideWithBuild(
                (_, _) => const CredentialsState(
                  url: 'https://example.com',
                  apiKey: 'valid_api_key',
                ),
              ),
              restClientProvider.overrideWith((_) => mockOpenapi),
            ],
          );

          final userDto = const UserDto(
            id: 1,
            username: 'fetched_user',
          );

          when(
            mockOpenapi.apiPluginAuthenticatePost(
              apiKey: anyNamed('apiKey'),
              pluginName: anyNamed('pluginName'),
            ),
          ).thenAnswer(
            (_) async => Response(http.Response('', 200), userDto),
          );

          final updates = <UserModel>[];
          container.listen(currentUserProvider, (_, next) {
            next.whenData((user) => updates.add(user));
          });

          async.flushMicrotasks();
          expect(updates, [storedUser, UserModel.fromUserDto(userDto)]);
        });
      },
    );

    test(
      'when stored user is available and credentials become invalid, should clear user and return error state',
      () {
        fakeAsync((async) {
          final mockOpenapi = MockOpenapi();
          final storedUser = const UserModel(id: 0, username: 'stored_user');
          var credentials = const CredentialsState(
            url: 'https://example.com',
            apiKey: 'valid_api_key',
          );
          final container = ProviderContainer.test(
            overrides: [
              storageProvider.overrideWith(
                (ref) {
                  final storage = Storage<String, String>.inMemory();
                  storage.write(
                    CurrentUser().key,
                    jsonEncode(storedUser.toJson()),
                    const StorageOptions(
                      cacheTime: StorageCacheTime.unsafe_forever,
                    ),
                  );
                  return storage;
                },
              ),
              credentialsProvider.overrideWithBuild(
                (_, _) => credentials,
              ),
              restClientProvider.overrideWith((_) => mockOpenapi),
            ],
          );

          when(
            mockOpenapi.apiPluginAuthenticatePost(
              apiKey: anyNamed('apiKey'),
              pluginName: anyNamed('pluginName'),
            ),
          ).thenAnswer(
            (_) async => Response(http.Response('', 401), null),
          );

          final sub = container.listen(currentUserProvider, (_, _) {});

          async.flushMicrotasks();
          expect(sub.read().value, equals(storedUser));

          credentials = const CredentialsState();
          container.invalidate(credentialsProvider);

          async.flushMicrotasks();

          expectLater(
            container.read(currentUserProvider.future),
            throwsA(isA<NoCredentialsException>()),
          );

          async.flushMicrotasks();
        });
      },
    );

    test(
      'when stored user is available and refreshing fails, should keep stored user',
      () {
        fakeAsync((async) {
          final mockOpenapi = MockOpenapi();
          final storedUser = const UserModel(id: 0, username: 'stored_user');
          final container = ProviderContainer.test(
            overrides: [
              storageProvider.overrideWith(
                (ref) {
                  final storage = Storage<String, String>.inMemory();
                  storage.write(
                    CurrentUser().key,
                    jsonEncode(storedUser.toJson()),
                    const StorageOptions(
                      cacheTime: StorageCacheTime.unsafe_forever,
                    ),
                  );
                  return storage;
                },
              ),
              credentialsProvider.overrideWithBuild(
                (_, _) => const CredentialsState(
                  url: 'https://example.com',
                  apiKey: 'valid_api_key',
                ),
              ),
              restClientProvider.overrideWith((_) => mockOpenapi),
            ],
          );

          when(
            mockOpenapi.apiPluginAuthenticatePost(
              apiKey: anyNamed('apiKey'),
              pluginName: anyNamed('pluginName'),
            ),
          ).thenAnswer(
            (_) async => Response(http.Response('', 500), null),
          );

          final updates = <UserModel>[];
          final sub = container.listen(currentUserProvider, (_, next) {
            next.whenData((user) => updates.add(user));
          });

          async.flushMicrotasks();
          expect(sub.read().value, equals(storedUser));
          async.flushMicrotasks();
          expect(container.read(currentUserProvider).value, equals(storedUser));
        });
      },
    );
  });
}
