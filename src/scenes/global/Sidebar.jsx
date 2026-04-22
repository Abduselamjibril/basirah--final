import { useState } from "react";
import { ProSidebarProvider, Sidebar, Menu, MenuItem, useProSidebar } from "react-pro-sidebar";
import { Box, IconButton, Typography, useTheme, Collapse } from "@mui/material";
import { Link } from "react-router-dom";
import { tokens } from "../../theme";
import { useAuth } from "../../context/AuthContext"; 
import HomeOutlinedIcon from "@mui/icons-material/HomeOutlined";
import NotificationsOutlinedIcon from "@mui/icons-material/NotificationsOutlined";
import HelpOutlineOutlinedIcon from "@mui/icons-material/HelpOutlineOutlined";
import PersonOutlinedIcon from "@mui/icons-material/PersonOutlined";
import QuestionAnswerOutlinedIcon from "@mui/icons-material/QuestionAnswerOutlined";
import MenuOutlinedIcon from "@mui/icons-material/MenuOutlined";
import CloudUploadOutlinedIcon from "@mui/icons-material/CloudUploadOutlined";
import ExpandMoreOutlinedIcon from "@mui/icons-material/ExpandMoreOutlined";
import ExpandLessOutlinedIcon from "@mui/icons-material/ExpandLessOutlined";
import CardGiftcardIcon from "@mui/icons-material/CardGiftcard";
import AdminPanelSettings from "@mui/icons-material/AdminPanelSettings";
import AssessmentIcon from '@mui/icons-material/Assessment';
import PaymentsIcon from '@mui/icons-material/Payments';
import ArticleOutlinedIcon from '@mui/icons-material/ArticleOutlined';
import InfoOutlinedIcon from '@mui/icons-material/InfoOutlined';
import GavelOutlinedIcon from '@mui/icons-material/GavelOutlined';
import PrivacyTipOutlinedIcon from '@mui/icons-material/PrivacyTipOutlined';
import ContactPhoneOutlinedIcon from '@mui/icons-material/ContactPhoneOutlined';
// --- ADDED: New Icon for the External Website Link ---
import LanguageOutlinedIcon from '@mui/icons-material/LanguageOutlined';


const Item = ({ title, to, icon, selected, setSelected }) => {
    const theme = useTheme();
    const colors = tokens(theme.palette.mode);
    const isActive = selected === title;
    return (
        <MenuItem active={isActive} style={{ color: isActive ? colors.greenAccent[500] : colors.grey[100], backgroundColor: "transparent", margin: "4px 0", borderRadius: "8px" }} onClick={() => setSelected(title)} icon={icon} component={<Link to={to} />}>
            <Typography variant="body1" fontWeight={isActive ? "600" : "500"}>{title}</Typography>
        </MenuItem>
    );
};

// --- ADDED: New Component for External Links ---
// This component uses a standard <a> tag to navigate to an external URL in a new tab.
const ExternalItem = ({ title, href, icon }) => {
    const theme = useTheme();
    const colors = tokens(theme.palette.mode);
    return (
        <MenuItem 
            style={{ color: colors.grey[100], backgroundColor: "transparent", margin: "4px 0", borderRadius: "8px" }} 
            icon={icon} 
            component={<a href={href} target="_blank" rel="noopener noreferrer" />}
        >
            <Typography variant="body1" fontWeight="500">{title}</Typography>
        </MenuItem>
    );
};


const SidebarContent = () => {
    const { collapseSidebar, collapsed } = useProSidebar();
    const theme = useTheme();
    const colors = tokens(theme.palette.mode);
    const [selected, setSelected] = useState("Dashboard");
    const { user } = useAuth();
    
    const can = (permissionName) => {
        if (user?.is_super_admin) {
            return true;
        }
        return user?.permissions?.some(p => p.name === permissionName);
    };

    return (
        <Box sx={{
            height: "100%", backgroundColor: theme.palette.background.paper,
            '& .ps-sidebar-root': { height: '100%', border: 'none' },
            '& .ps-sidebar-container': { background: `${theme.palette.background.paper} !important` },
            '& .ps-menu-root': { padding: '0 12px' },
            '& .ps-menu-button': { padding: '8px 20px 8px 16px !important', margin: '4px 0', borderRadius: '8px', transition: 'all 0.2s ease !important', '&:hover': { backgroundColor: 'rgba(0, 200, 149, 0.1) !important', color: `${colors.greenAccent[500]} !important` } },
            '& .ps-menu-item.ps-active > .ps-menu-button': { color: `${colors.greenAccent[500]} !important` },
        }}>
            <Sidebar collapsed={collapsed} width="270px" collapsedWidth="80px" backgroundColor="transparent">
                <Menu>
                    <MenuItem onClick={() => collapseSidebar()} icon={collapsed ? <MenuOutlinedIcon /> : undefined} style={{ margin: "16px 0 24px 0", color: colors.grey[100] }}>
                        {!collapsed && ( <Box display="flex" justifyContent="space-between" alignItems="center" ml="12px"><Typography variant="h3" color={colors.grey[100]} fontWeight="bold">ADMIN</Typography><IconButton onClick={() => collapseSidebar()} sx={{ color: colors.grey[100] }}><MenuOutlinedIcon /></IconButton></Box> )}
                    </MenuItem>
                    {!collapsed && user && (
                        <Box mb="25px" px="16px">
                            <Box display="flex" justifyContent="center" alignItems="center" mb="12px"><img alt="profile-user" width="100px" height="100px" src={`../../assets/Basirah.jpg`} style={{ cursor: "pointer", borderRadius: "50%", border: `3px solid ${colors.greenAccent[500]}`, objectFit: "cover" }} /></Box>
                            <Box textAlign="center">
                                <Typography variant="h2" color={colors.grey[100]} fontWeight="bold" sx={{ m: "10px 0 0 0" }}>{user.name}</Typography>
                                <Typography variant="h5" color={colors.greenAccent[500]}>{user.is_super_admin ? 'Super Admin' : 'Admin'}</Typography>
                            </Box>
                        </Box>
                    )}

                    <Box paddingLeft={collapsed ? undefined : "10%"} paddingRight="10%">
                        {can('view_dashboard') && <Item title="Dashboard" to="/dashboard" icon={<HomeOutlinedIcon />} selected={selected} setSelected={setSelected} />}
                        {can('view_notifications') && <Item title="Notifications" to="/notificationpage" icon={<NotificationsOutlinedIcon />} selected={selected} setSelected={setSelected} />}
                        {can('manage_faq') && <Item title="FAQ Page" to="/faq" icon={<HelpOutlineOutlinedIcon />} selected={selected} setSelected={setSelected} />}
                        <Item title="Questions" to="/questions" icon={<QuestionAnswerOutlinedIcon />} selected={selected} setSelected={setSelected} />
                        
                        {user?.is_super_admin && (
                            <>
                                <Item title="Financial Report" to="/financial-report" icon={<AssessmentIcon />} selected={selected} setSelected={setSelected} />
                                <Item title="Payouts" to="/payouts" icon={<PaymentsIcon />} selected={selected} setSelected={setSelected} />
                            </>
                        )}
                        
                        {can('manage_roles') && <Item title="Roles & Permissions" to="/roles" icon={<AdminPanelSettings />} selected={selected} setSelected={setSelected} />}
                        <Item title="Gift Purchases" to="/gift-purchases" icon={<CardGiftcardIcon />} selected={selected} setSelected={setSelected} />
                        
                        <UploadManager selected={selected} setSelected={setSelected} can={can} />
                        <AppPagesManager selected={selected} setSelected={setSelected} can={can} />

                        {/* --- ADDED: The external website link is placed here --- */}
                        {can('view_main_website') && (
                            <ExternalItem 
                                title="Main Website" 
                                href="https://besirad.basirahtv.com/" 
                                icon={<LanguageOutlinedIcon />} 
                            />
                        )}

                        <Item title="Profile" to="/user" icon={<PersonOutlinedIcon />} selected={selected} setSelected={setSelected} />
                    </Box>
                </Menu>
            </Sidebar>
        </Box>
    );
};

const UploadManager = ({ selected, setSelected, can }) => {
    const [isOpen, setIsOpen] = useState(false);
    const theme = useTheme();
    const colors = tokens(theme.palette.mode);
    const hasAnyUploadPermission = ['manage_uploads_course', 'manage_uploads_surah', 'manage_uploads_story', 'manage_uploads_deeper_look', 'manage_uploads_commentary'].some(p => can(p));
    
    if (!hasAnyUploadPermission) return null;

    return (
        <>
            <MenuItem icon={<CloudUploadOutlinedIcon />} onClick={() => setIsOpen(!isOpen)} style={{ color: colors.grey[100], margin: "4px 0", borderRadius: "8px" }} suffix={isOpen ? <ExpandLessOutlinedIcon /> : <ExpandMoreOutlinedIcon />}>
                <Typography variant="body1">Upload Manager</Typography>
            </MenuItem>
            <Collapse in={isOpen} timeout="auto" unmountOnExit>
                <Box pl={2}>
                    {can('manage_uploads_course') && <Item title="Course" to="/upload/course" selected={selected} setSelected={setSelected} />}
                    {can('manage_uploads_surah') && <Item title="Surah" to="/upload/surah" selected={selected} setSelected={setSelected} />}
                    {can('manage_uploads_story') && <Item title="Story" to="/upload/story" selected={selected} setSelected={setSelected} />}
                    {can('manage_uploads_deeper_look') && <Item title="DeeperLook" to="/upload/deeperLook" selected={selected} setSelected={setSelected} />}
                    {can('manage_uploads_commentary') && <Item title="Commentary" to="/upload/commentary" selected={selected} setSelected={setSelected} />}
                </Box>
            </Collapse>
        </>
    );
};

const AppPagesManager = ({ selected, setSelected, can }) => {
    const [isOpen, setIsOpen] = useState(false);
    const theme = useTheme();
    const colors = tokens(theme.palette.mode);

    if (!can('manage_app_pages')) return null;

    return (
        <>
            <MenuItem icon={<ArticleOutlinedIcon />} onClick={() => setIsOpen(!isOpen)} style={{ color: colors.grey[100], margin: "4px 0", borderRadius: "8px" }} suffix={isOpen ? <ExpandLessOutlinedIcon /> : <ExpandMoreOutlinedIcon />}>
                <Typography variant="body1">App Pages</Typography>
            </MenuItem>
            <Collapse in={isOpen} timeout="auto" unmountOnExit>
                <Box pl={2}>
                    <Item title="About Us" to="/pages/about-us" icon={<InfoOutlinedIcon />} selected={selected} setSelected={setSelected} />
                    <Item title="Privacy Policy" to="/pages/privacy-policy" icon={<PrivacyTipOutlinedIcon />} selected={selected} setSelected={setSelected} />
                    <Item title="Terms & Agreement" to="/pages/terms" icon={<GavelOutlinedIcon />} selected={selected} setSelected={setSelected} />
                    <Item title="Contact Info" to="/pages/contact-info" icon={<ContactPhoneOutlinedIcon />} selected={selected} setSelected={setSelected} />
                </Box>
            </Collapse>
        </>
    );
}

const SidebarComponent = () => (
    <ProSidebarProvider>
        <SidebarContent />
    </ProSidebarProvider>
);

export default SidebarComponent;