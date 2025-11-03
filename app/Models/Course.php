<?php

// app/Models/Course.php

namespace App\Models;
use App\Models\Concerns\Bookmarkable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Course extends Model
{
    use HasFactory, Bookmarkable;

    protected $fillable = ['name', 'image_path', 'description', 'is_premium', 'category']; // Include category

    public function episodes()
    {
        return $this->hasMany(Episode::class);
    }
}
