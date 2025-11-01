import React, { useState, useEffect, useCallback } from 'react';
import { Box, Paper, Typography, Button, CircularProgress, useTheme, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Chip, TextField, Select, MenuItem, FormControl, InputLabel } from '@mui/material';
import { tokens } from '../../theme';
import { useAuth } from '../../context/AuthContext';
import Header from '../../components/Header';
import apiClient from '../../api/axiosConfig';
import { Toaster, toast } from 'react-hot-toast';
import { format } from 'date-fns';
import * as XLSX from 'xlsx'; // --- NEW: Import the Excel library ---

const PayoutsPage = () => {
    const theme = useTheme();
    const colors = tokens(theme.palette.mode);
    const { user } = useAuth();

    const [payouts, setPayouts] = useState([]);
    const [loading, setLoading] = useState(true);
    const [filters, setFilters] = useState({ status: 'all', startDate: '', endDate: '' });

    const fetchPayouts = useCallback(async (currentFilters) => {
        setLoading(true);
        try {
            // --- UPDATED: Create params and only add dates if they exist ---
            const payoutParams = new URLSearchParams();
            payoutParams.append('status', currentFilters.status);
            if (currentFilters.startDate) {
                payoutParams.append('start_date', currentFilters.startDate);
            }
            if (currentFilters.endDate) {
                payoutParams.append('end_date', currentFilters.endDate);
            }

            const payoutsRes = await apiClient.get(`/admin/payouts?${payoutParams.toString()}`);
            setPayouts(payoutsRes.data);
        } catch (error) {
            toast.error('Failed to fetch payout history.');
            console.error(error);
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => {
        fetchPayouts(filters);
    }, []); // This still runs only on initial load, which is correct.

    const handleFilterChange = (e) => {
        setFilters({ ...filters, [e.target.name]: e.target.value });
    };

    const applyFilters = () => {
        // --- This now works correctly with the updated fetchPayouts logic ---
        fetchPayouts(filters);
    };
    
    const handleUpdatePayoutStatus = async (payoutId, newStatus) => {
        try {
            await apiClient.put(`/admin/payouts/${payoutId}`, { status: newStatus });
            toast.success(`Payout has been ${newStatus}.`);
            fetchPayouts(filters); // Refresh table with current filters
        } catch (error) {
            toast.error(error.response?.data?.message || 'Failed to update payout status.');
        }
    };
    
    // --- NEW: Function to handle Excel export ---
    const handleExportExcel = () => {
        if (payouts.length === 0) {
            toast.error("There is no data to export.");
            return;
        }

        // 1. Format the data for the worksheet
        const dataToExport = payouts.map(payout => ({
            'Requested At': format(new Date(payout.requested_at), 'yyyy-MM-dd HH:mm'),
            'Amount (ETB)': parseFloat(payout.amount_paid),
            'Requested By': payout.requester?.name || 'N/A',
            'Status': payout.status,
            'Reviewed By': payout.reviewer?.name || 'N/A',
            'Reviewed At': payout.reviewed_at ? format(new Date(payout.reviewed_at), 'yyyy-MM-dd HH:mm') : 'N/A',
        }));

        // 2. Create worksheet and workbook
        const worksheet = XLSX.utils.json_to_sheet(dataToExport);
        const workbook = XLSX.utils.book_new();
        XLSX.utils.book_append_sheet(workbook, worksheet, "Payouts Report");

        // 3. Trigger the download
        XLSX.writeFile(workbook, "Payouts_Report.xlsx");
    };
    
    // --- NEW: Function to handle printing ---
    const handlePrint = () => {
        const printableArea = document.getElementById('printable-area');
        if (!printableArea || payouts.length === 0) {
            toast.error("There is no data to print.");
            return;
        }

        // Create a clean HTML table for printing
        let printContent = `
            <h1>Payouts Report</h1>
            <p>Generated on: ${format(new Date(), 'MMM dd, yyyy HH:mm')}</p>
            <table border="1" style="width: 100%; border-collapse: collapse; font-family: sans-serif;">
                <thead>
                    <tr>
                        <th style="padding: 8px;">Requested At</th>
                        <th style="padding: 8px;">Amount (ETB)</th>
                        <th style="padding: 8px;">Requested By</th>
                        <th style="padding: 8px;">Status</th>
                        <th style="padding: 8px;">Reviewed By</th>
                        <th style="padding: 8px;">Reviewed At</th>
                    </tr>
                </thead>
                <tbody>
        `;

        payouts.forEach(payout => {
            printContent += `
                <tr>
                    <td style="padding: 8px;">${format(new Date(payout.requested_at), 'yyyy-MM-dd HH:mm')}</td>
                    <td style="padding: 8px;">${payout.amount_paid.toLocaleString()}</td>
                    <td style="padding: 8px;">${payout.requester?.name || 'N/A'}</td>
                    <td style="padding: 8px;">${payout.status.toUpperCase()}</td>
                    <td style="padding: 8px;">${payout.reviewer?.name || 'N/A'}</td>
                    <td style="padding: 8px;">${payout.reviewed_at ? format(new Date(payout.reviewed_at), 'yyyy-MM-dd HH:mm') : 'N/A'}</td>
                </tr>
            `;
        });

        printContent += '</tbody></table>';
        printableArea.innerHTML = printContent;
        window.print(); // Trigger the browser's print dialog
    };


    return (
        <Box m="20px">
            <Toaster position="top-center" />
            <Header title="PAYOUTS" subtitle="Review and track partner payout history" />

            <Paper sx={{ p: 3 }}>
                <Box display="flex" gap={2} mb={3} alignItems="center" flexWrap="wrap">
                    <TextField label="Start Date" type="date" name="startDate" value={filters.startDate} onChange={handleFilterChange} InputLabelProps={{ shrink: true }} />
                    <TextField label="End Date" type="date" name="endDate" value={filters.endDate} onChange={handleFilterChange} InputLabelProps={{ shrink: true }} />
                    <FormControl sx={{ minWidth: 150 }}>
                        <InputLabel>Status</InputLabel>
                        <Select value={filters.status} label="Status" name="status" onChange={handleFilterChange}>
                            <MenuItem value="all">All</MenuItem>
                            <MenuItem value="pending">Pending</MenuItem>
                            <MenuItem value="approved">Approved</MenuItem>
                            <MenuItem value="declined">Declined</MenuItem>
                        </Select>
                    </FormControl>
                    <Button variant="contained" onClick={applyFilters}>Filter</Button>
                    <Box sx={{ flexGrow: 1, textAlign: 'right' }}>
                        {/* --- UPDATED: Export buttons are now enabled and have onClick handlers --- */}
                        <Button variant="outlined" onClick={handleExportExcel}sx={{ 
        // Sets the text color to a light grey from your theme
        color: colors.grey[100], 
        // Sets the border color to a slightly more visible grey
        borderColor: colors.grey[300],
        // On hover, make them pop with your theme's accent color
        '&:hover': {
            borderColor: colors.greenAccent[400],
            color: colors.greenAccent[400],
        } 
    }}>Export Excel</Button>
                       
                    </Box>
                </Box>

                {loading ? (
                    <Box display="flex" justifyContent="center" py={5}><CircularProgress /></Box>
                ) : (
                    <TableContainer>
                        <Table>
                            <TableHead>
                                <TableRow>
                                    <TableCell>Requested At</TableCell>
                                    <TableCell>Amount (ETB)</TableCell>
                                    <TableCell>Requested By</TableCell>
                                    <TableCell>Status</TableCell>
                                    <TableCell>Reviewed By</TableCell>
                                    <TableCell>Reviewed At</TableCell>
                                </TableRow>
                            </TableHead>
                            <TableBody>
                                {payouts.length > 0 ? payouts.map((payout) => (
                                    <TableRow key={payout.id} hover>
                                        <TableCell>{format(new Date(payout.requested_at), 'MMM dd, yyyy HH:mm')}</TableCell>
                                        <TableCell>{parseFloat(payout.amount_paid).toLocaleString()}</TableCell> {/* Ensure it's a number */}
                                        <TableCell>{payout.requester?.name || 'N/A'}</TableCell>
                                        <TableCell>
                                            {payout.status === 'pending' && user?.email === 'skylink@gmail.com' ? (
                                                <Box display="flex" gap={1}>
                                                    <Button size="small" variant="outlined" color="success" onClick={() => handleUpdatePayoutStatus(payout.id, 'approved')}>Approve</Button>
                                                    <Button size="small" variant="outlined" color="error" onClick={() => handleUpdatePayoutStatus(payout.id, 'declined')}>Decline</Button>
                                                </Box>
                                            ) : (
                                                <Chip 
                                                    label={payout.status.toUpperCase()} 
                                                    color={payout.status === 'approved' ? 'success' : payout.status === 'declined' ? 'error' : 'warning'} 
                                                />
                                            )}
                                        </TableCell>
                                        <TableCell>{payout.reviewer?.name || '—'}</TableCell>
                                        <TableCell>{payout.reviewed_at ? format(new Date(payout.reviewed_at), 'MMM dd, yyyy HH:mm') : '—'}</TableCell>
                                    </TableRow>
                                )) : (
                                    <TableRow><TableCell colSpan={6} align="center"><Typography p={3}>No payout records match the current filters.</Typography></TableCell></TableRow>
                                )}
                            </TableBody>
                        </Table>
                    </TableContainer>
                )}
            </Paper>
            
            {/* --- NEW: Hidden div that will be used for printing --- */}
            <div id="printable-area" style={{ display: 'none' }}></div>
        </Box>
    );
};

export default PayoutsPage;