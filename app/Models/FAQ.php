<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * 
 *
 * @property int $id
 * @property string $question
 * @property string $answer
 * @property \Illuminate\Support\Carbon|null $created_at
 * @property \Illuminate\Support\Carbon|null $updated_at
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FAQ newModelQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FAQ newQuery()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FAQ query()
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FAQ whereAnswer($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FAQ whereCreatedAt($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FAQ whereId($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FAQ whereQuestion($value)
 * @method static \Illuminate\Database\Eloquent\Builder<static>|FAQ whereUpdatedAt($value)
 * @mixin \Eloquent
 */
class FAQ extends Model
{
    use HasFactory;

    protected $fillable = ['question', 'answer'];
}
