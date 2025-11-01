// utils/auth.js

// Helper to get the token from localStorage
export const getToken = () => {
  return localStorage.getItem('token');
};

// Helper to check if the token is expired
export const isTokenExpired = (token) => {
  if (!token) return true;  // If there's no token, consider it expired

  try {
    // Decode JWT token payload (base64 decode the middle part of the JWT token)
    const tokenPayload = JSON.parse(atob(token.split('.')[1]));

    // Convert expiry time (in seconds) to milliseconds and compare with the current time
    const expiryTime = tokenPayload.exp * 1000;  // JWT expiration time is in seconds, convert to ms
    return Date.now() > expiryTime;  // If current time is greater than the expiry time, the token is expired
  } catch (error) {
    console.error('Error decoding token:', error);
    return true;  // If there's an issue decoding the token, consider it expired
  }
};