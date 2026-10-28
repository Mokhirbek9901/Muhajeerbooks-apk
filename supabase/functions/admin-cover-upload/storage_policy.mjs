export const MAX_PHOTO_BYTES = 240 * 1024;
export const MAX_THUMB_BYTES = 40 * 1024;

export function optimizedUploadError(full, thumb) {
  if (!full?.length || full.length > MAX_PHOTO_BYTES)
    return "Siqilgan rasm 240 KB dan kichik bo‘lishi kerak.";
  if (!thumb?.length || thumb.length > MAX_THUMB_BYTES)
    return "Kichik rasm 40 KB dan kichik bo‘lishi kerak.";
  if ([full, thumb].some(bytes => bytes[0] !== 255 || bytes[1] !== 216 || bytes[2] !== 255))
    return "Siqilgan JPG rasm kerak.";
  return null;
}

export async function contentStamp(bytes, hasThumbnail) {
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
  const hash = Array.from(digest, x => x.toString(16).padStart(2, "0")).join("");
  return `mb-${hasThumbnail ? "opt-" : ""}${hash}`;
}

export function isDuplicateStorageError(error) {
  if (!error || typeof error !== "object") return false;
  const status = String(error.statusCode ?? error.status ?? "");
  if (status === "409") return true;
  return status === "400" && /already exists|duplicate/i.test(String(error.message ?? error.error ?? ""));
}

