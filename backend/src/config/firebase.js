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
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId,
        privateKey: privateKey.replace(/\\n/g, '\n'),
        clientEmail,
      }),
    });
  } else {
    // Initialize without credentials (push notifications disabled)
    admin.initializeApp();
    console.warn('⚠️  Firebase initialized without credentials — push notifications disabled');
  }
}

module.exports = admin;
