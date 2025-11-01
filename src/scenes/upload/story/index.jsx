import React, { useState, useEffect, useCallback } from 'react';
import apiClient from '../../../api/axiosConfig';
import {
  Box, Button, TextField, Typography, Card, CardContent, CardMedia, IconButton,
  Alert, Tooltip, CircularProgress, Grid, Paper, Avatar, Chip, Dialog,
  DialogTitle, DialogContent, DialogActions, Snackbar, useTheme
} from '@mui/material';
import {
  Edit, Delete, Add, CloudUpload, Cancel, CheckCircle, Description, Title,
  Lock, LockOpen
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { styled } from '@mui/material/styles';
import { motion } from 'framer-motion';
import Header from '../../../components/Header';

const StyledCard = styled(Card)(({ theme }) => ({
  transition: 'transform 0.3s, box-shadow 0.3s',
  '&:hover': {
    transform: 'translateY(-5px)',
    boxShadow: theme.shadows[8]
  }
}));

const StoryManager = () => {
  const theme = useTheme();
  const [stories, setStories] = useState([]);
  const [formData, setFormData] = useState({ name: '', description: '', image: null });
  const [editingId, setEditingId] = useState(null);
  const [previewImage, setPreviewImage] = useState(null);
  const [openDeleteDialog, setOpenDeleteDialog] = useState(false);
  const [deleteId, setDeleteId] = useState(null);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });
  const [loading, setLoading] = useState({ submit: false, page: true, delete: false, lock: null });
  const navigate = useNavigate();

  const showSnackbar = useCallback((message, severity = 'success') => {
    setSnackbar({ open: true, message, severity });
  }, []);

  const fetchStories = useCallback(async () => {
    setLoading(prev => ({ ...prev, page: true }));
    try {
      const { data } = await apiClient.get('/stories');
      setStories(data.data || []);
    } catch (error) {
      showSnackbar('Failed to fetch stories', 'error');
    } finally {
      setLoading(prev => ({ ...prev, page: false }));
    }
  }, [showSnackbar]);

  useEffect(() => {
    fetchStories();
  }, [fetchStories]);

  const handleChange = (e) => setFormData({ ...formData, [e.target.name]: e.target.value });

  const handleImageChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      setFormData({ ...formData, image: file });
      setPreviewImage(URL.createObjectURL(file));
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading({ ...loading, submit: true });
    const data = new FormData();
    Object.entries(formData).forEach(([key, value]) => { if (value) data.append(key, value) });
    
    try {
      if (editingId) {
        const response = await apiClient.post(`/admin/stories/${editingId}`, data, {
            headers: { 'Content-Type': 'multipart/form-data' },
        });
        showSnackbar('Story updated successfully!', 'success');
        const updatedStory = response.data.data;
        setStories(prev => prev.map(s => s.id === updatedStory.id ? updatedStory : s));
      } else {
        const response = await apiClient.post('/admin/stories', data);
        showSnackbar('Story created successfully!', 'success');
        const newStory = response.data.data;
        setStories(prev => [newStory, ...prev]);
      }
      resetForm();
    } catch (error) {
      showSnackbar(error.response?.data?.message || 'Operation failed', 'error');
    } finally {
      setLoading(prev => ({ ...prev, submit: false }));
    }
  };

  const handleEdit = (story) => {
    setFormData({ name: story.name, description: story.description, image: null });
    setEditingId(story.id);
    setPreviewImage(story.image || null);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const confirmDelete = (id) => {
    setDeleteId(id);
    setOpenDeleteDialog(true);
  };

  const handleDelete = async () => {
    setLoading({ ...loading, delete: true });
    try {
      await apiClient.delete(`/admin/stories/${deleteId}`);
      showSnackbar('Story deleted successfully!', 'success');
      setStories(prev => prev.filter(s => s.id !== deleteId));
      setOpenDeleteDialog(false);
    } catch (error) { // <-- The typo is removed here
      showSnackbar(error.response?.data?.message || 'Deletion failed', 'error');
    } finally {
      setLoading(prev => ({ ...prev, delete: false }));
    }
  };

  const toggleLock = async (story) => {
    setLoading(p => ({ ...p, lock: story.id }));
    const endpoint = story.is_premium ? 'unlock' : 'lock';
    try {
      const response = await apiClient.post(`/admin/stories/${story.id}/${endpoint}`);
      const updatedStory = response.data.data;
      
      setStories(prevStories => 
        prevStories.map(s => 
          s.id === updatedStory.id ? updatedStory : s
        )
      );
      showSnackbar(`Story ${endpoint}ed successfully!`, 'success');
    } catch (error) {
      showSnackbar(error.response?.data?.message || 'Operation failed', 'error');
    } finally {
      setLoading(p => ({ ...p, lock: null }));
    }
  };

  const resetForm = () => {
    setFormData({ name: '', description: '', image: null });
    setEditingId(null);
    setPreviewImage(null);
  };

  const handleCloseSnackbar = () => setSnackbar({ ...snackbar, open: false });

  return (
    <Box m="20px">
      <Header title="STORY MANAGEMENT" subtitle="Create, edit, and manage all Stories" />
      <Paper elevation={3} sx={{ p: { xs: 2, md: 4 }, mb: 4, borderRadius: '12px' }}>
        <Typography variant="h5" sx={{ mb: 3, display: 'flex', alignItems: 'center', gap: 1 }}>
          {editingId ? <Edit color="secondary" /> : <Add color="secondary" />}
          {editingId ? 'Edit Story' : 'Create New Story'}
        </Typography>
        <form onSubmit={handleSubmit}>
          <Grid container spacing={3}>
            <Grid item xs={12} md={6}>
              <TextField fullWidth label="Story Name" name="name" value={formData.name} onChange={handleChange} required variant="filled" InputProps={{ startAdornment: (<Title color="action" sx={{ mr: 1 }} />) }} />
              <TextField fullWidth label="Description" name="description" value={formData.description} onChange={handleChange} required multiline rows={4} sx={{ mt: 2 }} variant="filled" InputProps={{ startAdornment: (<Description color="action" sx={{ mr: 1 }} />) }} />
            </Grid>
            <Grid item xs={12} md={6} sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
              <Avatar src={previewImage} variant="rounded" sx={{ width: 200, height: 200, mb: 2, bgcolor: 'action.hover' }}>
                {!previewImage && <CloudUpload fontSize="large" />}
              </Avatar>
              <Button component="label" variant="contained" color="secondary" startIcon={<CloudUpload />}>
                Upload Image
                <input type="file" hidden onChange={handleImageChange} accept="image/*" />
              </Button>
            </Grid>
          </Grid>
          <Box sx={{ display: 'flex', justifyContent: 'flex-end', mt: 3, gap: 2 }}>
            {editingId && (<Button variant="outlined" color="inherit" onClick={resetForm} startIcon={<Cancel />}>Cancel Edit</Button>)}
            <Button type="submit" variant="contained" color="secondary" disabled={loading.submit} startIcon={loading.submit ? <CircularProgress size={20} /> : <CheckCircle />}>
              {editingId ? 'Update Story' : 'Create Story'}
            </Button>
          </Box>
        </form>
      </Paper>
      {loading.page ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}><CircularProgress color="secondary" /></Box>
      ) : (
        <Grid container spacing={3}>
          {stories.map((story) => (
            <Grid item xs={12} sm={6} md={4} key={story.id}>
              <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3 }}>
                <StyledCard sx={{ position: 'relative' }}>
                  <Chip label="PREMIUM" color="warning" size="small" sx={{ position: 'absolute', top: 10, right: 10, zIndex: 1, visibility: story.is_premium ? 'visible' : 'hidden' }} />
                  <CardMedia component="img" height="160" image={story.image || '/placeholder-story.jpg'} alt={story.name} />
                  <CardContent>
                    <Typography gutterBottom variant="h6" component="div">{story.name}</Typography>
                    <Typography variant="body2" color="text.secondary" sx={{ minHeight: '40px', overflow: 'hidden', textOverflow: 'ellipsis', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical' }}>
                      {story.description}
                    </Typography>
                  </CardContent>
                  <Box sx={{ display: 'flex', justifyContent: 'space-around', p: 1, bgcolor: 'action.hover' }}>
                    <Tooltip title="Edit"><IconButton onClick={() => handleEdit(story)} color="secondary"><Edit /></IconButton></Tooltip>
                    <Tooltip title="Delete"><IconButton onClick={() => confirmDelete(story.id)} color="error"><Delete /></IconButton></Tooltip>
                    <Tooltip title={story.is_premium ? 'Make Free' : 'Make Premium'}><span><IconButton onClick={() => toggleLock(story)} color={story.is_premium ? 'warning' : 'default'} disabled={!!loading.lock}>{loading.lock === story.id ? <CircularProgress size={24} /> : story.is_premium ? <Lock /> : <LockOpen />}</IconButton></span></Tooltip>
                    <Tooltip title="Manage Episodes"><IconButton onClick={() => navigate(`/upload/story/${story.id}/episodes`)} sx={{ color: theme.palette.success.main }}><Add /></IconButton></Tooltip>
                  </Box>
                </StyledCard>
              </motion.div>
            </Grid>
          ))}
        </Grid>
      )}
      <Dialog open={openDeleteDialog} onClose={() => setOpenDeleteDialog(false)}>
        <DialogTitle>Confirm Deletion</DialogTitle>
        <DialogContent><Typography>Are you sure you want to delete this story? This action cannot be undone.</Typography></DialogContent>
        <DialogActions>
          <Button onClick={() => setOpenDeleteDialog(false)}>Cancel</Button>
          <Button onClick={handleDelete} color="error" variant="contained" disabled={loading.delete} startIcon={loading.delete ? <CircularProgress size={20} /> : <Delete />}>Delete</Button>
        </DialogActions>
      </Dialog>
      <Snackbar open={snackbar.open} autoHideDuration={6000} onClose={handleCloseSnackbar} anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}>
        <Alert onClose={handleCloseSnackbar} severity={snackbar.severity} sx={{ width: '100%' }}>{snackbar.message}</Alert>
      </Snackbar>
    </Box>
  );
};

export default StoryManager;