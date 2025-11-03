<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use Carbon\Carbon; // Import Carbon for date handling

// --- ADDED: Imports for the new relationship ---
use App\Models\Playlist;
use Illuminate\Database\Eloquent\Relations\HasMany;
// --- END ADDED ---

class User extends Authenticatable
{
    use HasApiTokens, Notifiable, HasFactory;

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'first_name',
        'last_name',
        'email', // ADDED
        'phone_number',
        'password',
        'is_subscribed',
        'subscription_expires_at',
        'otp_code', // ADDED
        'otp_expires_at', // ADDED
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var array<int, string>
     */
    protected $hidden = [
        'password',
        'remember_token',
        'otp_code', // ADDED (so it's not sent in API responses)
        'otp_expires_at', // ADDED
    ];

    /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'password' => 'hashed',
        'is_subscribed' => 'boolean',
        'subscription_expires_at' => 'datetime',
        'otp_expires_at' => 'datetime', // ADDED
    ];

    // --- ADDED: The missing Playlist Relationship ---
    /**
     * Get all of the playlists for the User.
     */
    public function playlists(): HasMany
    {
        return $this->hasMany(Playlist::class);
    }
    // --- END ADDED ---

    public function fullName()
    {
        return "{$this->first_name} {$this->last_name}";
    }

    public function activeDevices()
    {
        return $this->hasMany(ActiveDevice::class);
    }

    /**
     * Check if the user has an active and valid subscription.
     *
     * @return bool
     */
    public function isSubscribedAndActive(): bool
    {
        // User must be marked as subscribed AND the expiry date must exist and be in the future.
        return $this->is_subscribed && $this->subscription_expires_at && $this->subscription_expires_at->isFuture();
    }
}