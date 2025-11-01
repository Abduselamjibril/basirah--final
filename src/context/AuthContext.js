import React, { createContext, useState, useContext, useCallback } from 'react';
import apiClient from '../api/axiosConfig'; // Your configured axios instance
import { jwtDecode } from 'jwt-decode';

// Create the context
const AuthContext = createContext(null);

// Create the provider component
export const AuthProvider = ({ children }) => {
    const [user, setUser] = useState(null);
    const [isAuthenticated, setIsAuthenticated] = useState(() => !!localStorage.getItem('authToken'));
    const [loading, setLoading] = useState(true);

    const logout = useCallback(() => {
        localStorage.removeItem('authToken');
        setUser(null);
        setIsAuthenticated(false);
    }, []);

    const fetchUser = useCallback(async () => {
        const token = localStorage.getItem('authToken');
        if (!token) {
            setLoading(false);
            setIsAuthenticated(false);
            setUser(null);
            return;
        }

        try {
            const decoded = jwtDecode(token);
            if (decoded.exp * 1000 < Date.now()) {
                logout();
                return;
            }
            
            apiClient.defaults.headers.common['Authorization'] = `Bearer ${token}`;
            const response = await apiClient.get('/admin/profile');
            setUser(response.data);
            setIsAuthenticated(true);
        } catch (error) {
            console.error("Failed to fetch user or token invalid", error);
            logout();
        } finally {
            setLoading(false);
        }
    }, [logout]);

    const authValue = {
        user,
        isAuthenticated,
        loading,
        fetchUser,
        logout,
        setIsAuthenticated,
        setUser
    };

    return (
        <AuthContext.Provider value={authValue}>
            {children}
        </AuthContext.Provider>
    );
};

// Custom hook to use the auth context easily
export const useAuth = () => {
    return useContext(AuthContext);
};