import React, { useState, useEffect, useCallback } from 'react';
import apiClient from '../api/axiosConfig';
import {
  Box, Button, TextField, Typography, Paper,
  CircularProgress, Grid, Snackbar, Alert
} from '@mui/material';
import { Save } from '@mui/icons-material';
import Header from './Header'; // Adjust path if necessary
import { toast, Toaster } from 'react-hot-toast';

const ContentEditorPage = ({ pageTitle, pageSubtitle, endpoint }) => {
  const [formData, setFormData] = useState({ title: '', content: '' });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const response = await apiClient.get(`/admin/${endpoint}`);
      setFormData(response.data);
    } catch (error) {
      console.error(`Failed to fetch ${endpoint} data:`, error);
      toast.error(`Failed to load content for ${pageTitle}.`);
    } finally {
      setLoading(false);
    }
  }, [endpoint, pageTitle]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const handleChange = (e) => {
    setFormData(prev => ({ ...prev, [e.target.name]: e.target.value }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!formData.title.trim() || !formData.content.trim()) {
      toast.error('Title and Content fields cannot be empty.');
      return;
    }
    setSaving(true);
    try {
      await apiClient.post(`/admin/${endpoint}`, formData);
      toast.success('Content updated successfully!');
    } catch (error) {
      const errorMsg = error.response?.data?.message || 'An error occurred while saving.';
      toast.error(errorMsg);
      console.error(`Failed to save ${endpoint} data:`, error);
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <Box m="20px">
        <Header title={pageTitle.toUpperCase()} subtitle={pageSubtitle} />
        <Box display="flex" justifyContent="center" alignItems="center" height="60vh">
          <CircularProgress color="secondary" />
        </Box>
      </Box>
    );
  }

  return (
    <Box m="20px">
      <Toaster position="top-center" />
      <Header title={pageTitle.toUpperCase()} subtitle={pageSubtitle} />
      <Paper sx={{ p: { xs: 2, md: 4 }, borderRadius: '12px' }}>
        <form onSubmit={handleSubmit}>
          <Grid container spacing={3}>
            <Grid item xs={12}>
              <TextField
                name="title"
                label="Page Title"
                value={formData.title}
                onChange={handleChange}
                fullWidth
                required
                variant="filled"
              />
            </Grid>
            <Grid item xs={12}>
              <TextField
                name="content"
                label="Page Content"
                value={formData.content}
                onChange={handleChange}
                fullWidth
                multiline
                rows={15}
                required
                variant="filled"
              />
            </Grid>
          </Grid>
          <Box display="flex" justifyContent="flex-end" mt={3}>
            <Button
              variant="contained"
              color="secondary"
              type="submit"
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

export default ContentEditorPage;