import { useEffect } from "react";
import { Routes, Route, Navigate } from "react-router-dom";
import { AuthProvider, useAuth } from "./context/AuthContext";
import { CssBaseline, ThemeProvider, Box, CircularProgress } from "@mui/material";
import { ColorModeContext, useMode } from "./theme";

// --- SCENE IMPORTS ---
import Topbar from "./scenes/global/Topbar";
import Sidebar from "./scenes/global/Sidebar";
import Dashboard from "./scenes/dashboard";
import User from "./scenes/user_list";
import FAQ from "./scenes/faq";
import NotificationPage from "./scenes/notificationpage";
import Maintenance from "./scenes/maintanace";
import Profile from "./components/Profile";
import CourseManager from './scenes/upload/course/index';
import EpisodeManager from './scenes/upload/course/EpisodeManager';
import SurahUpload from "./scenes/upload/surah";
import SurahEpisodeManager from "./scenes/upload/surah/SurahEpisodeManager";
import DeeperLookManager from "./scenes/upload/deeperLook"; 
import DeeperLookEpisodeManager from "./scenes/upload/deeperLook/DeeperLookEpisodeManager"; 
import CommentaryManager from "./scenes/upload/commentary"; 
import CommentaryEpisodeManager from "./scenes/upload/commentary/CommentaryEpisodeManager"; 
import StoryUpload from "./scenes/upload/story"; 
import StoryEpisodeManager from "./scenes/upload/story/StoryEpisodeManager"; 
import AdminLogin from "./components/AdminLogin"; 
import GiftPurchases from "./scenes/gift_purchases";
import RolesAndPermissions from "./scenes/roles";
import FinancialReportPage from "./scenes/financial_report"; 
import PayoutsPage from "./scenes/payouts";
import Questions from "./scenes/questions";

// --- NEW SCENE IMPORTS FOR APP PAGES ---
import AboutUsPage from "./scenes/app_pages/AboutUsPage";
import PrivacyPolicyPage from "./scenes/app_pages/PrivacyPolicyPage";
import TermsPage from "./scenes/app_pages/TermsPage";
import ContactInfoPage from "./scenes/app_pages/ContactInfoPage";

function AuthenticatedApp() {
  const { logout } = useAuth();

  return (
    <>
      <Sidebar />
      <main className="content">
        <Topbar onLogout={logout} />
        <Routes>
          <Route path="/" element={<Navigate to="/dashboard" replace />} />
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/user" element={<User />} />
          <Route path="/faq" element={<FAQ />} />
          <Route path="/notificationpage" element={<NotificationPage />} />
          <Route path="/maintanace" element={<Maintenance />} />
          <Route path="/roles" element={<RolesAndPermissions />} />
          <Route path="/financial-report" element={<FinancialReportPage />} />
          <Route path="/payouts" element={<PayoutsPage />} />
          <Route path="/questions" element={<Questions />} />
          <Route path="/profile" element={<Profile onLogout={logout} />} />
          <Route path="/upload/surah" element={<SurahUpload />} />
          <Route path="/upload/course" element={<CourseManager />} />
          <Route path="/upload/course/:courseId/episodes" element={<EpisodeManager />} />
          <Route path="/upload/surah/:surahId/episodes" element={<SurahEpisodeManager />} />
          <Route path="/upload/deeperLook" element={<DeeperLookManager />} />
          <Route path="/upload/deeper-looks/:deeperLookId/episodes" element={<DeeperLookEpisodeManager />} />
          <Route path="/upload/commentary" element={<CommentaryManager />} />
          <Route path="/upload/commentaries/:commentaryId/episodes" element={<CommentaryEpisodeManager />} />
          <Route path="/upload/story" element={<StoryUpload />} />
          <Route path="/upload/story/:storyId/episodes" element={<StoryEpisodeManager />} />
          <Route path="/gift-purchases" element={<GiftPurchases />} /> 

          {/* --- NEW ROUTES FOR APP PAGES --- */}
          <Route path="/pages/about-us" element={<AboutUsPage />} />
          <Route path="/pages/privacy-policy" element={<PrivacyPolicyPage />} />
          <Route path="/pages/terms" element={<TermsPage />} />
          <Route path="/pages/contact-info" element={<ContactInfoPage />} />

          <Route path="*" element={<Navigate to="/dashboard" replace />} />
        </Routes>
      </main>
    </>
  );
}

function AppContent() {
  const { isAuthenticated, loading, fetchUser, setIsAuthenticated } = useAuth();

  useEffect(() => {
    fetchUser();
  }, [fetchUser]);

  const handleLoginSuccess = (token) => {
    localStorage.setItem('authToken', token);
    setIsAuthenticated(true);
    fetchUser();
  };

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" height="100vh">
        <CircularProgress />
      </Box>
    );
  }

  return (
    <div className="app">
      {isAuthenticated ? (
        <AuthenticatedApp />
      ) : (
        <Routes>
          <Route path="/login" element={<AdminLogin onLoginSuccess={handleLoginSuccess} />} />
          <Route path="*" element={<Navigate to="/login" replace />} />
        </Routes>
      )}
    </div>
  );
}

function App() {
  const [theme, colorMode] = useMode();
  return (
    <ColorModeContext.Provider value={colorMode}>
      <ThemeProvider theme={theme}>
        <CssBaseline />
        <AuthProvider>
          <AppContent />
        </AuthProvider>
      </ThemeProvider>
    </ColorModeContext.Provider>
  );
}

export default App;