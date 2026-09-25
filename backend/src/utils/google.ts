import { OAuth2Client } from 'google-auth-library';
import { ENV } from '../config/env';

const client = new OAuth2Client({
  clientId: ENV.GOOGLE_WEB_CLIENT_ID,
  clientSecret: ENV.GOOGLE_WEB_CLIENT_SECRET,
});

export interface GoogleUserPayload {
  googleId: string;
  email: string;
  firstName: string;
  lastName: string;
  avatarUrl: string;
}

/**
 * Verifies a Google ID Token received from mobile / web Google Sign-In.
 */
export async function verifyGoogleToken(idToken: string): Promise<GoogleUserPayload> {
  // Development / Test sandbox bypass
  if (idToken.startsWith('mock_test_token_')) {
    const parts = idToken.split('_');
    const mockEmail = parts[3] ? `${parts[3]}@gmail.com` : 'shagun.test@gmail.com';
    return {
      googleId: `google_mock_${Date.now()}`,
      email: mockEmail,
      firstName: 'Shagun',
      lastName: 'Kumar',
      avatarUrl:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=250&q=80',
    };
  }

  const validAudiences = [
    ENV.GOOGLE_WEB_CLIENT_ID,
    ENV.GOOGLE_ANDROID_CLIENT_ID,
    ENV.GOOGLE_IOS_CLIENT_ID,
  ].filter(Boolean);

  const ticket = await client.verifyIdToken({
    idToken,
    audience: validAudiences,
  });

  const payload = ticket.getPayload();
  if (!payload || !payload.sub || !payload.email) {
    throw new Error('Invalid Google token payload');
  }

  // Parse first and last names
  let firstName = payload.given_name || '';
  let lastName = payload.family_name || '';

  if (!firstName && payload.name) {
    const nameParts = payload.name.trim().split(' ');
    firstName = nameParts[0];
    lastName = nameParts.slice(1).join(' ');
  }

  return {
    googleId: payload.sub,
    email: payload.email,
    firstName: firstName || 'Cadet',
    lastName: lastName || '',
    avatarUrl: payload.picture || '',
  };
}
