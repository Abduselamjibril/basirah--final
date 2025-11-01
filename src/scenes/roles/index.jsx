import React, { useEffect, useState, useCallback } from 'react';
import {
  Box,
  Button,
  Typography,
  useTheme,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  CircularProgress,
  IconButton,
  Chip,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  FormGroup,
  FormControlLabel,
  Checkbox,
} from '@mui/material';
import { Add, Edit, Delete, AdminPanelSettings } from '@mui/icons-material';
import { tokens } from '../../theme';
import { useAuth } from '../../context/AuthContext';
import apiClient from '../../api/axiosConfig';
import { Toaster, toast } from 'react-hot-toast';
import Header from '../../components/Header';

const UserFormModal = ({ open, onClose, onSave, user, allPermissions }) => {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [selectedPermissions, setSelectedPermissions] = useState(new Set());
  const [isSubmitting, setIsSubmitting] = useState(false);
  const isEditMode = !!user;

  useEffect(() => {
    if (isEditMode && user) {
      setName(user.name);
      setEmail(user.email);
      setSelectedPermissions(new Set(user.permissions.map(p => p.id)));
    } else {
      setName('');
      setEmail('');
      setSelectedPermissions(new Set());
    }
  }, [user, isEditMode, open]);

  const handlePermissionChange = (permissionId) => {
    setSelectedPermissions(prev => {
      const newSet = new Set(prev);
      if (newSet.has(permissionId)) {
        newSet.delete(permissionId);
      } else {
        newSet.add(permissionId);
      }
      return newSet;
    });
  };

  const handleSave = async () => {
    if (!isEditMode && (!name || !email)) {
        toast.error("Role Name and Email are required.");
        return;
    }
    if (selectedPermissions.size === 0) {
        toast.error("At least one permission must be selected.");
        return;
    }

    const userData = {
      name: isEditMode ? user.name : name,
      email: isEditMode ? user.email : email,
      permissions: Array.from(selectedPermissions),
    };

    setIsSubmitting(true);
    await onSave(userData, user?.id);
    setIsSubmitting(false);
  };

  return (
    <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth>
      <DialogTitle>{isEditMode ? 'Edit User Permissions' : 'Create New Admin User'}</DialogTitle>
      <DialogContent>
        <TextField
          autoFocus
          margin="dense"
          label="Role Name"
          type="text"
          fullWidth
          variant="standard"
          value={name}
          onChange={(e) => setName(e.target.value)}
          disabled={isEditMode}
          required
        />
        <TextField
          margin="dense"
          label="Email Address"
          type="email"
          fullWidth
          variant="standard"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          disabled={isEditMode}
          required
        />
        <Typography variant="h6" sx={{ mt: 3, mb: 1 }}>Permissions</Typography>
        <FormGroup sx={{ maxHeight: '300px', overflowY: 'auto' }}>
          {allPermissions.map(permission => (
            <FormControlLabel
              key={permission.id}
              control={
                <Checkbox
                  checked={selectedPermissions.has(permission.id)}
                  onChange={() => handlePermissionChange(permission.id)}
                />
              }
              label={permission.display_name}
            />
          ))}
        </FormGroup>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={isSubmitting}>Cancel</Button>
        <Button onClick={handleSave} variant="contained" color="secondary" disabled={isSubmitting}>
          {isSubmitting ? <CircularProgress size={24} /> : 'Save'}
        </Button>
      </DialogActions>
    </Dialog>
  );
};

const RolesAndPermissions = () => {
  const theme = useTheme();
  const colors = tokens(theme.palette.mode);
  const { user: loggedInUser } = useAuth();

  const [users, setUsers] = useState([]);
  const [permissions, setPermissions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [editingUser, setEditingUser] = useState(null);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const [usersResponse, permissionsResponse] = await Promise.all([
        apiClient.get('/admin/admin-users'),
        apiClient.get('/admin/permissions'),
      ]);
      setUsers(usersResponse.data);
      setPermissions(permissionsResponse.data);
    } catch (error) {
      console.error('Failed to fetch data:', error);
      toast.error('Failed to load user and permission data.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const handleOpenModal = (user = null) => {
    setEditingUser(user);
    setModalOpen(true);
  };

  const handleCloseModal = () => {
    setModalOpen(false);
    setEditingUser(null);
  };

  const handleSaveUser = async (userData, userId) => {
    try {
      if (userId) { // Editing permissions
        await apiClient.put(`/admin/admin-users/${userId}/permissions`, { permissions: userData.permissions });
        toast.success('User permissions updated successfully!');
      } else { // Creating new user
        await apiClient.post('/admin/admin-users', userData);
        toast.success('User created successfully!');
      }
      await fetchData();
      handleCloseModal();
    } catch (error) {
      const errorMsg = error.response?.data?.message || 'An error occurred.';
      const errors = error.response?.data?.errors;
      if (errors) {
        Object.values(errors).forEach(errArray => {
          errArray.forEach(err => toast.error(err));
        });
      } else {
        toast.error(`Error: ${errorMsg}`);
      }
    }
  };

  const handleDeleteUser = async (userId, userName) => {
    if (window.confirm(`Are you sure you want to delete the user "${userName}"? This action cannot be undone.`)) {
      try {
        await apiClient.delete(`/admin/admin-users/${userId}`);
        toast.success('User deleted successfully!');
        await fetchData();
      } catch (error) {
        const errorMsg = error.response?.data?.message || 'An error occurred.';
        toast.error(`Error: ${errorMsg}`);
      }
    }
  };

  if (loading) {
    return <Box display="flex" justifyContent="center" alignItems="center" height="100%"><CircularProgress /></Box>;
  }

  return (
    <Box m="20px">
      <Toaster position="top-center" />
      <Header title="Roles & Permissions" subtitle="Manage admin user roles and their access levels" />
      <Box display="flex" justifyContent="end" mb="20px">
        <Button variant="contained" color="secondary" startIcon={<Add />} onClick={() => handleOpenModal()}>
          Create New User
        </Button>
      </Box>
      <TableContainer component={Paper} sx={{ backgroundColor: colors.primary[400] }}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Role Name</TableCell>
              <TableCell>Email</TableCell>
              <TableCell>Status</TableCell>
              <TableCell align="right">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {users.map((user) => (
              <TableRow key={user.id} hover>
                <TableCell>{user.name}</TableCell>
                <TableCell>{user.email}</TableCell>
                <TableCell>
                  {user.is_super_admin && (
                    <Chip
                      icon={<AdminPanelSettings />}
                      label="Super Admin"
                      color="success"
                      variant="outlined"
                    />
                  )}
                </TableCell>
                <TableCell align="right">
                  <IconButton
                    onClick={() => handleOpenModal(user)}
                    disabled={user.is_super_admin || user.id === loggedInUser.id}
                    title="Edit Permissions"
                  >
                    <Edit />
                  </IconButton>
                  <IconButton
                    onClick={() => handleDeleteUser(user.id, user.name)}
                    disabled={user.is_super_admin}
                    color="error"
                    title="Delete User"
                  >
                    <Delete />
                  </IconButton>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>
      <UserFormModal
        open={modalOpen}
        onClose={handleCloseModal}
        onSave={handleSaveUser}
        user={editingUser}
        allPermissions={permissions}
      />
    </Box>
  );
};

export default RolesAndPermissions;