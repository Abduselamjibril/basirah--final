// src/scenes/dashboard/index.jsx

// --- IMPORTS WERE MISSING - THEY ARE NOW RESTORED ---
import React, { useEffect, useState } from 'react';
import { Box, Typography, useTheme, Grid, CircularProgress } from "@mui/material";
import Header from "../../components/Header";
import StatBox from "../../components/StatBox";
import apiClient from '../../api/axiosConfig';
import { tokens } from "../../theme";

// Import new icons for the stat boxes
import PersonAddIcon from "@mui/icons-material/PersonAdd";
import SchoolIcon from '@mui/icons-material/School';
import MenuBookIcon from '@mui/icons-material/MenuBook';
import AutoStoriesIcon from '@mui/icons-material/AutoStories';
import RateReviewIcon from '@mui/icons-material/RateReview';
import TravelExploreIcon from '@mui/icons-material/TravelExplore';
// --- END OF RESTORED IMPORTS ---


const Dashboard = () => {
  const theme = useTheme();
  const colors = tokens(theme.palette.mode);
  
  const [counts, setCounts] = useState({
    users: 0,
    courses: 0,
    surahs: 0,
    stories: 0,
    commentaries: 0,
    deeperLooks: 0,
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const fetchDashboardStats = async () => {
      setLoading(true);
      setError('');
      try {
        // Call the new, single, admin-only endpoint
        const response = await apiClient.get('/admin/stats');
        setCounts(response.data);
      } catch (err) {
        console.error('Failed to fetch dashboard counts:', err);
        setError('Could not load dashboard data. Please try again later.');
      } finally {
        setLoading(false);
      }
    };

    fetchDashboardStats();
  }, []);

  const statBoxData = [
    { title: "Total Users", count: counts.users, icon: <PersonAddIcon sx={{ color: colors.greenAccent[500], fontSize: "32px" }} /> },
    { title: "Total Courses", count: counts.courses, icon: <SchoolIcon sx={{ color: colors.greenAccent[500], fontSize: "32px" }} /> },
    { title: "Total Surahs", count: counts.surahs, icon: <MenuBookIcon sx={{ color: colors.greenAccent[500], fontSize: "32px" }} /> },
    { title: "Total Stories", count: counts.stories, icon: <AutoStoriesIcon sx={{ color: colors.greenAccent[500], fontSize: "32px" }} /> },
    { title: "Total Commentaries", count: counts.commentaries, icon: <RateReviewIcon sx={{ color: colors.greenAccent[500], fontSize: "32px" }} /> },
    { title: "Total Deeper Looks", count: counts.deeperLooks, icon: <TravelExploreIcon sx={{ color: colors.greenAccent[500], fontSize: "32px" }} /> },
  ];

  return (
    <Box m="20px">
      <Header title="DASHBOARD" subtitle="Welcome to your dashboard" />

      {loading ? (
        <Box display="flex" justifyContent="center" alignItems="center" height="50vh">
          <CircularProgress color="secondary" />
        </Box>
      ) : error ? (
        <Typography color="error">{error}</Typography>
      ) : (
        <Grid container spacing={3}>
          {statBoxData.map((stat, index) => (
            <Grid item xs={12} sm={6} md={4} key={index}>
              <Box
                backgroundColor={colors.primary[400]} // Using a theme color for consistency
                p="20px"
                borderRadius="12px"
                boxShadow={3}
              >
                <StatBox
                  title={String(stat.count)}
                  subtitle={stat.title}
                  progress="1" 
                  increase=""
                  icon={stat.icon}
                />
              </Box>
            </Grid>
          ))}
        </Grid>
      )}
    </Box>
  );
};

export default Dashboard;