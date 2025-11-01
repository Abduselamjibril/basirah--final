import React, { useState, useEffect, useCallback } from 'react';
import apiClient from '../../../api/axiosConfig';
import {
  Box, Button, TextField, Typography, Card, CardContent, CardMedia, IconButton,
  Alert, Tooltip, CircularProgress, Grid, Paper, FormControl,
  InputLabel, Select, MenuItem, Avatar, Chip, Dialog, DialogTitle,
  DialogContent, DialogActions, Snackbar, useTheme
} from '@mui/material';
import {
  Edit, Delete, Add, Lock, LockOpen, CloudUpload, Cancel,
  CheckCircle, Category, Description, Title
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

const CourseManager = () => {
  const theme = useTheme();
  const [courses, setCourses] = useState([]);
  const [formData, setFormData] = useState({ name: '', description: '', category: '', image: null });
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

  const fetchCourses = useCallback(async () => {
    setLoading(prev => ({ ...prev, page: true }));
    try {
      const { data } = await apiClient.get('/courses');
      setCourses(data.data || []);
    } catch (error) {
      showSnackbar('Failed to fetch courses', 'error');
    } finally {
      setLoading(prev => ({ ...prev, page: false }));
    }
  }, [showSnackbar]);

  useEffect(() => {
    fetchCourses();
  }, [fetchCourses]);

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

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
    const { image, ...otherData } = formData;
    Object.entries(otherData).forEach(([key, value]) => { if (value) data.append(key, value) });
    if (image) data.append('image', image);

    try {
      if (editingId) {
        // UPDATED: Use apiClient.put for updates
        const response = await apiClient.post(`/admin/courses/${editingId}`, data, {
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        });
        showSnackbar('Course updated!', 'success');
        const updatedCourse = response.data.data;
        setCourses(prevCourses => 
          prevCourses.map(c => c.id === updatedCourse.id ? updatedCourse : c)
        );
      } else {
        // Create (POST) logic is unchanged
        const response = await apiClient.post('/admin/courses', data);
        showSnackbar('Course created!', 'success');
        const newCourse = response.data.data;
        setCourses(prevCourses => [newCourse, ...prevCourses]);
      }
      resetForm();
    } catch (error) {
      showSnackbar(error.response?.data?.message || 'Operation failed', 'error');
    } finally {
      setLoading(prev => ({ ...prev, submit: false }));
    }
  };

  const handleEdit = (course) => {
    setFormData({ name: course.name, description: course.description, category: course.category, image: null });
    setEditingId(course.id);
    setPreviewImage(course.image_path || null);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const confirmDelete = (id) => {
    setDeleteId(id);
    setOpenDeleteDialog(true);
  };

  const handleDelete = async () => {
    setLoading({ ...loading, delete: true });
    try {
      await apiClient.delete(`/admin/courses/${deleteId}`);
      showSnackbar('Course deleted!', 'success');
      setCourses(prev => prev.filter(c => c.id !== deleteId));
    } catch (error) {
      showSnackbar(error.response?.data?.message || 'Deletion failed', 'error');
    } finally {
      setLoading({ ...loading, delete: false });
      setOpenDeleteDialog(false);
      setDeleteId(null);
    }
  };

  const toggleLock = async (course) => {
    setLoading(p => ({ ...p, lock: course.id }));
    const endpoint = course.is_premium ? 'unlock' : 'lock';
    try {
      const response = await apiClient.post(`/admin/courses/${course.id}/${endpoint}`);
      const updatedCourse = response.data.data; 
      setCourses(prevCourses => 
        prevCourses.map(c => 
          c.id === updatedCourse.id ? updatedCourse : c
        )
      );
      showSnackbar(`Course ${endpoint}ed successfully!`, 'success');
    } catch (error) {
      showSnackbar(error.response?.data?.message || 'Operation failed', 'error');
    } finally {
      setLoading(p => ({ ...p, lock: null }));
    }
  };

  const resetForm = () => {
    setFormData({ name: '', description: '', category: '', image: null });
    setEditingId(null);
    setPreviewImage(null);
  };

  return (
    <Box m="20px">
      <Header title="COURSE MANAGEMENT" subtitle="Create, edit, and manage all Courses" />

      <Paper elevation={3} sx={{ p: { xs: 2, md: 4 }, mb: 4, borderRadius: '12px' }}>
        <Typography variant="h5" sx={{ mb: 3, display: 'flex', alignItems: 'center', gap: 1 }}>
          {editingId ? <Edit color="secondary" /> : <Add color="secondary" />}
          {editingId ? 'Edit Course' : 'Create New Course'}
        </Typography>

        <form onSubmit={handleSubmit}>
          <Grid container spacing={3}>
            <Grid item xs={12} md={6}>
              <TextField fullWidth label="Course Name" name="name" value={formData.name} onChange={handleChange} required variant="filled" InputProps={{ startAdornment: (<Title color="action" sx={{ mr: 1 }} />) }} />
              <TextField fullWidth label="Description" name="description" value={formData.description} onChange={handleChange} required multiline rows={4} sx={{ mt: 2 }} variant="filled" InputProps={{ startAdornment: (<Description color="action" sx={{ mr: 1 }} />) }} />
              <FormControl fullWidth sx={{ mt: 2 }} variant="filled">
                <InputLabel>Category</InputLabel>
                <Select name="category" value={formData.category} onChange={handleChange} label="Category" required startAdornment={<Category color="action" sx={{ mr: 1, ml: -0.5 }} />}>
                  <MenuItem value="Introduction to Quran">Introduction to Quran</MenuItem>
                  <MenuItem value="Messages in Quran">Messages in Quran</MenuItem>
                </Select>
              </FormControl>
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
              {editingId ? 'Update Course' : 'Create Course'}
            </Button>
          </Box>
        </form>
      </Paper>

      {loading.page ? ( <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}><CircularProgress color="secondary" /></Box> ) : (
        <Grid container spacing={3}>
          {courses.map((course) => (
            <Grid item xs={12} sm={6} md={4} key={course.id}>
              <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}>
                <StyledCard sx={{ position: 'relative' }}>
                  <Chip label="PREMIUM" color="warning" size="small" sx={{ position: 'absolute', top: 10, right: 10, zIndex: 1, visibility: course.is_premium ? 'visible' : 'hidden' }} />
                  <CardMedia component="img" height="160" image={course.image_path || '/placeholder-course.jpg'} alt={course.name} />
                  <CardContent>
                    <Typography gutterBottom variant="h6">{course.name}</Typography>
                    <Typography variant="body2" color="text.secondary" sx={{ mb: 1, minHeight: '40px', overflow: 'hidden', textOverflow: 'ellipsis', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical' }}>
                      {course.description}
                    </Typography>
                    <Chip label={course.category} size="small" color="secondary" variant="outlined" sx={{ mt: 1 }} />
                  </CardContent>
                  <Box sx={{ display: 'flex', justifyContent: 'space-around', p: 1, bgcolor: 'action.hover' }}>
                    <Tooltip title="Edit"><IconButton onClick={() => handleEdit(course)} color="secondary"><Edit /></IconButton></Tooltip>
                    <Tooltip title="Delete"><IconButton onClick={() => confirmDelete(course.id)} color="error"><Delete /></IconButton></Tooltip>
                    <Tooltip title={course.is_premium ? 'Make Free' : 'Make Premium'}><span><IconButton onClick={() => toggleLock(course)} color={course.is_premium ? 'warning' : 'default'} disabled={!!loading.lock}>{loading.lock === course.id ? <CircularProgress size={24} /> : course.is_premium ? <Lock /> : <LockOpen />}</IconButton></span></Tooltip>
                    <Tooltip title="Manage Episodes"><IconButton onClick={() => navigate(`/upload/course/${course.id}/episodes`)} sx={{ color: theme.palette.success.main }}><Add /></IconButton></Tooltip>
                  </Box>
                </StyledCard>
              </motion.div>
            </Grid>
          ))}
        </Grid>
      )}

      <Dialog open={openDeleteDialog} onClose={() => setOpenDeleteDialog(false)}>
        <DialogTitle>Confirm Deletion</DialogTitle>
        <DialogContent><Typography>Are you sure you want to delete this course? This action cannot be undone.</Typography></DialogContent>
        <DialogActions>
          <Button onClick={() => setOpenDeleteDialog(false)}>Cancel</Button>
          <Button onClick={handleDelete} color="error" variant="contained" disabled={loading.delete} startIcon={loading.delete ? <CircularProgress size={20} /> : <Delete />}>Delete</Button>
        </DialogActions>
      </Dialog>
      <Snackbar open={snackbar.open} autoHideDuration={6000} onClose={() => setSnackbar(p => ({...p, open: false}))} anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}>
        <Alert onClose={() => setSnackbar(p => ({...p, open: false}))} severity={snackbar.severity} sx={{ width: '100%' }}>{snackbar.message}</Alert>
      </Snackbar>
    </Box>
  );
};

export default CourseManager;