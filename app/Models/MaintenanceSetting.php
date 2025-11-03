<?php

// app/Models/MaintenanceSetting.php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * 
 *
 * @property int $id
 * @property int $isMaintenance
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @method static \Illuminate\Database\Eloquent\Builder<static>|MaintenanceSetting newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|MaintenanceSetting newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|MaintenanceSetting query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|MaintenanceSetting whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|MaintenanceSetting whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|MaintenanceSetting whereIsMaintenance($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|MaintenanceSetting whereUpdatedAt($value)
 * @mixin \Eloquent
 */
class MaintenanceSetting extends Model
{
    use HasFactory;

    protected $fillable = ['isMaintenance'];
}
