<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Tymon\JWTAuth\Contracts\JWTSubject;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

class AdminUser extends Authenticatable implements JWTSubject
{
    protected $table = 'admin_users';

    protected $fillable = [
        'name',
        'email',
        'password',
        'is_super_admin',
    ];

    protected $hidden = [
        'password',
    ];

    protected $casts = [
        'is_super_admin' => 'boolean',
    ];

    // --- THIS IS THE CRITICAL FIX ---
    // This line tells Laravel to ALWAYS eager-load the 'permissions' relationship
    // every single time an AdminUser is retrieved from the database.
    protected $with = ['permissions'];
    // --- END OF FIX ---

    public function permissions(): BelongsToMany
    {
        return $this->belongsToMany(Permission::class, 'permission_admin_user', 'admin_user_id', 'permission_id');
    }

    public function hasPermissionTo(string $permissionName): bool
    {
        return $this->permissions->contains('name', $permissionName);
    }

    public function getJWTIdentifier()
    {
        return $this->getKey();
    }

    public function getJWTCustomClaims()
    {
        // Now that permissions are always loaded thanks to the $with property,
        // this method will always have access to them.
        $permissionNames = $this->permissions->pluck('name');

        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'is_super_admin' => $this->is_super_admin,
            'permissions' => $permissionNames,
        ];
    }
}