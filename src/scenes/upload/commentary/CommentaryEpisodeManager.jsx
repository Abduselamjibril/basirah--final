import React, { useEffect, useState, useRef, useCallback } from 'react';
import {
  Box, Button, TextField, Typography, Card, CardContent, CardMedia, IconButton,
  CircularProgress, Grid, Paper, Chip, Dialog, DialogTitle, DialogContent,
  DialogActions, Snackbar, Alert, Tooltip, useTheme, Switch, FormControlLabel
} from '@mui/material';
import {
  Delete as DeleteIcon, Lock, LockOpen, Edit, CloudUpload, Cancel,
  CheckCircle, Title as TitleIcon, Add, YouTube as YouTubeIcon
} from '@mui/icons-material';
import { useParams, useNavigate } from 'react-router-dom';
import apiClient from '../../../api/axiosConfig';
import { styled } from '@mui/material/styles';
import { motion } from 'framer-motion';
import Header from '../../../components/Header';

const StyledCard = styled(Card)(({ theme }) => ({
  transition: 'transform 0.3s, box-shadow 0.3s',
  display: 'flex',
  flexDirection: 'column',
  height: '100%',
  '&:hover': {
    transform: 'translateY(-5px)',
    boxShadow: theme.shadows[8]
  }
}));

const getYouTubeEmbedUrl = (url) => {
    if (!url) return null;
    const regex = /(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})/;
    const match = url.match(regex);
    return match && match[1] ? `https://www.youtube.com/embed/${match[1]}` : null;
};

const CommentaryEpisodeManager = () => {
  const theme = useTheme();
  const { commentaryId } = useParams();
  const navigate = useNavigate();

  const [parentCommentary, setParentCommentary] = useState(null);
  const [episodes, setEpisodes] = useState([]);
  const [formData, setFormData] = useState({ title: '', video: null, audio: null, youtube_link: '' });
  const [isYouTube, setIsYouTube] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [preview, setPreview] = useState({ video: null, audio: null });
  const [openDeleteDialog, setOpenDeleteDialog] = useState(false);
  const [deleteId, setDeleteId] = useState(null);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'success' });
  const [loading, setLoading] = useState({ submit: false, page: true, delete: false, lock: null });

  const videoInputRef = useRef();
  const audioInputRef = useRef();

  const showSnackbar = useCallback((message, severity = 'success') => {
    setSnackbar({ open: true, message, severity });
  }, []);

  const fetchEpisodesAndParent = useCallback(async () => {
    setLoading(prev => ({ ...prev, page: true }));
    try {
      const [episodesResponse, parentResponse] = await Promise.all([
        apiClient.get(`/commentaries/${commentaryId}/episodes`),
        apiClient.get(`/commentaries/${commentaryId}`)
      ]);
      setEpisodes(Array.isArray(episodesResponse.data.data) ? episodesResponse.data.data : []);
      setParentCommentary(parentResponse.data.data);
    } catch (error) {
      showSnackbar('Failed to fetch commentary data. It may not exist.', 'error');
      navigate('/upload/commentaries');
    } finally {
      setLoading(prev => ({ ...prev, page: false }));
    }
  }, [commentaryId, showSnackbar, navigate]);

  useEffect(() => {
    fetchEpisodesAndParent();
  }, [fetchEpisodesAndParent]);

  const handleChange = (e) => setFormData(p => ({ ...p, [e.target.name]: e.target.value }));

  const handleFileChange = (e, fileType) => {
    const file = e.target.files[0];
    if (file) {
      if (fileType === 'video') {
        setFormData(p => ({ ...p, video: file, youtube_link: '' }));
        setPreview(p => ({ ...p, video: URL.createObjectURL(file) }));
        setIsYouTube(false);
      } else {
        setFormData(p => ({ ...p, audio: file }));
        setPreview(p => ({ ...p, audio: URL.createObjectURL(file) }));
      }
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(p => ({ ...p, submit: true }));
    const data = new FormData();
    data.append('title', formData.title);
    if (formData.youtube_link) {
      data.append('youtube_link', formData.youtube_link);
    } else if (formData.video instanceof File) {
      data.append('video', formData.video);
    }
    if (formData.audio instanceof File) data.append('audio', formData.audio);

    try {
      if (editingId) {
        // UPDATED: Use apiClient.put for updates
        const response = await apiClient.post(`/admin/commentaries/${commentaryId}/episodes/${editingId}`, data, {
            headers: { 'Content-Type': 'multipart/form-data' },
        });
        showSnackbar('Episode updated!', 'success');
        // UPDATED: Efficiently update local state
        const updatedEpisode = response.data.data;
        setEpisodes(prev => prev.map(ep => ep.id === updatedEpisode.id ? updatedEpisode : ep));
      } else {
        // Create (POST) logic is unchanged, but now with efficient state update
        const response = await apiClient.post(`/admin/commentaries/${commentaryId}/episodes`, data);
        showSnackbar('Episode created!', 'success');
        // UPDATED: Efficiently update local state
        const newEpisode = response.data.data;
        setEpisodes(prev => [newEpisode, ...prev]);
      }
      resetForm();
    } catch (error) {
        const errorMessage = error.response?.data?.errors 
            ? Object.values(error.response.data.errors).join(' ') 
            : error.response?.data?.message || 'Operation failed';
        showSnackbar(errorMessage, 'error');
    } finally {
        setLoading(p => ({ ...p, submit: false }));
    }
  };

  const handleEdit = (episode) => {
    setEditingId(episode.id);
    setFormData({ title: episode.title || '', video: null, audio: null, youtube_link: episode.youtube_link || '' });
    setIsYouTube(!!episode.youtube_link);
    setPreview({ video: episode.video, audio: episode.audio });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };
  
  const confirmDelete = (id) => { setDeleteId(id); setOpenDeleteDialog(true) };

  const handleDelete = async () => {
    setLoading(p => ({ ...p, delete: true }));
    try {
      await apiClient.delete(`/admin/commentaries/${commentaryId}/episodes/${deleteId}`);
      showSnackbar('Episode deleted!', 'success');
      // UPDATED: Efficiently update local state
      setEpisodes(prev => prev.filter(ep => ep.id !== deleteId));
      setOpenDeleteDialog(false);
    } catch (error) {
      showSnackbar(error.response?.data?.message || 'Deletion failed', 'error');
    } finally {
      setLoading(p => ({ ...p, delete: false }));
    }
  };

  const toggleLock = async (episode) => {
    if (parentCommentary?.is_premium && !episode.is_locked) {
      showSnackbar("Unlock the parent Commentary to manage this episode's lock status.", "info");
      return;
    }

    setLoading(p => ({ ...p, lock: episode.id }));
    const endpoint = episode.is_locked ? 'unlock' : 'lock';
    try {
      const response = await apiClient.post(`/admin/commentaries/${commentaryId}/episodes/${episode.id}/${endpoint}`);
      const updatedEpisode = response.data.data;
      
      setEpisodes(prevEpisodes => 
        prevEpisodes.map(ep => 
          ep.id === updatedEpisode.id ? updatedEpisode : ep
        )
      );
      showSnackbar(`Episode ${endpoint}ed!`, 'success');
    } catch (error) {
      showSnackbar(error.response?.data?.message || 'Operation failed', 'error');
    } finally {
      setLoading(p => ({ ...p, lock: null }));
    }
  };

  const resetForm = () => {
    setFormData({ title: '', video: null, audio: null, youtube_link: '' });
    setEditingId(null);
    setPreview({ video: null, audio: null });
    setIsYouTube(false);
    if (videoInputRef.current) videoInputRef.current.value = null;
    if (audioInputRef.current) audioInputRef.current.value = null;
  };
  
  const isFormValid = formData.title && (isYouTube ? formData.youtube_link : (formData.video || preview.video));

  if (loading.page || !parentCommentary) {
    return (
        <Box m="20px">
            <Header title="LOADING..." subtitle="Fetching commentary and episode data..." />
            <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}><CircularProgress color="secondary" /></Box>
        </Box>
    );
  }

  return (
    <Box m="20px">
      <Header title={`EPISODES: ${parentCommentary.title}`} subtitle={`Manage episodes for this commentary. Parent is currently ${parentCommentary.is_premium ? 'PREMIUM' : 'FREE'}.`} />

      <Paper elevation={3} sx={{ p: { xs: 2, md: 4 }, mb: 4, borderRadius: '12px' }}>
        <Typography variant="h5" sx={{ mb: 3, display: 'flex', alignItems: 'center', gap: 1 }}>
          {editingId ? <Edit color="secondary" /> : <Add color="secondary" />}
          {editingId ? 'Edit Episode' : 'Create New Episode'}
        </Typography>

        <form onSubmit={handleSubmit}>
          <Grid container spacing={4}>
            <Grid item xs={12} md={6}>
              <TextField fullWidth label="Episode Title" name="title" value={formData.title} onChange={handleChange} required variant="filled" InputProps={{ startAdornment: (<TitleIcon color="action" sx={{ mr: 1 }} />) }} />
              <FormControlLabel control={<Switch checked={isYouTube} onChange={(e) => { setIsYouTube(e.target.checked); setFormData(p=>({...p, video: null})); setPreview(p=>({...p, video: null})); }} />} label="Use YouTube Link" sx={{ mt: 2 }} />
              {isYouTube ? (
                <TextField fullWidth sx={{ mt: 1 }} label="YouTube Link" name="youtube_link" value={formData.youtube_link} onChange={handleChange} required variant="filled" type="url" InputProps={{ startAdornment: (<YouTubeIcon color="action" sx={{ mr: 1 }} />) }} />
              ) : (
                <Box sx={{ mt: 1, p: 2, border: '1px dashed', borderColor: 'divider', borderRadius: '8px' }}>
                  {preview.video && <video key={preview.video} src={preview.video} controls style={{ width: '100%', borderRadius: '4px' }} />}
                  <Button fullWidth component="label" sx={{ mt: preview.video ? 2 : 0 }} variant="outlined" color="inherit" startIcon={<CloudUpload />}> {preview.video ? "Change Video" : "Upload Video"}
                    <input ref={videoInputRef} type="file" hidden onChange={(e) => handleFileChange(e, 'video')} accept="video/*" />
                  </Button>
                </Box>
              )}
            </Grid>
            <Grid item xs={12} md={6}>
                <Box sx={{ p: 2, border: '1px dashed', borderColor: 'divider', borderRadius: '8px', height: '100%', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
                  <Typography variant="h6" sx={{ mb: 2, textAlign: 'center', color: 'text.secondary' }}>Optional Audio</Typography>
                  {preview.audio && <audio key={preview.audio} src={preview.audio} controls style={{ width: '100%' }} />}
                  <Button fullWidth component="label" sx={{ mt: preview.audio ? 2 : 0 }} variant="outlined" color="inherit" startIcon={<CloudUpload />}> {preview.audio ? "Change Audio" : "Upload Audio"}
                    <input ref={audioInputRef} type="file" hidden onChange={(e) => handleFileChange(e, 'audio')} accept="audio/*" />
                  </Button>
                </Box>
            </Grid>
          </Grid>
          <Box sx={{ display: 'flex', justifyContent: 'flex-end', mt: 3, gap: 2 }}>
            {editingId && <Button variant="outlined" color="inherit" onClick={resetForm} startIcon={<Cancel />}>Cancel Edit</Button>}
            <Button type="submit" variant="contained" color="secondary" disabled={loading.submit || !isFormValid} startIcon={loading.submit ? <CircularProgress size={20} /> : <CheckCircle />}>
              {editingId ? 'Update Episode' : 'Create Episode'}
            </Button>
          </Box>
        </form>
      </Paper>

      <Grid container spacing={3}>
        {episodes.map((episode) => {
          const isIndividuallyLocked = parentCommentary.is_premium || episode.is_locked;
          const isLockControlDisabled = parentCommentary.is_premium;
          return (
            <Grid item xs={12} sm={6} md={4} key={episode.id}>
              <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}>
                <StyledCard>
                  <Box sx={{ position: 'relative' }}>
                    {isIndividuallyLocked && <Chip label="PREMIUM" color="warning" size="small" sx={{ position: 'absolute', top: 10, right: 10, zIndex: 1 }} />}
                    {getYouTubeEmbedUrl(episode.youtube_link) ? <Box sx={{ position: 'relative', paddingTop: '56.25%', backgroundColor: '#000' }}><iframe style={{ position: 'absolute', top: 0, left: 0, width: '100%', height: '100%' }} src={getYouTubeEmbedUrl(episode.youtube_link)} title={episode.title} frameBorder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowFullScreen /></Box>
                      : episode.video ? <CardMedia component="video" controls src={episode.video} sx={{ height: 200, backgroundColor: '#000' }} />
                      : <Box sx={{ height: 200, bgcolor: 'action.hover', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Typography color="text.secondary">No Video</Typography></Box>
                    }
                  </Box>
                  <CardContent sx={{ flexGrow: 1 }}>
                    <Tooltip title={episode.title}><Typography gutterBottom variant="h6" noWrap>{episode.title}</Typography></Tooltip>
                    {episode.audio && <Box sx={{ mt: 1 }}><audio src={episode.audio} controls style={{ width: '100%' }} /></Box>}
                  </CardContent>
                  <Box sx={{ display: 'flex', justifyContent: 'space-around', p: 1, borderTop: 1, borderColor: 'divider' }}>
                    <Tooltip title={isLockControlDisabled ? "Unlock parent to manage" : (episode.is_locked ? 'Make Free' : 'Make Premium')}><span><IconButton onClick={() => toggleLock(episode)} color={episode.is_locked ? 'warning' : 'default'} disabled={!!loading.lock || isLockControlDisabled}>{loading.lock === episode.id ? <CircularProgress size={24} /> : (episode.is_locked ? <Lock /> : <LockOpen />)}</IconButton></span></Tooltip>
                    <Tooltip title="Edit"><IconButton onClick={() => handleEdit(episode)} color="secondary"><Edit /></IconButton></Tooltip>
                    <Tooltip title="Delete"><IconButton onClick={() => confirmDelete(episode.id)} color="error"><DeleteIcon /></IconButton></Tooltip>
                  </Box>
                </StyledCard>
              </motion.div>
            </Grid>
        )})}
      </Grid>

      <Dialog open={openDeleteDialog} onClose={() => setOpenDeleteDialog(false)}>
        <DialogTitle>Confirm Deletion</DialogTitle>
        <DialogContent><Typography>Are you sure you want to delete this episode?</Typography></DialogContent>
        <DialogActions>
          <Button onClick={() => setOpenDeleteDialog(false)}>Cancel</Button>
          <Button onClick={handleDelete} color="error" variant="contained" disabled={loading.delete} startIcon={loading.delete ? <CircularProgress size={20} /> : <DeleteIcon />}>Delete</Button>
        </DialogActions>
      </Dialog>
      <Snackbar open={snackbar.open} autoHideDuration={6000} onClose={() => setSnackbar(p => ({...p, open: false}))} anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}>
        <Alert onClose={() => setSnackbar(p => ({...p, open: false}))} severity={snackbar.severity} sx={{ width: '100%' }}>{snackbar.message}</Alert>
      </Snackbar>
    </Box>
  );
};

export default CommentaryEpisodeManager;