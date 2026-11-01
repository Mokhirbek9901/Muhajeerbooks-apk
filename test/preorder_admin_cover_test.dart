import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/admin_ui.dart';

void main() {
  const catalog = <String,String>{
    'book-1': 'https://example.com/catalog-cover.jpg',
  };

  test('native preorder uses linked catalog book image', () {
    expect(preorderCoverUrl({'_origin': 'native', 'book_id':'book-1'}, catalog),
      'https://example.com/catalog-cover.jpg');
  });

  test('private uploaded image uses signed URL, not storage path', () {
    const signed='https://example.com/storage/v1/object/sign/web-preorder-assets/cover.jpg?token=abc';
    expect(preorderCoverUrl({
      '_origin':'web',
      'book_image_path':'secret-private-storage/cover.jpg',
      'book_image_url':signed,
    }, catalog), signed);
    expect(preorderCoverUrl({
      '_origin':'web',
      'book_image_path':'secret-private-storage/cover.jpg',
    }, catalog), isEmpty);
  });

  test('multi preorder resolves individual signed cover', () {
    const signed='https://example.com/storage/v1/object/sign/multi.jpg?token=abc';
    expect(preorderCoverUrl({
      '_origin':'web',
      'request_items': [
        {'book_image_path':'private/multi.jpg','book_image_url':signed}
      ]
    }, catalog), signed);
  });

  test('falls back to linked item catalog image when no uploaded cover', () {
    expect(preorderCoverUrl({
      '_origin':'web',
      'request_items':[{'book_id':'book-1'}],
    },catalog),'https://example.com/catalog-cover.jpg');
  });

  test('invalid or relative image URL is never used in Image.network', () {
    expect(preorderCoverUrl({
      'book_image_url':'/private/not-signed.jpg',
    },catalog),isEmpty);
  });
}
