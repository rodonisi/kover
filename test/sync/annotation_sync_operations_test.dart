import 'package:chopper/chopper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kover/api/openapi.swagger.dart';
import 'package:kover/sync/annotation_sync_operations.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<Openapi>()])
import 'annotation_sync_operations_test.mocks.dart';

void main() {
  setUpAll(() {
    provideDummy<Response<List<AnnotationDto>>>(
      Response(http.Response('', 200), const <AnnotationDto>[]),
    );
  });

  test('requests every annotation page in one call', () async {
    final client = MockOpenapi();
    when(
      client.apiAnnotationAllFilteredPost(
        pageSize: 0,
        body: anyNamed('body'),
      ),
    ).thenAnswer(
      (_) async => Response(http.Response('', 200), const <AnnotationDto>[]),
    );

    await AnnotationSyncOperations(client).getAllAnnotations();

    verify(
      client.apiAnnotationAllFilteredPost(
        pageSize: 0,
        body: anyNamed('body'),
      ),
    ).called(1);
  });
}
