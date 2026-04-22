import React, { useState, useEffect } from 'react';
import apiClient from '../../api/axiosConfig';
import {
  Box, Typography, useTheme, CircularProgress, Snackbar, Alert,
  Paper, IconButton, Divider, Tooltip, Avatar
} from '@mui/material';
import DeleteIcon from '@mui/icons-material/Delete';
import Header from '../../components/Header';
import { tokens } from '../../theme';
import { format } from 'date-fns';

const Questions = () => {
  const theme = useTheme();
  const colors = tokens(theme.palette.mode);

  const [questions, setQuestions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'info' });

  const fetchData = async () => {
    try {
      const response = await apiClient.get('/admin/questions');
      setQuestions(response.data || []);
    } catch (error) {
      console.error('Failed to fetch questions:', error);
      setSnackbar({ open: true, message: 'Failed to fetch questions.', severity: 'error' });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  const handleDelete = async (id) => {
    if (window.confirm('Are you sure you want to delete this question?')) {
      try {
        await apiClient.delete(`/admin/questions/${id}`);
        setSnackbar({ open: true, message: 'Question deleted successfully!', severity: 'success' });
        fetchData();
      } catch (error) {
        console.error('Failed to delete question:', error);
        setSnackbar({ open: true, message: 'Failed to delete question.', severity: 'error' });
      }
    }
  };

  const handleCloseSnackbar = () => setSnackbar({ ...snackbar, open: false });

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="80vh">
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box m="20px">
      <Header title="STUDENT QUESTIONS" subtitle="Manage questions submitted by students from the mobile app" />

      <Box mt="20px">
        {questions.length > 0 ? (
          questions.map((q) => (
            <Paper
              key={q.id}
              sx={{
                p: 3,
                mb: 2,
                backgroundColor: theme.palette.background.paper,
                borderRadius: '12px',
                boxShadow: '0 4px 12px rgba(0,0,0,0.05)',
                position: 'relative',
                '&:hover': {
                  boxShadow: '0 6px 16px rgba(0,0,0,0.1)',
                },
              }}
            >
              <Box display="flex" justifyContent="space-between" alignItems="flex-start">
                <Box display="flex" alignItems="center" gap={2}>
                  <Avatar sx={{ bgcolor: colors.greenAccent[500], width: 40, height: 40 }}>
                    {(q.user?.first_name?.[0] || 'U').toUpperCase()}
                  </Avatar>
                  <Box>
                    <Typography variant="h5" fontWeight="600" color={colors.grey[100]}>
                      {q.user ? `${q.user.first_name} ${q.user.last_name}` : 'Unknown User'}
                    </Typography>
                    <Typography variant="body2" color={colors.grey[400]}>
                      {format(new Date(q.created_at), 'MMMM dd, yyyy - hh:mm a')}
                    </Typography>
                  </Box>
                </Box>
                <Tooltip title="Delete Question">
                  <IconButton onClick={() => handleDelete(q.id)} color="error">
                    <DeleteIcon />
                  </IconButton>
                </Tooltip>
              </Box>

              <Divider sx={{ my: 2 }} />

              <Box sx={{ pl: '56px' }}>
                <Typography variant="body1" color={colors.grey[100]} sx={{ lineHeight: 1.6, whiteSpace: 'pre-wrap' }}>
                  {q.question_text}
                </Typography>
              </Box>
            </Paper>
          ))
        ) : (
          <Box display="flex" flexDirection="column" alignItems="center" justifyContent="center" p={10}>
            <Typography variant="h4" color={colors.grey[400]}>No questions found.</Typography>
          </Box>
        )}
      </Box>

      <Snackbar
        open={snackbar.open}
        autoHideDuration={6000}
        onClose={handleCloseSnackbar}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
      >
        <Alert onClose={handleCloseSnackbar} severity={snackbar.severity} sx={{ width: '100%' }}>
          {snackbar.message}
        </Alert>
      </Snackbar>
    </Box>
  );
};

export default Questions;
