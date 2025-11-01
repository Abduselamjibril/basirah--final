// src/api/axiosConfig.js

import axios from 'axios';

const API_URL = 'https://admin.basirahtv.com/api';

const apiClient = axios.create({
  baseURL: API_URL,
});

// Use an interceptor to add the auth token to every request
apiClient.interceptors.request.use(
  (config) => {
    // Retrieve the token from local storage
    const token = localStorage.getItem('authToken'); // Make sure you use the same key you used on login

    if (token) {
      config.headers['Authorization'] = `Bearer ${token}`;
    }
    
    config.headers['Accept'] = 'application/json';

    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Optional: Add a response interceptor for handling 401 errors globally
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response && error.response.status === 401) {
      // Handle unauthorized access, e.g., redirect to login
      console.error("Unauthorized! Redirecting to login.");
      localStorage.removeItem('authToken'); // Clear expired token
      // This assumes you are using React Router and have a history object or use a different navigation method.
      // window.location.href = '/login'; 
    }
    return Promise.reject(error);
  }
);

export default apiClient;