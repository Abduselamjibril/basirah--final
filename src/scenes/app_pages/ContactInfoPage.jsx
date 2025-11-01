import React, { useState, useEffect, useCallback } from 'react';
import apiClient from '../../api/axiosConfig';
import {
  Box, Button, TextField, Paper, CircularProgress,
  Grid
} from '@mui/material';
import { Save, Phone, Email } from '@mui/icons-material';
import Header from '../../components/Header';
import { toast, Toaster } from 'react-hot-toast';

const ContactInfoPage = () => {
  const [formData, setFormData] = useState({ phone_number: '', email: '' });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const response = await apiClient.get('/admin/contact-information');
      setFormData(response.data);
    } catch (error) {
      console.error('Failed to fetch contact info:', error);
      toast.error('Failed to load contact information.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const handleChange = (e) => {
    setFormData(prev => ({ ...prev, [e.target.name]: e.target.value }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      await apiClient.post('/admin/contact-information', formData);
      toast.success('Contact information updated successfully!');
    } catch (error) {
      const errorMsg = error.response?.data?.message || 'An error occurred.';
      toast.error(errorMsg);
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <Box m="20px">
        <Header title="CONTACT INFORMATION" subtitle="Manage the support contact details for the mobile app" />
        <Box display="flex" justifyContent="center" alignItems="center" height="60vh">
          <CircularProgress color="secondary" />
        </Box>
      </Box>
    );
  }

  return (
    <Box m="20px">
      <Toaster position="top-center" />
      <Header title="CONTACT INFORMATION" subtitle="Manage the support contact details for the mobile app" />
      <Paper sx={{ p: { xs: 2, md: 4 }, borderRadius: '12px' }}>
        <form onSubmit={handleSubmit}>
          <Grid container spacing={3}>
            <Grid item xs={12} md={6}>
              <TextField
                name="phone_number"
                label="Support Phone Number"
                value={formData.phone_number}
                onChange={handleChange}
                fullWidth
                required
                variant="filled"
                InputProps={{ startAdornment: <Phone sx={{ mr: 1, color: 'text.secondary' }} /> }}
              />
            </Grid>
            <Grid item xs={12} md={6}>
              <TextField
                name="email"
                label="Support Email Address"
                type="email"
                value={formData.email}
                onChange={handleChange}
                fullWidth
                required
                variant="filled"
                InputProps={{ startAdornment: <Email sx={{ mr: 1, color: 'text.secondary' }} /> }}
              />
            </Grid>
          </Grid>
          <Box display="flex" justifyContent="flex-end" mt={3}>
            <Button
              type="submit"
              color="secondary"
              variant="contained"
              disabled={saving}
              startIcon={saving ? <CircularProgress size={20} /> : <Save />}
            >
              {saving ? 'Saving...' : 'Save Changes'}
            </Button>
          </Box>
        </form>
      </Paper>
    </Box>
  );
};

export default ContactInfoPage;