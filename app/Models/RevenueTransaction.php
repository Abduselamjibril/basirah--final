<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class RevenueTransaction extends Model
{
    use HasFactory;

    protected $fillable = [
        'source_type',
        'source_id',
        'amount',
        'plan_duration',
        'processed_at',
    ];
}