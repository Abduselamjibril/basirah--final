// src/scenes/gift_purchases/index.js

import React, { useState, useEffect } from 'react';
import apiClient from '../../api/axiosConfig';
import {
  Box,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Typography,
  Button,
  Snackbar,
  Alert,
  CircularProgress,
  useTheme,
  Chip
} from '@mui/material';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import Header from '../../components/Header';
import { tokens } from '../../theme';
import { format } from 'date-fns';

const GiftPurchases = () => {
  const theme = useTheme();
  const colors = tokens(theme.palette.mode);

  const [purchases, setPurchases] = useState([]);
  const [loading, setLoading] = useState(true);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'info' });

  const fetchPurchases = async () => {
    setLoading(true);
    try {
      const response = await apiClient.get('/admin/gift-purchases');
      setPurchases(response.data || []);
    } catch (error) {
      console.error('Failed to fetch gift purchases:', error);
      setSnackbar({ open: true, message: 'Failed to fetch gift purchases.', severity: 'error' });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPurchases();
  }, []);

  const handleApprovePayment = async (purchaseId) => {
    try {
      await apiClient.post(`/admin/gift-purchases/${purchaseId}/approve-payment`);
      setSnackbar({ open: true, message: 'Payment approved! The gift pool is now active.', severity: 'success' });
      // Refresh the list to move the item from pending to active
      fetchPurchases(); 
    } catch (error) {
      console.error('Error approving payment:', error);
      setSnackbar({ open: true, message: 'Failed to approve payment.', severity: 'error' });
    }
  };

  const handleCloseSnackbar = () => setSnackbar({ ...snackbar, open: false });

  // Separate purchases into pending and active pools
  const pendingPurchases = purchases.filter(p => p.status === 'pending');
  const activePools = purchases.filter(p => p.status === 'approved' && p.quantity_remaining > 0);

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="80vh">
        <CircularProgress color="secondary" />
      </Box>
    );
  }

  return (
    <Box m="20px">
      <Header title="GIFT MANAGEMENT" subtitle="Approve gift payments and view active gift pools" />

      {/* Section for Pending Approvals */}
      <Paper sx={{ p: 3, mb: 4, borderRadius: '12px' }}>
        <Typography variant="h4" gutterBottom>Pending Payment Approvals</Typography>
        <TableContainer>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Gifter</TableCell>
                <TableCell>Plan</TableCell>
                <TableCell>Quantity</TableCell>
                <TableCell>Total Price (ETB)</TableCell>
                <TableCell>Transaction ID</TableCell>
                <TableCell>Date</TableCell>
                <TableCell align="center">Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {pendingPurchases.length > 0 ? (
                pendingPurchases.map((purchase) => (
                  <TableRow key={purchase.id}>
                    <TableCell>{`${purchase.gifter.first_name} ${purchase.gifter.last_name}`}</TableCell>
                    <TableCell>{purchase.plan_duration}</TableCell>
                    <TableCell>{purchase.quantity_purchased}</TableCell>
                    <TableCell>{purchase.total_price}</TableCell>
                    <TableCell>{purchase.transaction_id}</TableCell>
                    <TableCell>{format(new Date(purchase.created_at), 'MMM dd, yyyy')}</TableCell>
                    <TableCell align="center">
                      <Button
                        onClick={() => handleApprovePayment(purchase.id)}
                        variant="contained"
                        color="success"
                        startIcon={<CheckCircleIcon />}
                      >
                        Approve Payment
                      </Button>
                    </TableCell>
                  </TableRow>
                ))
              ) : (
                <TableRow><TableCell colSpan={7} align="center"><Typography p={2}>No pending gift payments.</Typography></TableCell></TableRow>
              )}
            </TableBody>
          </Table>
        </TableContainer>
      </Paper>

      {/* Section for Active Gift Pools */}
      <Paper sx={{ p: 3, borderRadius: '12px' }}>
        <Typography variant="h4" gutterBottom>Active Gift Pools</Typography>
        <TableContainer>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Gifter</TableCell>
                <TableCell>Plan</TableCell>
                <TableCell>Gifts Remaining</TableCell>
                <TableCell>Date Approved</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {activePools.length > 0 ? (
                activePools.map((pool) => (
                  <TableRow key={pool.id}>
                    <TableCell>{`${pool.gifter.first_name} ${pool.gifter.last_name}`}</TableCell>
                    <TableCell>{pool.plan_duration}</TableCell>
                    <TableCell>
                      <Chip label={pool.quantity_remaining} color="primary" />
                    </TableCell>
                    <TableCell>{format(new Date(pool.updated_at), 'MMM dd, yyyy')}</TableCell>
                  </TableRow>
                ))
              ) : (
                <TableRow><TableCell colSpan={4} align="center"><Typography p={2}>No active gift pools.</Typography></TableCell></TableRow>
              )}
            </TableBody>
          </Table>
        </TableContainer>
      </Paper>

      <Snackbar open={snackbar.open} autoHideDuration={6000} onClose={handleCloseSnackbar} anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}>
        <Alert onClose={handleCloseSnackbar} severity={snackbar.severity} sx={{ width: '100%' }}>
          {snackbar.message}
        </Alert>
      </Snackbar>
    </Box>
  );
};

export default GiftPurchases;