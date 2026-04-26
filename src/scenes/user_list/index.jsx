import React, { useState, useEffect } from 'react';
import apiClient from '../../api/axiosConfig';
import {
  Box, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Paper,
  InputBase, IconButton, Typography, Button, Snackbar, Alert, CircularProgress,
  useTheme, Tooltip,
  Menu, MenuItem, Modal, Select, FormControl, InputLabel
} from '@mui/material';
import SearchIcon from '@mui/icons-material/Search';
import DeleteIcon from '@mui/icons-material/Delete';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import MoreVertIcon from '@mui/icons-material/MoreVert';
import CardGiftcardIcon from '@mui/icons-material/CardGiftcard';
import LockResetIcon from '@mui/icons-material/LockReset';
import Header from '../../components/Header';
import { tokens } from '../../theme';
import { format } from 'date-fns';

// Style for the modal
const style = {
  position: 'absolute',
  top: '50%',
  left: '50%',
  transform: 'translate(-50%, -50%)',
  width: 400,
  bgcolor: 'background.paper',
  border: '2px solid #000',
  borderRadius: '8px',
  boxShadow: 24,
  p: 4,
};


const UserList = () => {
  const theme = useTheme();
  const colors = tokens(theme.palette.mode);

  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [snackbar, setSnackbar] = useState({ open: false, message: '', severity: 'info' });

  // --- NEW: State for search and filtering ---
  const [searchTerm, setSearchTerm] = useState('');
  const [filterStatus, setFilterStatus] = useState('all'); // 'all', 'active', 'inactive', 'requested'

  // State for menu and modal
  const [anchorEl, setAnchorEl] = useState(null);
  const [selectedUser, setSelectedUser] = useState(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [activeGiftPools, setActiveGiftPools] = useState([]);
  const [selectedPoolId, setSelectedPoolId] = useState('');
  const [isModalLoading, setIsModalLoading] = useState(false);

  const fetchData = async () => {
    try {
      const [usersResponse, paymentsResponse] = await Promise.all([
        apiClient.get('/admin/users'),
        apiClient.get('/admin/payment-requests'),
      ]);

      const usersData = usersResponse.data || [];
      const paymentsData = paymentsResponse.data || [];
      const paymentMap = new Map();
      
      paymentsData.forEach(payment => paymentMap.set(Number(payment.user_id), payment));

      const mergedData = usersData.map(user => ({
        ...user,
        pendingPayment: paymentMap.get(user.id) || null,
      }));
      setUsers(mergedData);
    } catch (error) {
      console.error('Failed to fetch data:', error);
      setSnackbar({ open: true, message: 'Failed to fetch user or payment data.', severity: 'error' });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  const filteredUsers = users.filter((user) => {
    // Status Filter Logic
    let statusMatch = true;
    if (filterStatus === 'active') {
      statusMatch = user.is_subscribed === true;
    } else if (filterStatus === 'inactive') {
      statusMatch = user.is_subscribed === false;
    } else if (filterStatus === 'requested') {
      statusMatch = !!user.pendingPayment;
    }

    // Search Term Filter Logic
    const searchMatch = (
      (user.first_name || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (user.last_name || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (user.phone_number || '').includes(searchTerm) ||
      (user.email || '').toLowerCase().includes(searchTerm.toLowerCase())
    );

    return statusMatch && searchMatch;
  });
  
  const handleApprove = async (paymentId) => {
    try {
      await apiClient.post(`/admin/payment-requests/${paymentId}/approve`);
      setSnackbar({ open: true, message: 'Payment approved! User is now subscribed.', severity: 'success' });
      fetchData();
    } catch (error) {
      setSnackbar({ open: true, message: 'Failed to approve payment.', severity: 'error' });
    }
  };
  
  const handleDelete = async (userId) => {
    if (window.confirm('Are you sure you want to delete this user? This action cannot be undone.')) {
      try {
        await apiClient.delete(`/admin/users/${userId}`);
        setSnackbar({ open: true, message: 'User deleted successfully!', severity: 'success' });
        fetchData();
      } catch (error) {
        setSnackbar({ open: true, message: 'Failed to delete user.', severity: 'error' });
      }
    }
  };

  const handleResetPassword = async (userId, userName) => {
    if (window.confirm(`Are you sure you want to reset the password for ${userName} to "00000000"?`)) {
      try {
        await apiClient.post(`/admin/users/${userId}/reset-password`);
        setSnackbar({ open: true, message: 'User password has been reset successfully!', severity: 'success' });
      } catch (error) {
        const errorMessage = error.response?.data?.message || 'Failed to reset password.';
        setSnackbar({ open: true, message: errorMessage, severity: 'error' });
      }
    }
  };
  
  const handleCloseSnackbar = () => setSnackbar({ ...snackbar, open: false });

  const handleMenuClick = (event, user) => {
    setAnchorEl(event.currentTarget);
    setSelectedUser(user);
  };

  const handleMenuClose = () => {
    setAnchorEl(null);
  };

  const handleAssignGiftClick = async () => {
    handleMenuClose();
    setIsModalOpen(true);
    setIsModalLoading(true);
    try {
      const response = await apiClient.get('/admin/gift-purchases');
      const pools = response.data.filter(p => p.status === 'approved' && p.quantity_remaining > 0);
      setActiveGiftPools(pools);
    } catch (error) {
      setSnackbar({ open: true, message: 'Could not load active gift pools.', severity: 'error' });
    } finally {
      setIsModalLoading(false);
    }
  };
  
  const handleModalClose = () => {
    setIsModalOpen(false);
    setSelectedPoolId('');
  };

  const handleConfirmAssignment = async () => {
    if (!selectedPoolId || !selectedUser) return;
    try {
      await apiClient.post('/admin/gift/assign', {
        recipient_user_id: selectedUser.id,
        gift_purchase_id: selectedPoolId,
      });
      setSnackbar({ open: true, message: `Gift assigned to ${selectedUser.first_name} successfully!`, severity: 'success' });
      handleModalClose();
      fetchData();
    } catch (error) {
      const errorMessage = error.response?.data?.message || 'Failed to assign gift.';
      setSnackbar({ open: true, message: errorMessage, severity: 'error' });
    }
  };

  if (loading) {
    return <Box display="flex" justifyContent="center" alignItems="center" minHeight="80vh"><CircularProgress /></Box>;
  }

  return (
    <Box m="20px">
      <Header title="USER MANAGEMENT" subtitle="List of users, their payments, and gift assignments" />
      
      <Paper sx={{ p: 3, backgroundColor: theme.palette.background.paper, borderRadius: '12px' }}>
        <Box sx={{ 
          display: 'flex', 
          justifyContent: 'space-between', 
          alignItems: { xs: 'stretch', sm: 'center' }, 
          flexDirection: { xs: 'column', sm: 'row' },
          gap: 2,
          mb: 2 
        }}>
          <FormControl sx={{ minWidth: { xs: '100%', sm: 200 } }} size="small">
            <InputLabel>Filter by Status</InputLabel>
            <Select
              value={filterStatus}
              label="Filter by Status"
              onChange={(e) => setFilterStatus(e.target.value)}
            >
              <MenuItem value="all">All Users</MenuItem>
              <MenuItem value="active">Active Subscribers</MenuItem>
              <MenuItem value="inactive">Inactive Users</MenuItem>
              <MenuItem value="requested">Pending Request</MenuItem>
            </Select>
          </FormControl>
          
          <Box display="flex" backgroundColor={theme.palette.background.default} borderRadius="8px" p="2px 10px" sx={{ width: { xs: '100%', sm: 'auto' } }}>
            <InputBase
              sx={{ ml: 1, flex: 1 }}
              placeholder="Search by name, phone, or email"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
            <IconButton type="button" sx={{ p: 1 }}><SearchIcon /></IconButton>
          </Box>
        </Box>

        <TableContainer>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>ID</TableCell>
                <TableCell>FULL NAME</TableCell>
                <TableCell>EMAIL</TableCell>
                <TableCell>PHONE NUMBER</TableCell>
                <TableCell>SUBSCRIPTION</TableCell>
                <TableCell>EXPIRES AT</TableCell>
                <TableCell>PENDING PAYMENT</TableCell>
                <TableCell align="center">ACTIONS</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {filteredUsers.length > 0 ? (
                filteredUsers.map((user) => (
                  <TableRow key={user.id}>
                    <TableCell>{user.id}</TableCell>
                    <TableCell>{`${user.first_name || ''} ${user.last_name || ''}`}</TableCell>
                    <TableCell>{user.email || 'N/A'}</TableCell>
                    <TableCell>{user.phone_number}</TableCell>
                    
                    <TableCell>
                      <Box component="span" sx={{ p: '5px 10px', borderRadius: '6px', color: '#fff', backgroundColor: user.is_subscribed ? colors.greenAccent[600] : colors.redAccent[500], fontSize: '12px', fontWeight: 'bold' }}>
                        {user.is_subscribed ? 'ACTIVE' : 'INACTIVE'}
                      </Box>
                    </TableCell>

                    <TableCell>
                      {user.is_subscribed && user.subscription_expires_at 
                        ? format(new Date(user.subscription_expires_at), 'MMM dd, yyyy')
                        : 'N/A'
                      }
                    </TableCell>

                    <TableCell>
                      {user.pendingPayment ? (
                        <Tooltip title={`Plan: ${user.pendingPayment.plan} | ID: ${user.pendingPayment.transaction_id}`} arrow>
                           <Typography variant="body2" color={colors.blueAccent[400]} sx={{ fontWeight: 'bold' }}>
                             PENDING
                           </Typography>
                        </Tooltip>
                      ) : (<Typography variant="body2" color="textSecondary">—</Typography>)}
                    </TableCell>
                    
                    <TableCell align="center">
                      <IconButton aria-label="more" onClick={(e) => handleMenuClick(e, user)}>
                        <MoreVertIcon />
                      </IconButton>
                    </TableCell>
                  </TableRow>
                ))
              ) : (
                <TableRow><TableCell colSpan={8} align="center"><Typography p={3}>No users match the current filters.</Typography></TableCell></TableRow>
              )}
            </TableBody>
          </Table>
        </TableContainer>
      </Paper>
      
      <Menu 
        anchorEl={anchorEl} 
        open={Boolean(anchorEl)} 
        onClose={handleMenuClose}
        transformOrigin={{ horizontal: 'right', vertical: 'top' }}
        anchorOrigin={{ horizontal: 'right', vertical: 'bottom' }}
      >
        {selectedUser?.pendingPayment && (
          <MenuItem onClick={() => {
            handleMenuClose();
            handleApprove(selectedUser.pendingPayment.id);
          }}>
            <CheckCircleIcon color="success" sx={{ mr: 1 }} /> Approve Payment
          </MenuItem>
        )}
        <MenuItem onClick={handleAssignGiftClick}>
          <CardGiftcardIcon color="primary" sx={{ mr: 1 }} /> Assign Gift
        </MenuItem>

        <MenuItem onClick={() => {
          handleMenuClose();
          handleResetPassword(selectedUser.id, selectedUser.first_name);
        }}>
          <LockResetIcon sx={{ mr: 1 }} /> Reset Password
        </MenuItem>

        <MenuItem onClick={() => {
          handleMenuClose();
          handleDelete(selectedUser.id);
        }}>
          <DeleteIcon color="error" sx={{ mr: 1 }} /> <Typography color="error">Delete User</Typography>
        </MenuItem>
      </Menu>

      <Modal open={isModalOpen} onClose={handleModalClose}>
        <Box sx={style}>
          <Typography variant="h6" component="h2">Assign Gift to {selectedUser?.first_name}</Typography>
          <Typography sx={{ mt: 2 }}>Select an active gift pool to use.</Typography>
          <FormControl fullWidth sx={{ mt: 2 }}>
            <InputLabel>Gift Pool</InputLabel>
            <Select value={selectedPoolId} label="Gift Pool" onChange={(e) => setSelectedPoolId(e.target.value)}>
              {isModalLoading ? (
                <MenuItem disabled><CircularProgress size={20} /></MenuItem>
              ) : activeGiftPools.length > 0 ? (
                activeGiftPools.map((pool) => (
                  <MenuItem key={pool.id} value={pool.id}>
                    {`From: ${pool.gifter.first_name} | ${pool.plan_duration} | ${pool.quantity_remaining} left`}
                  </MenuItem>
                ))
              ) : (<MenuItem disabled>No active gift pools available.</MenuItem>)}
            </Select>
          </FormControl>
          <Box sx={{ mt: 3, display: 'flex', justifyContent: 'flex-end', gap: 1 }}>
            <Button onClick={handleModalClose}>Cancel</Button>
            <Button onClick={handleConfirmAssignment} variant="contained" color="primary" disabled={!selectedPoolId || isModalLoading}>
              Confirm Assignment
            </Button>
          </Box>
        </Box>
      </Modal>

      <Snackbar open={snackbar.open} autoHideDuration={6000} onClose={handleCloseSnackbar} anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}>
        <Alert onClose={handleCloseSnackbar} severity={snackbar.severity} sx={{ width: '100%' }}>{snackbar.message}</Alert>
      </Snackbar>
    </Box>
  );
};

export default UserList;