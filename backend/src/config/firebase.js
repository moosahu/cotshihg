const admin = require('firebase-admin');
require('dotenv').config();

if (!admin.apps.length) {
  try {
    // Approach 1: full service account JSON in one env var (most reliable on Render)
    const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    if (serviceAccountJson) {
      const serviceAccount = JSON.parse(serviceAccountJson);
      admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
      console.log('✅ Firebase Admin initialized via FIREBASE_SERVICE_ACCOUNT_JSON');
    } else {
      // Approach 2: individual fields (legacy)
      const projectId   = process.env.FIREBASE_PROJECT_ID;
      const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
      const rawKey      = process.env.FIREBASE_PRIVATE_KEY;

      const hasCredentials = projectId && clientEmail && rawKey &&
        !['placeholder', ''].includes(projectId);

      if (hasCredentials) {
        // Normalize newlines — handles all Render storage formats
        const privateKey = rawKey
          .replace(/^["']|["']$/g, '')  // strip surrounding quotes
          .replace(/\\n/g, '\n');        // literal \n → real newline

        admin.initializeApp({
          credential: admin.credential.cert({ projectId, clientEmail, privateKey }),
        });
        console.log('✅ Firebase Admin initialized via individual env vars');
      } else {
        admin.initializeApp();
        console.warn('⚠️  Firebase initialized without credentials — push notifications disabled');
      }
    }
  } catch (err) {
    console.error('❌ Firebase init error:', err.message);
    admin.initializeApp();
  }
}

module.exports = admin;
