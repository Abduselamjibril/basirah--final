<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

// --- CONTROLLER IMPORTS ---
use App\Http\Controllers\AdminAuthController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\BookmarkController;
use App\Http\Controllers\CommentaryController;
use App\Http\Controllers\CommentaryEpisodeController;
use App\Http\Controllers\CourseController;
use App\Http\Controllers\DeeperLookController;
use App\Http\Controllers\DeeperLookEpisodeController;
use App\Http\Controllers\EpisodeController;
use App\Http\Controllers\FAQController;
use App\Http\Controllers\FcmController;
use App\Http\Controllers\MaintenanceController;
use App\Http\Controllers\NotificationController;
use App\Http\Controllers\PaymentController;
use App\Http\Controllers\Api\PlaylistController;
use App\Http\Controllers\Api\PlaylistItemController;
use App\Http\Controllers\ProgressController;
use App\Http\Controllers\StoryController;
use App\Http\Controllers\StoryEpisodeController;
use App\Http\Controllers\SurahController;
use App\Http\Controllers\SurahEpisodeController;
use App\Http\Controllers\UploadController;
use App\Http\Controllers\UserListController;
use App\Http\Controllers\WebhookController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\PaymentRequestController; 
use App\Http\Controllers\GiftPurchaseController;   // <-- NEW
use App\Http\Controllers\GiftAssignmentController; // <-- NEW
use App\Http\Controllers\Admin\UserController as AdminUserController;
use App\Http\Controllers\Admin\RoleController;
use App\Http\Controllers\Admin\FinancialReportController;
use App\Http\Controllers\Admin\PayoutController;
use App\Http\Controllers\AboutUsController;
use App\Http\Controllers\PrivacyPolicyController;
use App\Http\Controllers\TermsAndAgreementController;
use App\Http\Controllers\ContactInformationController;
use App\Http\Controllers\QuestionController;


use Laravel\Sanctum\Http\Middleware\EnsureFrontendRequestsAreStateful;
/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| This file is organized into four main sections for clarity and security:
| 1. Public Routes: No authentication needed.
| 2. Admin-Only Routes: For the React admin panel. Requires 'admin' guard.
| 3. User-Only Routes: For the Flutter mobile app. Requires 'sanctum' (user) guard.
| 4. Shared Routes: Read-only routes accessible by both admins and users.
|
*/

// ========================================================
// === 1. PUBLIC & WEBHOOK ROUTES (NO AUTH)
// ========================================================
// User Authentication
Route::post('/login', [AuthController::class, 'login'])->name('login');
Route::post('/register', [AuthController::class, 'register'])->name('register');
Route::post('/forgot-password', [AuthController::class, 'forgotPassword']);
Route::post('/verify-otp', [AuthController::class, 'verifyOtp']);
Route::post('/reset-password', [AuthController::class, 'resetPassword']);

// Webhooks (must be public)
Route::any('/webhooks/chapa', [WebhookController::class, 'handleChapa']);
Route::post('/webhooks/stripe', [WebhookController::class, 'handleStripe']);

// Publicly accessible information
Route::get('/maintenance', [MaintenanceController::class, 'index']);
Route::get('/faqs', [FAQController::class, 'index']);
// Publicly accessible site content
Route::get('/about-us', [AboutUsController::class, 'get']);
Route::get('/privacy-policy', [PrivacyPolicyController::class, 'get']);
Route::get('/terms-and-agreement', [TermsAndAgreementController::class, 'get']);
Route::get('/contact-information', [ContactInformationController::class, 'get']);

// ========================================================
// === 2. ADMIN-ONLY ROUTES (FOR REACT ADMIN PANEL)
// ========================================================
// All management routes are prefixed with '/admin' and protected by the 'auth:admin' middleware.
Route::prefix('admin')->group(function () {
    // Admin Authentication (public within this group)
    Route::post('/login', [AdminAuthController::class, 'login']);
    
    // Protected Admin Routes
    Route::middleware('auth:admin')->group(function () {
        // Admin Profile & Auth
        Route::get('/profile', [AdminAuthController::class, 'profile']);
        Route::put('/profile', [AdminAuthController::class, 'updateProfile']); // NEW
        Route::post('/change-password', [AdminAuthController::class, 'changePassword']);
        Route::post('/logout', [AdminAuthController::class, 'logout']);
        Route::get('/stats', [DashboardController::class, 'getStats']);

         Route::get('/about-us', [AboutUsController::class, 'get']);
        Route::post('/about-us', [AboutUsController::class, 'update']);
        
        Route::get('/privacy-policy', [PrivacyPolicyController::class, 'get']);
        Route::post('/privacy-policy', [PrivacyPolicyController::class, 'update']);

        Route::get('/terms-and-agreement', [TermsAndAgreementController::class, 'get']);
        Route::post('/terms-and-agreement', [TermsAndAgreementController::class, 'update']);

        Route::get('/contact-information', [ContactInformationController::class, 'get']);
        Route::post('/contact-information', [ContactInformationController::class, 'update']);
        
        // --- Financial Reporting & Payouts ---
        Route::get('/financial-report', [FinancialReportController::class, 'getReport']);
        Route::get('/financial-report/export', [FinancialReportController::class, 'export']); // For future use
        
        Route::get('/payouts', [PayoutController::class, 'index']);
        Route::post('/payouts', [PayoutController::class, 'store']);
        Route::put('/payouts/{payout}', [PayoutController::class, 'updateStatus']);

        Route::get('/permissions', [RoleController::class, 'getPermissions']);
        Route::get('/admin-users', [RoleController::class, 'index']);
        Route::post('/admin-users', [RoleController::class, 'store']);
        Route::put('/admin-users/{user}/permissions', [RoleController::class, 'updatePermissions']);
        Route::delete('/admin-users/{user}', [RoleController::class, 'destroy']);
        
        // --- Management of Site & Users ---
        Route::post('/upload', [UploadController::class, 'uploadFile']);
        Route::post('/maintenance', [MaintenanceController::class, 'update']);
        Route::get('/users', [UserListController::class, 'index']);
        Route::delete('/users/{id}', [UserListController::class, 'destroy']);
        Route::post('/users/{user}/reset-password', [AdminUserController::class, 'resetPassword']);
        Route::apiResource('faqs', FAQController::class)->only(['store', 'update', 'destroy']);
        Route::post('/notifications', [NotificationController::class, 'createNotification']);
        Route::apiResource('notifications', NotificationController::class)->except(['index', 'store']);
        Route::post('/notifications/update-status', [NotificationController::class, 'updateNotificationStatus']);

        // --- Questions Management ---
        Route::get('/questions', [QuestionController::class, 'index']);
        Route::delete('/questions/{id}', [QuestionController::class, 'destroy']);

        // --- NEW: Manual Payment Management ---
        Route::get('/payment-requests', [PaymentRequestController::class, 'index']);
        Route::post('/payment-requests/{paymentRequest}/approve', [PaymentRequestController::class, 'approve']);
        
        Route::get('/gift-purchases', [GiftPurchaseController::class, 'index']);
        Route::post('/gift-purchases/{giftPurchase}/approve-payment', [GiftPurchaseController::class, 'approvePayment']);
        Route::post('/gift/assign', [GiftAssignmentController::class, 'assign']);

        // --- Content Management (Create, Update, Delete, Lock) ---

        // Course Management
        Route::post('/courses', [CourseController::class, 'store']);
        Route::put('/courses/{id}', [CourseController::class, 'update']);
        Route::delete('/courses/{id}', [CourseController::class, 'destroy']);
        Route::post('/courses/{id}/lock', [CourseController::class, 'lock']);
        Route::post('/courses/{id}/unlock', [CourseController::class, 'unlock']);
        Route::post('/courses/{courseId}/episodes', [EpisodeController::class, 'store']);
        Route::put('/courses/{courseId}/episodes/{episodeId}', [EpisodeController::class, 'update']);
        Route::delete('/courses/{courseId}/episodes/{episodeId}', [EpisodeController::class, 'destroy']);
        Route::post('/courses/{courseId}/episodes/{episodeId}/lock', [EpisodeController::class, 'lock']);
        Route::post('/courses/{courseId}/episodes/{episodeId}/unlock', [EpisodeController::class, 'unlock']);
        Route::post('/courses/{courseId}/episodes/lock', [EpisodeController::class, 'lockAll']);
        Route::post('/courses/{courseId}/episodes/unlock', [EpisodeController::class, 'unlockAll']);

        // Story Management
        Route::post('/stories', [StoryController::class, 'store']);
        Route::put('/stories/{story}', [StoryController::class, 'update']);
        Route::delete('/stories/{story}', [StoryController::class, 'destroy']);
        Route::post('/stories/{story}/lock', [StoryController::class, 'lock']);
        Route::post('/stories/{story}/unlock', [StoryController::class, 'unlock']);
        Route::post('/stories/{story}/episodes', [StoryEpisodeController::class, 'store']);
        Route::put('/episodes/{storyEpisode}', [StoryEpisodeController::class, 'update']);
        Route::delete('/episodes/{storyEpisode}', [StoryEpisodeController::class, 'destroy']);
        Route::post('/episodes/{storyEpisode}/lock', [StoryEpisodeController::class, 'lock']);
        Route::post('/episodes/{storyEpisode}/unlock', [StoryEpisodeController::class, 'unlock']);

        // Surah Management
        Route::post('/surahs', [SurahController::class, 'store']);
        Route::put('/surahs/{id}', [SurahController::class, 'update']);
        Route::delete('/surahs/{id}', [SurahController::class, 'destroy']);
        Route::post('/surahs/{id}/lock', [SurahController::class, 'lock']);
        Route::post('/surahs/{id}/unlock', [SurahController::class, 'unlock']);
        Route::post('/surahs/{surah}/episodes', [SurahEpisodeController::class, 'store']);
        Route::put('/surahs/{surah}/episodes/{episode}', [SurahEpisodeController::class, 'update'])->scopeBindings();
        Route::delete('/surahs/{surah}/episodes/{episode}', [SurahEpisodeController::class, 'destroy']);
        Route::post('/surahs/{surah}/episodes/{episode}/lock', [SurahEpisodeController::class, 'lock']);
        Route::post('/surahs/{surah}/episodes/{episode}/unlock', [SurahEpisodeController::class, 'unlock']);

        // Deeper Look Management
        Route::post('/deeper-looks', [DeeperLookController::class, 'store']);
        Route::put('/deeper-looks/{id}', [DeeperLookController::class, 'update']);
        Route::delete('/deeper-looks/{id}', [DeeperLookController::class, 'destroy']);
        Route::post('/deeper-looks/{id}/lock', [DeeperLookController::class, 'lock']);
        Route::post('/deeper-looks/{id}/unlock', [DeeperLookController::class, 'unlock']);
        Route::post('/deeper-looks/{deeperLook}/episodes', [DeeperLookEpisodeController::class, 'store']);
        Route::put('/deeper-looks/{deeperLook}/episodes/{episode}', [DeeperLookEpisodeController::class, 'update']);
        Route::delete('/deeper-looks/{deeperLook}/episodes/{episode}', [DeeperLookEpisodeController::class, 'destroy']);
        Route::post('/deeper-looks/{deeperLook}/episodes/{episode}/lock', [DeeperLookEpisodeController::class, 'lock']);
        Route::post('/deeper-looks/{deeperLook}/episodes/{episode}/unlock', [DeeperLookEpisodeController::class, 'unlock']);

        // Commentary Management
        Route::post('/commentaries', [CommentaryController::class, 'store']);
        Route::put('/commentaries/{id}', [CommentaryController::class, 'update']);
        Route::delete('/commentaries/{id}', [CommentaryController::class, 'destroy']);
        Route::post('/commentaries/{id}/lock', [CommentaryController::class, 'lock']);
        Route::post('/commentaries/{id}/unlock', [CommentaryController::class, 'unlock']);
        Route::post('/commentaries/{commentary}/episodes', [CommentaryEpisodeController::class, 'store']);
        Route::put('/commentaries/{commentary}/episodes/{episode}', [CommentaryEpisodeController::class, 'update']);
        Route::delete('/commentaries/{commentary}/episodes/{episode}', [CommentaryEpisodeController::class, 'destroy']);
        Route::post('/commentaries/{commentary}/episodes/{episode}/lock', [CommentaryEpisodeController::class, 'lock']);
        Route::post('/commentaries/{commentary}/episodes/{episode}/unlock', [CommentaryEpisodeController::class, 'unlock']);
    });
});


// ========================================================
// === 3. USER-ONLY ROUTES (FOR FLUTTER APP)
// ========================================================
// Routes that require a standard USER (`sanctum`) token.
Route::middleware(['auth:sanctum', EnsureFrontendRequestsAreStateful::class])->group(function () {
    Route::get('/user', function (Request $request) {
        return $request->user();
    });
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::post('/user/profile', [AuthController::class, 'updateProfile']);
    Route::post('/user/change-password', [AuthController::class, 'changePassword']);
    Route::post('/update-token', [AuthController::class, 'updateToken']);
    Route::post('/fcm-token', [FcmController::class, 'updateToken']);
    Route::post('/payment/initiate', [PaymentController::class, 'initiatePayment']);

    // --- NEW: User submitting a manual payment request ---
    Route::post('/payment/manual-request', [PaymentRequestController::class, 'store']);

    Route::post('/gift/purchase', [GiftPurchaseController::class, 'store']);


    // --- User-specific data (Playlists, Bookmarks, Progress) ---
    Route::apiResource('playlists', PlaylistController::class);

    // Manages the items within a specific playlist
    Route::post('playlists/{playlist}/items', [PlaylistItemController::class, 'store'])->name('playlists.items.store');
    Route::delete('playlists/{playlist}/items/{playlistItem}', [PlaylistItemController::class, 'destroy'])->name('playlists.items.destroy');
    
    // Bonus: A route to handle reordering multiple items at once
    Route::patch('playlists/{playlist}/items/reorder', [PlaylistItemController::class, 'reorder'])->name('playlists.items.reorder');

   Route::get('/bookmarks', [BookmarkController::class, 'index']);
    Route::post('/bookmarks/toggle', [BookmarkController::class, 'toggle']);

    Route::post('/progress/start', [ProgressController::class, 'startTracking']);
    Route::post('/progress/update', [ProgressController::class, 'updateProgress']);
    Route::get('/progress/my-learning', [ProgressController::class, 'getMyLearning']);

    // --- Questions Submission ---
    Route::post('/questions', [QuestionController::class, 'store']);
});


// ========================================================
// === 4. SHARED AUTHENTICATED ROUTES (READ-ONLY)
// ========================================================
// These READ-ONLY routes can be accessed by EITHER a standard user OR an admin.
Route::middleware(['auth:sanctum,admin', EnsureFrontendRequestsAreStateful::class])->group(function () {
    // --- Content Fetching (GET requests) ---
    Route::get('/courses', [CourseController::class, 'index']);
    Route::get('/courses/{id}', [CourseController::class, 'show']);
    Route::get('/courses/{courseId}/episodes', [EpisodeController::class, 'index']);
    Route::get('/courses/episodes/{episodeId}', [EpisodeController::class, 'showById']);

    Route::get('/stories', [StoryController::class, 'index']);
    Route::get('/stories/{story}', [StoryController::class, 'show']);
    Route::get('/stories/{story}/episodes', [StoryEpisodeController::class, 'index']);
    Route::get('/story-episodes', [StoryEpisodeController::class, 'getAllEpisodes']);
    Route::get('/story-episodes/{storyEpisode}', [StoryEpisodeController::class, 'showEpisode']);

    Route::get('/surahs', [SurahController::class, 'index']);
    Route::get('/surahs/{id}', [SurahController::class, 'show']);
    Route::get('/surahs/{surah}/episodes', [SurahEpisodeController::class, 'index']);
    Route::get('/surahs/{surah}/episodes/{episode}', [SurahEpisodeController::class, 'show']);

    Route::get('/deeper-looks', [DeeperLookController::class, 'index']);
    Route::get('/deeper-looks/{id}', [DeeperLookController::class, 'show']);
    Route::get('/deeper-looks/{deeperLook}/episodes', [DeeperLookEpisodeController::class, 'index']);
    Route::get('/deeper-looks/{deeperLook}/episodes/{episode}', [DeeperLookEpisodeController::class, 'show']);

    Route::get('/commentaries', [CommentaryController::class, 'index']);
    Route::get('/commentaries/{id}', [CommentaryController::class, 'show']);
    Route::get('/commentaries/{commentary}/episodes', [CommentaryEpisodeController::class, 'index']);
    Route::get('/commentaries/{commentary}/episodes/{episode}', [CommentaryEpisodeController::class, 'show']);

    // Notifications list is accessible to both
    Route::get('/notifications', [NotificationController::class, 'index']);
});   