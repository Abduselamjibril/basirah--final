<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Payout extends Model
{
    use HasFactory;

    protected $fillable = [
        'amount_paid',
        'requested_by_admin_id',
        'reviewed_by_admin_id',
        'status',
        'requested_at',
        'reviewed_at',
    ];
    
    // Relationship to get the name of the admin who requested
    public function requester(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'requested_by_admin_id');
    }

    // Relationship to get the name of the admin who reviewed
    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'reviewed_by_admin_id');
    }
}