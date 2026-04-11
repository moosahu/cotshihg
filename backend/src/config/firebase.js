const admin = require('firebase-admin');
require('dotenv').config();

const projectId = process.env.FIREBASE_PROJECT_ID;
const privateKey = process.env.FIREBASE_PRIVATE_KEY;
const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;

// Only initialize Firebase if real credentials are provided
const hasRealCredentials =
  projectId &&
  projectId !== 'placeholder' &&
  privateKey &&
  privateKey !== 'placeholder' &&
  clientEmail &&
  clientEmail !== 'placeholder';

if (!admin.apps.length) {
  if (hasRealCredentials) {
    // Normalize private key — handles all Render/env var line-ending formats:
    // 1. Literal \n strings  →  actual newlines
    // 2. Already has real newlines  →  keep as-is
    // 3. Quoted with surrounding quotes  →  strip them
    let formattedKey = privateKey
      .replace(/^["']|["']$/g, '')   // strip surrounding quotes if any
      .replace(/\\n/g, '\n');         // literal \n → real newline

    // If key still has no newlines after replacement, it may use \n already — try as-is
    if (!formattedKey.includes('\n')) {
      formattedKey = privateKey;
    }

    console.log(`🔑 Firebase key starts with: ${formattedKey.slice(0, 40).replace(/\n/g, '\\n')}`);

    admin.initializeApp({
      credential: admin.credential.cert({
        projectId,
        privateKey: formattedKey,
        clientEmail,
      }),
    });
    console.log('✅ Firebase Admin initialized with credentials');
  } else {
    // Initialize without credentials (push notifications disabled)
    admin.initializeApp();
    console.warn('⚠️  Firebase initialized without credentials — push notifications disabled');
  }
}

module.exports = admin;
