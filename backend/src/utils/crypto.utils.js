const crypto = require('crypto');

// MASTER_ENC_KEY must be a 64-char hex string (32 bytes) set in environment.
// Generate with: node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
const MASTER_KEY = process.env.MASTER_ENC_KEY
  ? Buffer.from(process.env.MASTER_ENC_KEY, 'hex')
  : null;

const ALGO = 'aes-256-gcm';
const IV_LEN = 12;
const TAG_LEN = 16;

/**
 * Encrypt plaintext. Returns base64 string: iv(12) + tag(16) + ciphertext.
 * Returns null if input is null/undefined.
 */
function encrypt(text) {
  if (text == null) return null;
  if (!MASTER_KEY) {
    console.warn('⚠️  MASTER_ENC_KEY not set — storing message unencrypted');
    return text;
  }
  const iv = crypto.randomBytes(IV_LEN);
  const cipher = crypto.createCipheriv(ALGO, MASTER_KEY, iv);
  const encrypted = Buffer.concat([cipher.update(String(text), 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([iv, tag, encrypted]).toString('base64');
}

/**
 * Decrypt base64 ciphertext produced by encrypt().
 * Returns original plaintext. Falls back to returning data as-is for
 * legacy unencrypted messages (graceful migration).
 */
function decrypt(data) {
  if (data == null) return null;
  if (!MASTER_KEY) return data;
  try {
    const buf = Buffer.from(data, 'base64');
    if (buf.length < IV_LEN + TAG_LEN + 1) return data; // too short → plaintext fallback
    const iv = buf.subarray(0, IV_LEN);
    const tag = buf.subarray(IV_LEN, IV_LEN + TAG_LEN);
    const encrypted = buf.subarray(IV_LEN + TAG_LEN);
    const decipher = crypto.createDecipheriv(ALGO, MASTER_KEY, iv);
    decipher.setAuthTag(tag);
    return decipher.update(encrypted) + decipher.final('utf8');
  } catch {
    // Not encrypted (legacy message) — return as-is
    return data;
  }
}

module.exports = { encrypt, decrypt };
