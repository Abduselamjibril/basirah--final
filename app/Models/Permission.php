<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Permission extends Model
{
    use HasFactory;

    protected $fillable = ['name', 'display_name'];

    public function adminUsers()
    {
        return $this->belongsToMany(AdminUser::class, 'permission_admin_user');
    }
}