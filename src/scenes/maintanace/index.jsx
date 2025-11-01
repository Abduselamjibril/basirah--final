import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { 
  Container, 
  Card, 
  CardContent, 
  Typography, 
  Box, 
  FormControlLabel, 
  Switch, 
  Snackbar, 
  CircularProgress,
  Alert,
  Avatar,
  useTheme,
  Fade
} from '@mui/material';
import { 
  Construction, 
  CheckCircle, 
  Warning, 
  Settings 
} from '@mui/icons-material';

const MAINTENANCE_API_URL = 'https://admin.basirahtv.com/api/maintenance';

const MaintenanceMode = () => {
  const theme = useTheme();
  const [isMaintenance, setIsMaintenance] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Fetch current maintenance status from the API
  useEffect(() => {
    const fetchMaintenanceStatus = async () => {
      try {
        const response = await axios.get(MAINTENANCE_API_URL);
        setIsMaintenance(response.data.isMaintenance);
      } catch (error) {
        console.error('Failed to fetch maintenance status', error);
        setError('Failed to fetch maintenance status. Please try again.');
      } finally {
        setLoading(false);
      }
    };
    fetchMaintenanceStatus();
  }, []);

  // Toggle maintenance mode
  const handleToggle = async (event) => {
    const newStatus = event.target.checked;
    setLoading(true);
    setError('');
    setSuccess('');
    
    try {
      await axios.post(MAINTENANCE_API_URL, { isMaintenance: newStatus });
      setIsMaintenance(newStatus);
      setSuccess(`Maintenance mode ${newStatus ? 'enabled' : 'disabled'} successfully!`);
    } catch (error) {
      console.error('Failed to update maintenance status', error);
      setError('Failed to update maintenance status. Please try again.');
      setIsMaintenance(!newStatus); // Revert the toggle
    } finally {
      setLoading(false);
    }
  };

  return (
    <Container maxWidth="sm" sx={{ mt: 5 }}>
      <Fade in={true} timeout={500}>
        <Card sx={{ 
          boxShadow: 6, 
          borderRadius: 3, 
          overflow: 'visible',
          borderLeft: `6px solid ${isMaintenance ? theme.palette.error.main : theme.palette.success.main}`,
          transition: 'all 0.3s ease',
          '&:hover': {
            boxShadow: 8,
            transform: 'translateY(-2px)'
          }
        }}>
          <CardContent sx={{ p: 4 }}>
            <Box display="flex" flexDirection="column" alignItems="center">
              {/* Status Avatar */}
              <Avatar sx={{ 
                bgcolor: isMaintenance ? theme.palette.error.main : theme.palette.success.main,
                width: 80, 
                height: 80,
                mb: 3,
                boxShadow: 3
              }}>
                {isMaintenance ? (
                  <Construction sx={{ fontSize: 40 }} />
                ) : (
                  <CheckCircle sx={{ fontSize: 40 }} />
                )}
              </Avatar>

              {/* Title */}
              <Typography 
                variant="h4" 
                sx={{ 
                  fontWeight: 'bold', 
                  mb: 1,
                  color: isMaintenance ? theme.palette.error.main : theme.palette.success.main
                }}
              >
                {isMaintenance ? 'Maintenance Active' : 'System Normal'}
              </Typography>

              {/* Subtitle */}
              <Typography 
                variant="subtitle1" 
                color="textSecondary" 
                sx={{ mb: 3 }}
              >
                {isMaintenance 
                  ? 'The application is currently undergoing maintenance' 
                  : 'All systems are operational'}
              </Typography>

              {/* Toggle Switch */}
              {loading ? (
                <CircularProgress size={50} thickness={4} />
              ) : (
                <Box sx={{ 
                  display: 'flex', 
                  flexDirection: 'column', 
                  alignItems: 'center',
                  mt: 2
                }}>
                  <FormControlLabel
                    control={
                      <Switch
                        checked={isMaintenance}
                        onChange={handleToggle}
                        disabled={loading}
                        size="large"
                        sx={{
                          width: 72,
                          height: 42,
                          padding: 0,
                          '& .MuiSwitch-switchBase': {
                            padding: 1,
                            '&.Mui-checked': {
                              transform: 'translateX(30px)',
                              color: '#fff',
                              '& + .MuiSwitch-track': {
                                opacity: 1,
                                backgroundColor: theme.palette.error.main,
                              },
                            },
                          },
                          '& .MuiSwitch-thumb': {
                            width: 18,
                            height: 18,
                            boxShadow: '0 2px 4px rgba(0,0,0,0.3)',
                          },
                          '& .MuiSwitch-track': {
                            borderRadius: 20,
                            backgroundColor: theme.palette.grey[400],
                            opacity: 1,
                          },
                        }}
                      />
                    }
                    label={
                      <Box sx={{ 
                        display: 'flex', 
                        alignItems: 'center',
                        mt: 1
                      }}>
                        <Settings sx={{ 
                          mr: 1, 
                          color: isMaintenance ? theme.palette.error.main : theme.palette.success.main 
                        }} />
                        <Typography 
                          variant="h6" 
                          sx={{ 
                            fontWeight: 'bold',
                            color: isMaintenance ? theme.palette.error.main : theme.palette.success.main
                          }}
                        >
                          {isMaintenance ? 'MAINTENANCE ON' : 'MAINTENANCE OFF'}
                        </Typography>
                      </Box>
                    }
                    labelPlacement="bottom"
                  />
                </Box>
              )}

              {/* Status Message */}
              <Typography 
                variant="body1" 
                sx={{ 
                  textAlign: 'center', 
                  mt: 3,
                  p: 2,
                  borderRadius: 1,
                  bgcolor: isMaintenance ? theme.palette.error.light : theme.palette.success.light,
                  color: isMaintenance ? theme.palette.error.dark : theme.palette.success.dark,
                  width: '100%'
                }}
              >
                {isMaintenance 
                  ? 'Users will see a maintenance page when accessing the application.' 
                  : 'All features are available to users.'}
              </Typography>
            </Box>
          </CardContent>
        </Card>
      </Fade>

      {/* Status Alerts */}
      <Snackbar 
        open={!!error} 
        autoHideDuration={6000} 
        onClose={() => setError('')}
        anchorOrigin={{ vertical: 'top', horizontal: 'center' }}
      >
        <Alert severity="error" icon={<Warning />}>
          {error}
        </Alert>
      </Snackbar>

      <Snackbar 
        open={!!success} 
        autoHideDuration={4000} 
        onClose={() => setSuccess('')}
        anchorOrigin={{ vertical: 'top', horizontal: 'center' }}
      >
        <Alert severity="success" icon={<CheckCircle />}>
          {success}
        </Alert>
      </Snackbar>
    </Container>
  );
};

export default MaintenanceMode;