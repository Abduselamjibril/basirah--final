<?php

namespace App\Http\Controllers;

use App\Models\Notification;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Messaging\CloudMessage;

// We no longer need this as we are sending data-only notifications
// use Kreait\Firebase\Messaging\Notification as FirebaseNotification;

class NotificationController extends Controller
{
    protected $messaging;

    public function __construct(Messaging $messaging)
    {
        $this->messaging = $messaging;
    }

    public function createNotification(Request $request)
    {
        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'remark' => 'required|string',
            'duration' => 'required|integer|min:1',
        ]);

        $notification = Notification::create([
            'title' => $validated['title'],
            'remark' => $validated['remark'],
            'duration' => $validated['duration'],
            'status' => 'active',
        ]);

        $this->sendPushNotification($notification);

        return response()->json($notification, 201);
    }

    protected function sendPushNotification(Notification $notification)
    {
        try {
            // Get unique tokens to avoid sending to the same device multiple times
            $tokens = User::whereNotNull('fcm_token')
                         ->distinct()
                         ->pluck('fcm_token')
                         ->toArray();

            if (empty($tokens)) {
                Log::warning('No FCM tokens available for notification');
                return;
            }

            // --- THE FIX: Send a DATA-ONLY notification ---
            // The 'notification' block is removed.
            // 'title' and 'body' are now part of the 'data' payload.
            // This gives the Flutter app full control over displaying the notification.
            $message = CloudMessage::new()
                ->withData([
                    'title'           => $notification->title,
                    'body'            => $notification->remark,
                    'notification_id' => (string) $notification->id, // Best practice to send IDs as strings
                    'click_action'    => 'FLUTTER_NOTIFICATION_CLICK',
                ]);
            // --- END OF FIX ---

            $report = $this->messaging->sendMulticast($message, $tokens);
            
            Log::info("Sent notification to " . count($tokens) . " unique devices. Successes: {$report->successes()->count()}");

        } catch (\Throwable $e) {
            Log::error("Push notification failed: {$e->getMessage()}");
        }
    }

    /**
     * Get all active notifications.
     * This method first deactivates any notifications whose duration has run out.
     */
    public function index()
    {
        Notification::where('status', 'active')
            ->whereRaw('DATE_ADD(created_at, INTERVAL duration MINUTE) <= ?', [now()])
            ->update(['status' => 'inactive']);

        return response()->json(
            Notification::where('status', 'active')
                ->orderBy('created_at', 'desc')
                ->get()
        );
    }

    public function show($id)
    {
        return response()->json(
            Notification::findOrFail($id)
        );
    }

    public function update(Request $request, $id)
    {
        $notification = Notification::findOrFail($id);

        $validated = $request->validate([
            'title' => 'sometimes|string|max:255',
            'remark' => 'sometimes|string',
            'duration' => 'sometimes|integer|min:1',
        ]);

        $notification->update($validated);

        return response()->json($notification);
    }

    public function destroy($id)
    {
        Notification::findOrFail($id)->delete();
        return response()->json(null, 204);
    }
}