// src/scenes/notificationpage/index.jsx
import React, { useState, useEffect, useCallback } from 'react';
import apiClient from '../../api/axiosConfig';
import {
  Box, Button, TextField, Typography, Table, TableBody, TableCell,
  TableContainer, TableHead, TableRow, Paper, IconButton, Alert, Chip,
  Dialog, DialogTitle, DialogContent, DialogActions,
  CircularProgress, useTheme,
  Grid, Snackbar
} from '@mui/material';
import { Edit, Delete, Notifications, Check, Close } from '@mui/icons-material';
import Header from '../../components/Header';

const NotificationPage = () => {
  const theme = useTheme();
  const [notifications, setNotifications] = useState([]);
  const [formData, setFormData] = useState({ title: '', remark: '', duration: '' });
  const [editId, setEditId] = useState(null);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'info' });
  const [loading, setLoading] = useState({ page: true, submit: false, delete: false });
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [notificationToDelete, setNotificationToDelete] = useState(null);

  const showSnackbar = useCallback((message, severity = 'info') => {
    setSnackbar({ open: true, message, severity });
  }, []);

  const fetchNotifications = useCallback(async () => {
    setLoading(p => ({ ...p, page: true }));
    try {
      // The shared GET /notifications route is under the main API, not /admin
      const response = await apiClient.get('/notifications'); 
      const notificationsArray = response.data || [];

      const sorted = notificationsArray.sort((a, b) => 
        new Date(b.created_at || 0).getTime() - new Date(a.created_at || 0).getTime()
      );
      setNotifications(sorted);
    } catch (err) {
      const message = err.response?.status === 401 
        ? 'Authentication error. Please log in again.'
        : 'Failed to fetch notifications';
      showSnackbar(message, 'error');
      console.error("Fetch Notifications error:", err);
    } finally {
      setLoading(p => ({ ...p, page: false }));
    }
  }, [showSnackbar]);

  useEffect(() => {
    fetchNotifications();
  }, [fetchNotifications]);

  const handleChange = (e) => {
    setFormData(p => ({ ...p, [e.target.name]: e.target.value }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!formData.title.trim() || !formData.remark.trim() || formData.duration === '') {
      showSnackbar('All fields are required', 'error');
      return;
    }
    setLoading(p => ({ ...p, submit: true }));
    
    // ======================= THIS IS THE FIX =======================
    // The backend expects 'duration' to be an integer, but the value 
    // from a TextField is always a string. We must convert it.
    const payload = {
      ...formData,
      duration: parseInt(formData.duration, 10)
    };

    // Add a check to ensure the result is a valid number.
    if (isNaN(payload.duration) || payload.duration <= 0) {
        showSnackbar('Duration must be a positive number.', 'error');
        setLoading(p => ({ ...p, submit: false }));
        return;
    }
    // ===================== END OF FIX ==============================

    const method = editId ? 'put' : 'post';
    const url = editId ? `/admin/notifications/${editId}` : '/admin/notifications';

    try {
      // Use the new 'payload' object with the corrected data type
      await apiClient[method](url, payload);
      showSnackbar(editId ? 'Notification updated!' : 'Notification created!', 'success');
      resetForm();
      fetchNotifications();
    } catch (err) {
      // Provide more specific error feedback if possible
      const errorMessage = err.response?.data?.message || err.message || 'Operation failed';
      showSnackbar(errorMessage, 'error');
      console.error("Submit Notification error:", err);
    } finally {
      setLoading(p => ({ ...p, submit: false }));
    }
  };

  const handleEdit = (notification) => {
    setFormData({ title: notification.title, remark: notification.remark, duration: notification.duration });
    setEditId(notification.id);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleDeleteClick = (notification) => {
    setNotificationToDelete(notification);
    setDeleteDialogOpen(true);
  };

  const handleDelete = async () => {
    if (!notificationToDelete) return;
    setLoading(p => ({ ...p, delete: true }));
    try {
      await apiClient.delete(`/admin/notifications/${notificationToDelete.id}`);
      showSnackbar('Notification deleted!', 'success');
      fetchNotifications();
    } catch (err) {
      showSnackbar('Failed to delete notification', 'error');
      console.error("Delete Notification error:", err);
    } finally {
      setLoading(p => ({ ...p, delete: false }));
      setDeleteDialogOpen(false);
      setNotificationToDelete(null);
    }
  };

  const resetForm = () => {
    setFormData({ title: '', remark: '', duration: '' });
    setEditId(null);
  };

  return (
    <Box m="20px">
      <Header title="NOTIFICATIONS" subtitle="Send and manage push notifications" />
      
      <Paper sx={{ p: { xs: 2, md: 4 }, mb: 4, borderRadius: '12px' }}>
        <Typography variant="h5" sx={{ mb: 3, display: 'flex', alignItems: 'center', gap: 1 }}>
          <Notifications color="secondary" />
          {editId ? 'Update Notification' : 'Create New Notification'}
        </Typography>
        <form onSubmit={handleSubmit}>
          <Grid container spacing={3}>
            <Grid item xs={12} md={8}>
              <TextField name="title" label="Title" value={formData.title} onChange={handleChange} fullWidth required variant="filled" />
            </Grid>
            <Grid item xs={12} md={4}>
              <TextField name="duration" label="Duration (Minutes)" type="number" value={formData.duration} onChange={handleChange} fullWidth required variant="filled" InputProps={{ inputProps: { min: 1 } }} />
            </Grid>
            <Grid item xs={12}>
              <TextField name="remark" label="Remark / Message" value={formData.remark} onChange={handleChange} fullWidth multiline rows={4} required variant="filled" />
            </Grid>
          </Grid>
          <Box display="flex" justifyContent="flex-end" mt={3} gap={2}>
            {editId && <Button variant="outlined" color="inherit" onClick={resetForm} startIcon={<Close />}>Cancel</Button>}
            <Button variant="contained" color="secondary" type="submit" disabled={loading.submit} startIcon={loading.submit ? <CircularProgress size={20} /> : <Check />}>
              {editId ? 'Update' : 'Create & Send'}
            </Button>
          </Box>
        </form>
      </Paper>
      
      <Paper sx={{ p: 2, borderRadius: '12px' }}>
        <Typography variant="h6" gutterBottom sx={{ fontWeight: 'bold', p: 2 }}>Notification History</Typography>
        {loading.page ? (
            <Box display="flex" justifyContent="center" py={4}><CircularProgress color="secondary" /></Box>
        ) : (
          <TableContainer>
            <Table>
              <TableHead>
                <TableRow sx={{ '& th': { fontWeight: 'bold', borderBottom: `2px solid ${theme.palette.divider}` } }}>
                  <TableCell>Title</TableCell>
                  <TableCell>Remark</TableCell>
                  <TableCell>Duration</TableCell>
                  <TableCell>Status</TableCell>
                  <TableCell align="center">Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {notifications.length > 0 ? (
                  notifications.map((n) => (
                    <TableRow key={n.id} hover sx={{ '&:last-child td': { border: 0 } }}>
                      <TableCell><Typography fontWeight="bold">{n.title}</Typography></TableCell>
                      <TableCell><Typography variant="body2" color="textSecondary" noWrap sx={{ maxWidth: '300px' }}>{n.remark}</Typography></TableCell>
                      <TableCell><Chip label={`${n.duration} min`} size="small" variant="outlined" color="primary" /></TableCell>
                      <TableCell><Chip label={n.status || 'inactive'} color={n.status === 'active' ? 'success' : 'default'} size="small" /></TableCell>
                      <TableCell align="center">
                        <IconButton onClick={() => handleEdit(n)} color="secondary" size="small"><Edit /></IconButton>
                        <IconButton onClick={() => handleDeleteClick(n)} color="error" size="small"><Delete /></IconButton>
                      </TableCell>
                    </TableRow>
                  ))
                ) : (
                  <TableRow>
                    <TableCell colSpan={5} align="center">
                      <Typography p={3}>No notifications found.</Typography>
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </TableContainer>
        )}
      </Paper>

      <Dialog open={deleteDialogOpen} onClose={() => setDeleteDialogOpen(false)}>
        <DialogTitle>Confirm Deletion</DialogTitle>
        <DialogContent><Typography>Are you sure you want to delete this notification: "{notificationToDelete?.title}"?</Typography></DialogContent>
        <DialogActions>
          <Button onClick={() => setDeleteDialogOpen(false)}>Cancel</Button>
          <Button onClick={handleDelete} color="error" variant="contained" disabled={loading.delete} startIcon={loading.delete ? <CircularProgress size={20} /> : <Delete />}>Delete</Button>
        </DialogActions>
      </Dialog>
      <Snackbar open={snackbar.open} autoHideDuration={6000} onClose={() => setSnackbar(p=>({...p, open: false}))} anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}>
        <Alert onClose={() => setSnackbar(p=>({...p, open: false}))} severity={snackbar.severity} sx={{ width: '100%' }}>{snackbar.message}</Alert>
      </Snackbar>
    </Box>
  );
};

export default NotificationPage;