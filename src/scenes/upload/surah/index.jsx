import React, { useState, useEffect, useCallback } from 'react';
import apiClient from '../../../api/axiosConfig';
import {
  Box, Avatar, Button, TextField, Typography, Card, CardContent, CardMedia,
  IconButton, Alert, Tooltip, CircularProgress, Grid, Paper, Chip, Dialog,
  DialogTitle, DialogContent, DialogActions, Snackbar, useTheme
} from '@mui/material';
import {
  Edit, Delete, Add, CloudUpload, Cancel, CheckCircle, Description, Title,
  Lock, LockOpen, DeleteForever as DeleteForeverIcon
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

const SurahManager = () => {
  const theme = useTheme();
  const [surahs, setSurahs] = useState([]);
  const [formData, setFormData] = useState({ name: '', description: '', juz: '', image: null });
  const [editingId, setEditingId] = useState(null);
  const [previewImage, setPreviewImage] = useState(null);
  const [openDeleteDialog, setOpenDeleteDialog] = useState(false);
  const [deleteId, setDeleteId] = useState(null);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });
  const [loading, setLoading] = useState({ submit: false, page: true, delete: false, lock: null });
  const [filterJuz, setFilterJuz] = useState('');
  const navigate = useNavigate();

  const showSnackbar = useCallback((message, severity = 'success') => {
    setSnackbar({ open: true, message, severity });
  }, []);

  const fetchSurahs = useCallback(async () => {
    setLoading(prev => ({ ...prev, page: true }));
    try {
      const { data } = await apiClient.get('/surahs', {
        params: filterJuz ? { juz: filterJuz } : {}
      });
      setSurahs(data.data || []);
    } catch (error) {
      showSnackbar('Failed to fetch surahs', 'error');
    } finally {
      setLoading(prev => ({ ...prev, page: false }));
    }
  }, [showSnackbar, filterJuz]);

  useEffect(() => {
    fetchSurahs();
  }, [fetchSurahs, filterJuz]);

  const handleChange = (e) => setFormData({ ...formData, [e.target.name]: e.target.value });

  const handleImageChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      setFormData({ ...formData, image: file });
      setPreviewImage(URL.createObjectURL(file));
    }
  };
  
  // NEW: Function to handle image removal from the form
  const handleRemoveImage = () => {
      setFormData({ ...formData, image: null }); // Signal for removal
      setPreviewImage(null);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading({ ...loading, submit: true });
    
    const data = new FormData();
    data.append('name', formData.name);
    data.append('description', formData.description || '');
    if (formData.juz) data.append('juz', formData.juz);

    // Handle the three image states to match the backend controller
    if (formData.image instanceof File) {
        // 1. New image is being uploaded
        data.append('image', formData.image);
    } else if (formData.image === null && editingId && previewImage === null) {
        // 2. User explicitly removed the image during an edit
        data.append('image', ''); // Sending empty string signals removal
    }
    // 3. If neither of the above, we don't append the image key, so it remains unchanged on the backend.

    try {
      if (editingId) {
        // UPDATED: Use apiClient.put and the /admin prefix.
        const response = await apiClient.post(`/admin/surahs/${editingId}`, data, {
            headers: { 'Content-Type': 'multipart/form-data' },
        });
        showSnackbar('Surah updated successfully!', 'success');
        // UPDATED: Efficiently update local state.
        const updatedSurah = response.data.data;
        setSurahs(prev => prev.map(s => s.id === updatedSurah.id ? updatedSurah : s));
      } else {
        // UPDATED: Use the /admin prefix for creation.
        const response = await apiClient.post('/admin/surahs', data);
        showSnackbar('Surah created successfully!', 'success');
        // UPDATED: Efficiently update local state.
        const newSurah = response.data.data;
        setSurahs(prev => [newSurah, ...prev]);
      }
      resetForm();
    } catch (error) {
      showSnackbar(error.response?.data?.message || 'Operation failed', 'error');
    } finally {
      setLoading(prev => ({ ...prev, submit: false }));
    }
  };
  
  const handleEdit = (surah) => {
    setFormData({ name: surah.name, description: surah.description, juz: surah.juz || '', image: 'unchanged' }); // Use 'unchanged' to start
    setEditingId(surah.id);
    setPreviewImage(surah.image || null);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const confirmDelete = (id) => {
    setDeleteId(id);
    setOpenDeleteDialog(true);
  };

  const handleDelete = async () => {
    setLoading({ ...loading, delete: true });
    try {
      // UPDATED: Use the /admin prefixed route.
      await apiClient.delete(`/admin/surahs/${deleteId}`);
      showSnackbar('Surah deleted successfully!', 'success');
      // UPDATED: Efficiently update local state.
      setSurahs(prev => prev.filter(s => s.id !== deleteId));
      setOpenDeleteDialog(false);
    } catch (error) {
      showSnackbar(error.response?.data?.message || 'Deletion failed', 'error');
    } finally {
      setLoading({ ...loading, delete: false });
    }
  };

  const toggleLock = async (surah) => {
    setLoading(p => ({ ...p, lock: surah.id }));
    const endpoint = surah.is_premium ? 'unlock' : 'lock';
    try {
      // UPDATED: Use the /admin prefixed route.
      const response = await apiClient.post(`/admin/surahs/${surah.id}/${endpoint}`);
      const updatedSurah = response.data.data;
      
      setSurahs(prevSurahs =>
        prevSurahs.map(s =>
          s.id === updatedSurah.id ? updatedSurah : s
        )
      );
      showSnackbar(`Surah ${endpoint}ed successfully!`, 'success');
    } catch (error) {
      showSnackbar(error.response?.data?.message || 'Operation failed', 'error');
    } finally {
      setLoading(p => ({ ...p, lock: null }));
    }
  };

  const resetForm = () => {
    setFormData({ name: '', description: '', juz: '', image: null });
    setEditingId(null);
    setPreviewImage(null);
  };

  const handleCloseSnackbar = () => setSnackbar({ ...snackbar, open: false });

  return (
    <Box m="20px">
      <Header title="SURAH MANAGEMENT" subtitle="Create, edit, and manage all Surahs" />
      <Paper elevation={3} sx={{ p: { xs: 2, md: 4 }, mb: 4, borderRadius: '12px' }}>
        <Typography variant="h5" sx={{ mb: 3, display: 'flex', alignItems: 'center', gap: 1 }}>
          {editingId ? <Edit color="secondary" /> : <Add color="secondary" />}
          {editingId ? 'Edit Surah' : 'Create New Surah'}
        </Typography>
        <form onSubmit={handleSubmit}>
          <Grid container spacing={3}>
            <Grid item xs={12} md={6}>
              <TextField fullWidth label="Surah Name" name="name" value={formData.name} onChange={handleChange} required variant="filled" InputProps={{ startAdornment: (<Title color="action" sx={{ mr: 1 }} />) }} />
              <TextField fullWidth label="Description" name="description" value={formData.description} onChange={handleChange} multiline rows={4} sx={{ mt: 2 }} variant="filled" InputProps={{ startAdornment: (<Description color="action" sx={{ mr: 1 }} />) }} />
              <TextField fullWidth select label="Juz" name="juz" value={formData.juz} onChange={handleChange} SelectProps={{ native: true }} variant="filled" sx={{ mt: 2 }} InputProps={{ startAdornment: (<Typography color="action" sx={{ mr: 1, fontWeight: 'bold' }}>J</Typography>) }}>
                <option value="">Select Juz (Optional)</option>
                {[...Array(30)].map((_, i) => (
                  <option key={i + 1} value={i + 1}>Juz {i + 1}</option>
                ))}
              </TextField>
            </Grid>
            <Grid item xs={12} md={6} sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
              <Avatar src={previewImage} variant="rounded" sx={{ width: 200, height: 200, mb: 2, bgcolor: 'action.hover' }}>
                {!previewImage && <CloudUpload fontSize="large" />}
              </Avatar>
              <Box sx={{ display: 'flex', gap: 1 }}>
                <Button component="label" variant="contained" color="secondary" startIcon={<CloudUpload />}>
                  {editingId && previewImage ? 'Change Image' : 'Upload Image'}
                  <input type="file" hidden onChange={handleImageChange} accept="image/*" />
                </Button>
                {/* NEW: Button to remove the image */}
                {editingId && previewImage && (
                    <Tooltip title="Remove Image">
                        <Button variant="outlined" color="error" onClick={handleRemoveImage}>
                            <DeleteForeverIcon />
                        </Button>
                    </Tooltip>
                )}
              </Box>
            </Grid>
          </Grid>
          <Box sx={{ display: 'flex', justifyContent: 'flex-end', mt: 3, gap: 2 }}>
            {editingId && (<Button variant="outlined" color="inherit" onClick={resetForm} startIcon={<Cancel />}>Cancel Edit</Button>)}
            <Button type="submit" variant="contained" color="secondary" disabled={loading.submit} startIcon={loading.submit ? <CircularProgress size={20} /> : <CheckCircle />}>
              {editingId ? 'Update Surah' : 'Create Surah'}
            </Button>
          </Box>
        </form>
      </Paper>

      {/* FILTER SECTION */}
      <Box sx={{ mb: 3, display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 2 }}>
        <Typography variant="h5" color="text.primary" sx={{ fontWeight: 'bold' }}>
          All Surahs {filterJuz && <Chip label={`Juz ${filterJuz}`} color="primary" variant="outlined" size="small" />}
        </Typography>
        <TextField
          select
          label="Filter by Juz"
          value={filterJuz}
          onChange={(e) => setFilterJuz(e.target.value)}
          SelectProps={{ native: true }}
          variant="outlined"
          size="small"
          sx={{ minWidth: 200 }}
        >
          <option value="">All Juzes</option>
          {[...Array(30)].map((_, i) => (
            <option key={i + 1} value={i + 1}>Juz {i + 1}</option>
          ))}
        </TextField>
      </Box>

      {loading.page ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}><CircularProgress color="secondary"/></Box>
      ) : (
        <Grid container spacing={3}>
          {surahs.map((surah) => (
            <Grid item xs={12} sm={6} md={4} key={surah.id}>
              <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3 }}>
                <StyledCard sx={{ position: 'relative' }}>
                  <Chip label="PREMIUM" color="warning" size="small" sx={{ position: 'absolute', top: 10, right: 10, zIndex: 1, visibility: surah.is_premium ? 'visible' : 'hidden' }} />
                  <CardMedia component="img" height="160" image={surah.image || '/placeholder-surah.jpg'} alt={surah.name} />
                  <CardContent>
                    <Typography gutterBottom variant="h6" component="div">
                      {surah.name}
                      {surah.juz && <Chip label={`Juz ${surah.juz}`} size="small" color="primary" sx={{ ml: 1, height: '20px' }} />}
                    </Typography>
                    <Typography variant="body2" color="text.secondary" sx={{ minHeight: '40px', overflow: 'hidden', textOverflow: 'ellipsis', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical' }}>
                      {surah.description}
                    </Typography>
                  </CardContent>
                  <Box sx={{ display: 'flex', justifyContent: 'space-around', p: 1, bgcolor: 'action.hover' }}>
                    <Tooltip title="Edit"><IconButton onClick={() => handleEdit(surah)} color="secondary"><Edit /></IconButton></Tooltip>
                    <Tooltip title="Delete"><IconButton onClick={() => confirmDelete(surah.id)} color="error"><Delete /></IconButton></Tooltip>
                    <Tooltip title={surah.is_premium ? 'Make Free' : 'Make Premium'}><span><IconButton onClick={() => toggleLock(surah)} color={surah.is_premium ? 'warning' : 'default'} disabled={!!loading.lock}>{loading.lock === surah.id ? <CircularProgress size={24} /> : surah.is_premium ? <Lock /> : <LockOpen />}</IconButton></span></Tooltip>
                    <Tooltip title="Manage Episodes"><IconButton onClick={() => navigate(`/upload/surah/${surah.id}/episodes`)} sx={{ color: theme.palette.success.main }}><Add /></IconButton></Tooltip>
                  </Box>
                </StyledCard>
              </motion.div>
            </Grid>
          ))}
        </Grid>
      )}
      <Dialog open={openDeleteDialog} onClose={() => setOpenDeleteDialog(false)}>
        <DialogTitle>Confirm Deletion</DialogTitle>
        <DialogContent><Typography>Are you sure you want to delete this surah? This action cannot be undone.</Typography></DialogContent>
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

export default SurahManager;