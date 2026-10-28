import test from 'node:test';
import assert from 'node:assert/strict';
import {MAX_PHOTO_BYTES, MAX_THUMB_BYTES, optimizedUploadError, contentStamp, isDuplicateStorageError} from '../../supabase/functions/admin-cover-upload/storage_policy.mjs';
const jpeg = length => { const bytes = new Uint8Array(length); bytes.set([255,216,255]); return bytes; };
test('optimized upload enforces both compact variants and rejects raw originals', () => {
  assert.equal(optimizedUploadError(jpeg(MAX_PHOTO_BYTES), jpeg(MAX_THUMB_BYTES)), null);
  assert.match(optimizedUploadError(jpeg(MAX_PHOTO_BYTES+1), jpeg(30)), /240 KB/);
  assert.match(optimizedUploadError(jpeg(30), jpeg(MAX_THUMB_BYTES+1)), /40 KB/);
  assert.match(optimizedUploadError(jpeg(30), null), /40 KB/);
  assert.match(optimizedUploadError(new Uint8Array(20), jpeg(30)), /JPG/);
});
test('identical photo content always uses the same storage key', async () => {
  assert.equal(await contentStamp(jpeg(40), true), await contentStamp(jpeg(40), true));
  assert.notEqual(await contentStamp(jpeg(40), true), await contentStamp(jpeg(41), true));
  assert.match(await contentStamp(jpeg(40), true), /^mb-opt-[0-9a-f]{64}$/);
});
test('only duplicate storage errors are safe to reuse', () => {
  assert.equal(isDuplicateStorageError({statusCode:'409'}), true);
  assert.equal(isDuplicateStorageError({statusCode:'400',message:'The resource already exists'}), true);
  assert.equal(isDuplicateStorageError({statusCode:'403',message:'Access denied'}), false);
  assert.equal(isDuplicateStorageError({statusCode:'400',message:'Quota exceeded'}), false);
  assert.equal(isDuplicateStorageError(null), false);
});
