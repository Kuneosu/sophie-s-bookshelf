import 'package:flutter_test/flutter_test.dart';
import 'package:bookshelf/app.dart';

void main() {
  testWidgets('App renders', (tester) async {
    await tester.pumpWidget(const BookshelfApp());
    expect(find.text('내 서재'), findsOneWidget);
  });
}
