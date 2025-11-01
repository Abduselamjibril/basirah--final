import React, { useState, useEffect, useCallback } from 'react';
import { 
    Box, 
    Paper, 
    Typography, 
    Grid, 
    Button, 
    CircularProgress, 
    useTheme, 
    Dialog, 
    DialogTitle, 
    DialogContent, 
    DialogActions, 
    TextField,
    Divider,
    Card,
    CardContent
} from '@mui/material';
import { tokens } from '../../theme';
import { useAuth } from '../../context/AuthContext';
import Header from '../../components/Header';
import apiClient from '../../api/axiosConfig';
import { Toaster, toast } from 'react-hot-toast';
import { AttachMoney, People, CalendarToday, Event } from '@mui/icons-material';

const StatCard = ({ title, value, color, icon }) => (
    <Card sx={{ height: '100%', boxShadow: 3 }}>
        <CardContent sx={{ p: 3 }}>
            <Box display="flex" justifyContent="space-between" alignItems="center">
                <Box>
                    <Typography variant="subtitle1" color="textSecondary" gutterBottom>
                        {title}
                    </Typography>
                    <Typography variant="h4" color={color || 'primary'} fontWeight="bold">
                        {value}
                    </Typography>
                </Box>
                <Box
                    sx={{
                        backgroundColor: color ? `${color}20` : 'primary.light',
                        borderRadius: '50%',
                        width: 60,
                        height: 60,
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center'
                    }}
                >
                    {icon}
                </Box>
            </Box>
        </CardContent>
    </Card>
);

const FinancialReportPage = () => {
    const theme = useTheme();
    const colors = tokens(theme.palette.mode);
    const { user } = useAuth();

    const [reportData, setReportData] = useState(null);
    const [loading, setLoading] = useState(true);
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [payoutAmount, setPayoutAmount] = useState('');

    const fetchData = useCallback(async () => {
        setLoading(true);
        try {
            const reportRes = await apiClient.get('/admin/financial-report');
            setReportData(reportRes.data);
        } catch (error) {
            toast.error('Failed to fetch financial report data.');
            console.error(error);
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => {
        fetchData();
    }, [fetchData]);

    const handleOpenPayoutModal = () => setIsModalOpen(true);
    const handleClosePayoutModal = () => {
        setIsModalOpen(false);
        setPayoutAmount('');
    };

    const handleInitiatePayout = async () => {
        if (!payoutAmount || parseFloat(payoutAmount) <= 0) {
            toast.error('Please enter a valid amount.');
            return;
        }
        try {
            await apiClient.post('/admin/payouts', { amount: payoutAmount });
            toast.success('Payout request submitted successfully!');
            handleClosePayoutModal();
            fetchData();
        } catch (error) {
            toast.error(error.response?.data?.message || 'Failed to submit payout request.');
        }
    };

    if (loading) {
        return (
            <Box 
                display="flex" 
                justifyContent="center" 
                alignItems="center" 
                height="80vh"
            >
                <CircularProgress size={60} thickness={4} />
            </Box>
        );
    }

    // Safe color access with fallbacks
    const primaryColor = colors.primary?.[400] || theme.palette.primary.main;
    const greenColor = colors.greenAccent?.[500] || '#4caf50';
    const blueColor = colors.blueAccent?.[500] || '#2196f3';
    const redColor = colors.redAccent?.[500] || '#f44336';
    const yellowColor = colors.yellowAccent?.[500] || '#ffeb3b';

    return (
        <Box m="20px">
            <Toaster position="top-center" />
            <Header 
                title="FINANCIAL REPORT" 
                subtitle="High-level summary of revenue and partner shares" 
            />

            <Grid container spacing={3} mb={4}>
                <Grid item xs={12} sm={6} md={3}>
                    <StatCard 
                        title="Total Revenue (ETB)" 
                        value={reportData?.total_revenue.toLocaleString() || '0'} 
                        color={greenColor}
                        icon={<AttachMoney fontSize="large" color="primary" />}
                    />
                </Grid>
                <Grid item xs={12} sm={6} md={3}>
                    <StatCard 
                        title="Active Subscribers" 
                        value={reportData?.subscription_counts.total_active_subscribers || '0'} 
                        color={blueColor}
                        icon={<People fontSize="large" color="primary" />}
                    />
                </Grid>
                <Grid item xs={12} sm={6} md={3}>
                    <StatCard 
                        title="6-Month Plans Sold" 
                        value={reportData?.subscription_counts.six_month_plans_sold || '0'} 
                        color={redColor}
                        icon={<CalendarToday fontSize="large" color="primary" />}
                    />
                </Grid>
                <Grid item xs={12} sm={6} md={3}>
                    <StatCard 
                        title="Yearly Plans Sold" 
                        value={reportData?.subscription_counts.yearly_plans_sold || '0'} 
                        color={yellowColor}
                        icon={<Event fontSize="large" color="primary" />}
                    />
                </Grid>
            </Grid>

            <Grid container spacing={3}>
                <Grid item xs={12} md={8}>
                    <Card sx={{ boxShadow: 3, height: '100%' }}>
                        <CardContent sx={{ p: 3 }}>
                            <Typography variant="h5" gutterBottom sx={{ fontWeight: 600 }}>
                                Share Distribution (All Time)
                            </Typography>
                            <Divider sx={{ my: 2 }} />
                            <Box display="flex" justifyContent="space-around" mt={4} flexWrap="wrap">
                                <Box textAlign="center" p={2} sx={{ minWidth: 200 }}>
                                    <Typography variant="h6" color="textSecondary">Basirah (70%)</Typography>
                                    <Typography 
                                        variant="h3" 
                                        fontWeight="bold"
                                        sx={{ 
                                            color: greenColor,
                                            background: `linear-gradient(135deg, ${greenColor}, ${colors.greenAccent?.[700] || '#2e7d32'})`,
                                            WebkitBackgroundClip: 'text',
                                            WebkitTextFillColor: 'transparent'
                                        }}
                                    >
                                        {reportData?.share_distribution.basirah_70_percent.toLocaleString()}
                                    </Typography>
                                </Box>
                                <Box textAlign="center" p={2} sx={{ minWidth: 200 }}>
                                    <Typography variant="h6" color="textSecondary">Skylink (30%)</Typography>
                                    <Typography 
                                        variant="h3" 
                                        fontWeight="bold"
                                        sx={{ 
                                            color: blueColor,
                                            background: `linear-gradient(135deg, ${blueColor}, ${colors.blueAccent?.[700] || '#1565c0'})`,
                                            WebkitBackgroundClip: 'text',
                                            WebkitTextFillColor: 'transparent'
                                        }}
                                    >
                                        {reportData?.share_distribution.skylink_30_percent.toLocaleString()}
                                    </Typography>
                                </Box>
                            </Box>
                        </CardContent>
                    </Card>
                </Grid>
                <Grid item xs={12} md={4}>
                    <Card sx={{ 
                        boxShadow: 3, 
                        height: '100%', 
                        background: `linear-gradient(135deg, ${primaryColor}, ${colors.blueAccent?.[700] || '#1565c0'})` 
                    }}>
                        <CardContent sx={{ p: 3, height: '100%', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
                            <Typography variant="h6" textAlign="center" color="white">
                                Skylink Available for Payout
                            </Typography>
                            <Typography 
                                variant="h3" 
                                fontWeight="bold" 
                                textAlign="center" 
                                my={2}
                                sx={{ 
                                    color: 'white',
                                    textShadow: '0 2px 4px rgba(0,0,0,0.2)'
                                }}
                            >
                                {reportData?.skylink_payout_summary.balance_available_for_payout.toLocaleString() || '0'} ETB
                            </Typography>
                            {user?.email === 'basirah@gmail.com' && (
                                <Button 
                                    variant="contained" 
                                    color="secondary" 
                                    onClick={handleOpenPayoutModal}
                                    sx={{
                                        mt: 2,
                                        fontWeight: 'bold',
                                        boxShadow: 2,
                                        '&:hover': {
                                            boxShadow: 4,
                                            transform: 'translateY(-2px)'
                                        },
                                        transition: 'all 0.2s ease-in-out'
                                    }}
                                >
                                    Initiate Payout
                                </Button>
                            )}
                        </CardContent>
                    </Card>
                </Grid>
            </Grid>
            
            <Dialog 
                open={isModalOpen} 
                onClose={handleClosePayoutModal}
                PaperProps={{
                    sx: {
                        borderRadius: 3,
                        boxShadow: 6
                    }
                }}
            >
                <DialogTitle sx={{ 
                    backgroundColor: primaryColor,
                    color: 'white',
                    fontWeight: 'bold'
                }}>
                    Initiate Payout to Skylink
                </DialogTitle>
                <DialogContent sx={{ p: 3 }}>
                    <Typography gutterBottom variant="body1">
                        Available Balance: <strong>{reportData?.skylink_payout_summary.balance_available_for_payout.toLocaleString() || '0'} ETB</strong>
                    </Typography>
                    <TextField 
                        autoFocus 
                        margin="dense" 
                        label="Amount to Pay (ETB)" 
                        type="number" 
                        fullWidth 
                        variant="outlined" 
                        value={payoutAmount} 
                        onChange={(e) => setPayoutAmount(e.target.value)}
                        sx={{ mt: 3 }}
                        InputProps={{
                            startAdornment: (
                                <Typography color="textSecondary" mr={1}>ETB</Typography>
                            )
                        }}
                    />
                </DialogContent>
                <DialogActions sx={{ p: 2 }}>
                    <Button 
                        onClick={handleClosePayoutModal}
                        variant="outlined"
                        sx={{
                            borderRadius: 2,
                            px: 3
                        }}
                    >
                        Cancel
                    </Button>
                    <Button 
                        onClick={handleInitiatePayout} 
                        variant="contained" 
                        color="secondary"
                        sx={{
                            borderRadius: 2,
                            px: 3,
                            fontWeight: 'bold'
                        }}
                    >
                        Submit Request
                    </Button>
                </DialogActions>
            </Dialog>
        </Box>
    );
};

export default FinancialReportPage;