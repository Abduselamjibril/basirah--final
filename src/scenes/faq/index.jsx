// src/scenes/faq/index.jsx
import React, { useState, useEffect, useCallback } from 'react';
import apiClient from '../../api/axiosConfig';
import {
  Box, Button, TextField, Typography, Paper, IconButton, Alert,
  Dialog, DialogTitle, DialogContent, DialogActions,
  CircularProgress, Accordion, AccordionSummary, AccordionDetails, useTheme,
  Grid, Snackbar
} from '@mui/material';
import { 
  Edit, Delete, HelpOutline, Add, Check, Close, ExpandMore, QuestionAnswer 
} from '@mui/icons-material';
import Header from '../../components/Header';
import { tokens } from '../../theme'; // Assuming you use this for colors

const FAQPage = () => {
  const theme = useTheme();
  const [faqs, setFaqs] = useState([]);
  const [formData, setFormData] = useState({ question: '', answer: '' });
  const [editId, setEditId] = useState(null);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'info' });
  const [loading, setLoading] = useState({ page: true, submit: false, delete: false });
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [faqToDelete, setFaqToDelete] = useState(null);
  const [expanded, setExpanded] = useState(false);

  const showSnackbar = useCallback((message, severity = 'info') => {
    setSnackbar({ open: true, message, severity });
  }, []);

  const fetchFaqs = useCallback(async () => {
    setLoading(p => ({ ...p, page: true }));
    try {
      const response = await apiClient.get('/faqs');
      // --- THIS IS THE FIX ---
      // Your public route returns a direct array, not an object with a `data` key.
      // We use response.data directly to get the array of FAQs.
      setFaqs(response.data || []); 
    } catch (err) {
      showSnackbar('Failed to fetch FAQs', 'error');
      console.error("Fetch FAQs error:", err);
    } finally {
      setLoading(p => ({ ...p, page: false }));
    }
  }, [showSnackbar]);

  useEffect(() => {
    fetchFaqs();
  }, [fetchFaqs]);

  const handleChange = (e) => {
    setFormData(p => ({ ...p, [e.target.name]: e.target.value }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!formData.question.trim() || !formData.answer.trim()) {
      showSnackbar('Both question and answer are required', 'error');
      return;
    }
    setLoading(p => ({ ...p, submit: true }));
    
    // Using FormData for PUT is tricky, a plain object is better if not uploading files.
    // However, Laravel can handle a PUT with a JSON body from Axios perfectly.
    const method = editId ? 'put' : 'post';
    const url = editId ? `/admin/faqs/${editId}` : '/admin/faqs';

    try {
      await apiClient[method](url, formData);
      showSnackbar(editId ? 'FAQ updated successfully!' : 'FAQ created successfully!', 'success');
      resetForm();
      fetchFaqs(); // Refresh the list
    } catch (err) {
      showSnackbar(err.response?.data?.message || 'Failed to submit FAQ', 'error');
      console.error("Submit FAQ error:", err);
    } finally {
      setLoading(p => ({ ...p, submit: false }));
    }
  };

  const handleEdit = (faq) => {
    setFormData({ question: faq.question, answer: faq.answer });
    setEditId(faq.id);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleDeleteClick = (faq) => {
    setFaqToDelete(faq);
    setDeleteDialogOpen(true);
  };

  const handleDelete = async () => {
    if (!faqToDelete) return;
    setLoading(p => ({ ...p, delete: true }));
    try {
      await apiClient.delete(`/admin/faqs/${faqToDelete.id}`);
      showSnackbar('FAQ deleted successfully!', 'success');
      fetchFaqs(); // Refresh the list
    } catch (err) {
      showSnackbar('Failed to delete FAQ', 'error');
      console.error("Delete FAQ error:", err);
    } finally {
      setLoading(p => ({ ...p, delete: false }));
      setDeleteDialogOpen(false);
      setFaqToDelete(null);
    }
  };

  const resetForm = () => {
    setFormData({ question: '', answer: '' });
    setEditId(null);
  };

  return (
    <Box m="20px">
      <Header title="FAQ MANAGEMENT" subtitle="Manage Frequently Asked Questions" />

      <Paper sx={{ p: { xs: 2, md: 4 }, mb: 4, borderRadius: '12px' }}>
        <Typography variant="h5" sx={{ mb: 3, display: 'flex', alignItems: 'center', gap: 1 }}>
          <HelpOutline color="secondary" />
          {editId ? 'Update FAQ' : 'Create New FAQ'}
        </Typography>
        <form onSubmit={handleSubmit}>
          <Grid container spacing={2}>
            <Grid item xs={12}>
              <TextField name="question" label="Question" value={formData.question} onChange={handleChange} fullWidth required variant="filled" InputProps={{ startAdornment: (<QuestionAnswer color="action" sx={{ mr: 1 }} />) }} />
            </Grid>
            <Grid item xs={12}>
              <TextField name="answer" label="Answer" value={formData.answer} onChange={handleChange} fullWidth multiline rows={4} required variant="filled" />
            </Grid>
          </Grid>
          <Box display="flex" justifyContent="flex-end" mt={3} gap={2}>
            {editId && <Button variant="outlined" color="inherit" onClick={resetForm} startIcon={<Close />}>Cancel Edit</Button>}
            <Button variant="contained" color="secondary" type="submit" disabled={loading.submit} startIcon={loading.submit ? <CircularProgress size={20} /> : <Check />}>
              {editId ? 'Update FAQ' : 'Create FAQ'}
            </Button>
          </Box>
        </form>
      </Paper>

      <Box>
        <Typography variant="h5" sx={{ mb: 2, display: 'flex', alignItems: 'center', gap: 1 }}>
            Published FAQs
        </Typography>
        {loading.page ? (
          <Box display="flex" justifyContent="center" py={4}><CircularProgress color="secondary" /></Box>
        ) : faqs.length > 0 ? (
          faqs.map((faq) => (
            <Accordion key={faq.id} expanded={expanded === faq.id} onChange={() => setExpanded(expanded === faq.id ? false : faq.id)} sx={{ mb: 1, '&:before': { display: 'none' }, borderRadius: '8px', overflow: 'hidden' }}>
              <AccordionSummary expandIcon={<ExpandMore />} sx={{ '& .MuiAccordionSummary-content': { justifyContent: 'space-between', alignItems: 'center' } }}>
                <Typography variant="h6">{faq.question}</Typography>
                <Box onClick={(e) => e.stopPropagation()}>
                  <IconButton onClick={() => handleEdit(faq)} color="secondary" size="small"><Edit /></IconButton>
                  <IconButton onClick={() => handleDeleteClick(faq)} color="error" size="small"><Delete /></IconButton>
                </Box>
              </AccordionSummary>
              <AccordionDetails sx={{ backgroundColor: theme.palette.action.hover }}>
                <Typography sx={{ whiteSpace: 'pre-wrap' }}>{faq.answer}</Typography>
              </AccordionDetails>
            </Accordion>
          ))
        ) : (
            <Typography sx={{ textAlign: 'center', p: 4, color: 'text.secondary' }}>No FAQs have been added yet.</Typography>
        )}
      </Box>

      <Dialog open={deleteDialogOpen} onClose={() => setDeleteDialogOpen(false)}>
        <DialogTitle>Confirm Deletion</DialogTitle>
        <DialogContent><Typography>Are you sure you want to delete this FAQ: "{faqToDelete?.question}"?</Typography></DialogContent>
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

export default FAQPage;