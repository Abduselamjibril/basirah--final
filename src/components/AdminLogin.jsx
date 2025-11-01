// src/scenes/login/AdminLogin.jsx (or similar path)

import React, { useState } from 'react';
import { 
  Box, 
  Typography, 
  Button, 
  TextField, 
  useTheme,
  InputAdornment,
  IconButton,
  CircularProgress,
  Fade
} from "@mui/material";
import { tokens } from "../theme";
// --- FIX 1: Import your configured apiClient ---
import apiClient from '../api/axiosConfig'; 
import { Visibility, VisibilityOff } from "@mui/icons-material";

const AdminLogin = ({ onLoginSuccess }) => {
    const theme = useTheme();
    const colors = tokens(theme.palette.mode);
    
    const [email, setEmail] = useState(''); 
    const [password, setPassword] = useState(''); 
    const [error, setError] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [isLoading, setIsLoading] = useState(false);
    const [shake, setShake] = useState(false);

    const handleLogin = async (e) => {
        e.preventDefault();
        setError('');
        setIsLoading(true);
        
        try {
            // --- FIX 2: Use apiClient for the request ---
            const response = await apiClient.post('/admin/login', {
                email,
                password,
            });
            
            if (response.status === 200 && response.data.token) {
                // This part is correct: it passes the token up to the parent.
                onLoginSuccess(response.data.token); 
            }
        } catch (err) {
            setError(err.response?.data?.message || 'Login failed. Please check your credentials.');
            setShake(true);
            setTimeout(() => setShake(false), 500);
        } finally {
            setIsLoading(false);
        }
    };

    const handleTogglePasswordVisibility = () => {
        setShowPassword(!showPassword);
    };

    // --- The rest of the JSX is unchanged and correct ---
    return (
        <Box
            display="flex"
            alignItems="center"
            justifyContent="center"
            minHeight="100vh"
            width="100vw"
            sx={{
                background: `radial-gradient(circle, ${colors.primary[800]} 0%, ${colors.primary[900]} 100%)`,
            }}
        >
            <Fade in={true} timeout={500}>
                <Box
                    display="flex"
                    flexDirection="column"
                    alignItems="center"
                    justifyContent="center"
                    bgcolor={theme.palette.background.paper}
                    borderRadius="16px"
                    p="40px"
                    boxShadow={`0 10px 30px ${colors.primary[900]}`}
                    width={{ xs: '90%', sm: '400px' }}
                    sx={{
                        transform: shake ? 'translateX(-5px)' : 'translateX(0)',
                        transition: 'transform 0.3s ease',
                    }}
                >
                    <Box mb="30px" textAlign="center">
                        <Typography 
                            variant="h3" 
                            color="text.primary" 
                            fontWeight="bold" 
                            mb="10px"
                            sx={{ textShadow: `0 2px 4px rgba(0,0,0,0.2)` }}
                        >
                            Basirah Admin
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                            Sign in to continue
                        </Typography>
                    </Box>
                    
                    {error && (
                        <Box 
                            width="100%"
                            bgcolor={colors.redAccent[700]}
                            color={colors.grey[100]}
                            p="10px"
                            borderRadius="4px"
                            mb="20px"
                            textAlign="center"
                        >
                            {error}
                        </Box>
                    )}
                    
                    <form onSubmit={handleLogin} style={{ width: '100%' }}>
                        <TextField
                            label="Email Address"
                            variant="filled"
                            fullWidth
                            margin="normal"
                            value={email}
                            onChange={(e) => setEmail(e.target.value)}
                            sx={{ mb: 2 }}
                            autoFocus
                        />
                        
                        <TextField
                            label="Password"
                            type={showPassword ? "text" : "password"}
                            variant="filled"
                            fullWidth
                            margin="normal"
                            value={password}
                            onChange={(e) => setPassword(e.target.value)}
                            InputProps={{
                                endAdornment: (
                                    <InputAdornment position="end">
                                        <IconButton
                                            aria-label="toggle password visibility"
                                            onClick={handleTogglePasswordVisibility}
                                            edge="end"
                                        >
                                            {showPassword ? <VisibilityOff /> : <Visibility />}
                                        </IconButton>
                                    </InputAdornment>
                                ),
                            }}
                            sx={{ mb: 3 }}
                        />
                        
                        <Button
                            type="submit"
                            variant="contained"
                            color="secondary"
                            fullWidth
                            size="large"
                            disabled={isLoading}
                            sx={{ 
                                mt: "10px",
                                py: "12px",
                                borderRadius: '8px',
                                fontWeight: 'bold',
                                color: theme.palette.mode === 'dark' ? colors.primary[900] : colors.grey[100],
                                boxShadow: `0 4px 15px -5px ${colors.greenAccent[500]}`,
                                '&:hover': {
                                    transform: 'translateY(-2px)',
                                    boxShadow: `0 6px 20px -5px ${colors.greenAccent[500]}`,
                                }
                            }}
                        >
                            {isLoading ? <CircularProgress size={24} color="inherit" /> : 'Login'}
                        </Button>
                    </form>
                </Box>
            </Fade>
        </Box>
    );
};

export default AdminLogin;