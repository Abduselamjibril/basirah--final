<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class GiftPurchase extends Model
{
    use HasFactory;

    protected $fillable = [
        'gifter_user_id',
        'plan_duration',
        'quantity_purchased',
        'quantity_remaining',
        'total_price',
        'transaction_id',
        'status',
    ];

    public function gifter(): BelongsTo
    {
        return $this->belongsTo(User::class, 'gifter_user_id');
    }
}