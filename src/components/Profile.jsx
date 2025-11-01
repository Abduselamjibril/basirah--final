import React, { useEffect, useState } from 'react';
import { Box, Button, TextField, Typography, useTheme, CircularProgress } from '@mui/material';
import { tokens } from '../theme';
import { Toaster, toast } from 'react-hot-toast';
import apiClient from '../api/axiosConfig'; 
import { useAuth } from '../context/AuthContext'; // <-- NEW IMPORT

function Profile({ onLogout }) {
  const theme = useTheme();
  const colors = tokens(theme.palette.mode);
  const { user, fetchUser } = useAuth(); // <-- GET USER FROM CONTEXT

  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [profileLoading, setProfileLoading] = useState(false);

  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmNewPassword, setConfirmNewPassword] = useState('');
  const [passwordLoading, setPasswordLoading] = useState(false);

  useEffect(() => {
    if (user) {
      setName(user.name || '');
      setEmail(user.email || '');
    }
  }, [user]);

  const handleProfileUpdate = async (e) => {
    e.preventDefault();
    setProfileLoading(true);
    try {
      await apiClient.put('/admin/profile', { name, email });
      toast.success('Profile updated successfully!');
      await fetchUser(); // Re-fetch user to update context and JWT
    } catch (error) {
      const errorMsg = error.response?.data?.message || 'Failed to update profile.';
      toast.error(`Error: ${errorMsg}`);
    } finally {
      setProfileLoading(false);
    }
  };

  const handleChangePassword = async (e) => {
    e.preventDefault();

    if (newPassword !== confirmNewPassword) {
      toast.error('New passwords do not match.');
      return;
    }
    
    if (newPassword.length < 8) {
      toast.error('New password must be at least 8 characters long.');
      return;
    }

    setPasswordLoading(true);
    try {
      await apiClient.post('/admin/change-password', {
        current_password: currentPassword,
        new_password: newPassword,
        new_password_confirmation: confirmNewPassword,
      });
      toast.success('Password updated successfully!');
      setCurrentPassword('');
      setNewPassword('');
      setConfirmNewPassword('');
    } catch (error) {
      const errorMsg = error.response?.data?.message || 'An error occurred.';
      toast.error(`Error: ${errorMsg}`);
    } finally {
      setPasswordLoading(false);
    }
  };
  
  return (
    <Box m="20px" display="flex" justifyContent="center">
      <Toaster position="top-center" reverseOrder={false} />
      <Box p={4} width="100%" maxWidth="600px" bgcolor={theme.palette.background.paper} borderRadius="8px" boxShadow={3}>
        <Typography variant="h2" fontWeight="bold" color="text.primary" mb={1}>
          Admin Profile
        </Typography>
        {user && (
          <Typography variant="h5" color="text.secondary" mb={4}>
            Logged in as: {user.email}
          </Typography>
        )}
        
        {user?.is_super_admin ? (
          <Box component="form" onSubmit={handleProfileUpdate} mb={4} pb={4} borderBottom={`1px solid ${colors.grey[700]}`}>
            <Typography variant="h4" color="text.primary" mb={2}>Edit Your Profile</Typography>
            <TextField fullWidth variant="filled" label="Role Name" value={name} onChange={(e) => setName(e.target.value)} required sx={{ mb: 2 }}/>
            <TextField fullWidth variant="filled" label="Email Address" type="email" value={email} onChange={(e) => setEmail(e.target.value)} required sx={{ mb: 2 }}/>
            <Button type="submit" variant="contained" color="secondary" disabled={profileLoading} fullWidth>
              {profileLoading ? <CircularProgress size={24} color="inherit" /> : 'Save Profile Changes'}
            </Button>
          </Box>
        ) : (
          <Box mb={4} pb={4} borderBottom={`1px solid ${colors.grey[700]}`}>
             <Typography variant="h4" color="text.primary" mb={2}>Your Profile</Typography>
             <TextField fullWidth variant="filled" label="Role Name" value={name} disabled sx={{ mb: 2 }}/>
            <TextField fullWidth variant="filled" label="Email Address" type="email" value={email} disabled sx={{ mb: 2 }}/>
          </Box>
        )}

        <Box component="form" onSubmit={handleChangePassword}>
          <Typography variant="h4" color="text.primary" mb={2}>Change Your Password</Typography>
          <TextField fullWidth variant="filled" type="password" label="Current Password" value={currentPassword} onChange={(e) => setCurrentPassword(e.target.value)} required sx={{ mb: 2 }} />
          <TextField fullWidth variant="filled" type="password" label="New Password" value={newPassword} onChange={(e) => setNewPassword(e.target.value)} required sx={{ mb: 2 }} />
          <TextField fullWidth variant="filled" type="password" label="Confirm New Password" value={confirmNewPassword} onChange={(e) => setConfirmNewPassword(e.target.value)} required sx={{ mb: 3 }} />
          <Button type="submit" variant="contained" color="secondary" disabled={passwordLoading} sx={{ width: '100%' }}>
            {passwordLoading ? <CircularProgress size={24} color="inherit" /> : 'Change Password'}
          </Button>
        </Box>

        <Box mt={4} pt={4} borderTop={`1px solid ${colors.grey[700]}`}>
          <Button variant="contained" onClick={onLogout} fullWidth sx={{ backgroundColor: colors.redAccent[600], color: colors.grey[100], '&:hover': { backgroundColor: colors.redAccent[700] } }}>
            Logout
          </Button>
        </Box>
      </Box>
    </Box>
  );
}

export default Profile;