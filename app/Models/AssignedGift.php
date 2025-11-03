<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AssignedGift extends Model
{
    use HasFactory;

    protected $fillable = [
        'gift_purchase_id',
        'recipient_user_id',
        'assigned_by_admin_id',
    ];
}