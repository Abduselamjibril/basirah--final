// Assuming path: src/scenes/content_management/index.js
import React, { useEffect, useState } from 'react';
import { Box, useTheme, Typography, Paper, CircularProgress, Button } from '@mui/material';
import { DataGrid } from '@mui/x-data-grid';
import Header from '../../components/Header';
import apiClient from '../../api/axiosConfig'; // Use the consistent API client
import { tokens } from '../../theme';

const ContentManagement = () => {
  const theme = useTheme();
  const colors = tokens(theme.palette.mode);
  const [videos, setVideos] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Define the columns for the DataGrid
  const columns = [
    {
      field: 'thumbnail',
      headerName: 'Thumbnail',
      width: 150,
      renderCell: (params) => (
        <Box
          component="img"
          src={params.value}
          alt={params.row.title}
          sx={{
            width: '100%',
            height: 'auto',
            maxHeight: '60px',
            objectFit: 'cover',
            borderRadius: '4px',
            my: '5px'
          }}
        />
      ),
    },
    { field: 'title', headerName: 'Title', flex: 1, minWidth: 250 },
    { field: 'description', headerName: 'Description', flex: 2, minWidth: 350 },
    {
      field: 'publishedAt',
      headerName: 'Published At',
      width: 200,
      valueGetter: (params) => new Date(params.value).toLocaleString(),
    },
    {
      field: 'videoUrl',
      headerName: 'Video Link',
      width: 150,
      renderCell: (params) => (
        <Button
          href={params.value}
          target="_blank"
          rel="noopener noreferrer"
          variant="contained"
          color="secondary"
          size="small"
        >
          Watch
        </Button>
      ),
    },
  ];

  useEffect(() => {
    const fetchVideos = async () => {
      setLoading(true);
      setError('');
      try {
        const response = await apiClient.get('/latest-videos');
        // Ensure the response has the 'videos' array and map it
        const videoData = (response.data.videos || []).map((video) => ({
          // Use a unique ID from the video data if available, otherwise fallback to a generated ID
          id: video.videoId || video.id || Math.random().toString(36).substr(2, 9),
          title: video.title,
          description: video.description,
          thumbnail: video.thumbnail,
          videoUrl: video.videoUrl,
          publishedAt: video.publishedAt,
        }));
        setVideos(videoData);
      } catch (err) {
        console.error('Error fetching videos:', err);
        setError('Failed to fetch video content. Please try again later.');
      } finally {
        setLoading(false);
      }
    };
    fetchVideos();
  }, []);

  return (
    <Box m="20px">
      <Header title="CONTENT MANAGEMENT" subtitle="Latest video content from YouTube Channel" />
      
      <Paper
        sx={{
          m: "40px 0 0 0",
          height: "75vh",
          backgroundColor: theme.palette.background.paper,
          borderRadius: '12px',
          overflow: 'hidden',
          "& .MuiDataGrid-root": {
            border: "none",
          },
          "& .MuiDataGrid-cell": {
            borderBottom: `1px solid ${theme.palette.divider}`,
          },
          "& .MuiDataGrid-columnHeaders": {
            backgroundColor: colors.greenAccent[700],
            borderBottom: "none",
            color: colors.grey[100],
          },
          "& .MuiDataGrid-virtualScroller": {
            backgroundColor: theme.palette.background.paper,
          },
          "& .MuiDataGrid-footerContainer": {
            borderTop: "none",
            backgroundColor: colors.greenAccent[700],
          },
          "& .MuiCheckbox-root": {
            color: `${colors.greenAccent[200]} !important`,
          },
        }}
      >
        {loading ? (
          <Box display="flex" justifyContent="center" alignItems="center" height="100%">
            <CircularProgress color="secondary" />
          </Box>
        ) : error ? (
          <Box display="flex" justifyContent="center" alignItems="center" height="100%">
            <Typography color="error">{error}</Typography>
          </Box>
        ) : (
          <DataGrid
            rows={videos}
            columns={columns}
            pageSize={10}
            rowsPerPageOptions={[10]}
            disableSelectionOnClick
            rowHeight={70} // Adjust row height to accommodate thumbnails
          />
        )}
      </Paper>
    </Box>
  );
};

export default ContentManagement;