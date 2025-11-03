<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Password Reset</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 20px auto; padding: 20px; border: 1px solid #ddd; border-radius: 5px; }
        h1 { color: #009B77; }
        .otp-code { font-size: 24px; font-weight: bold; color: #002147; letter-spacing: 2px; }
        .footer { font-size: 0.9em; color: #777; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Basirah App - Password Reset Request</h1>
        <p>Hello,</p>
        <p>You requested a password reset. Please use the following 6-digit code to complete the process:</p>
        <p class="otp-code">{{ $otp }}</p>
        <p>This code is valid for <strong>10 minutes</strong>.</p>
        <hr>
        <p class="footer">If you did not request this password reset, you can safely ignore this email. Your account is secure.</p>
    </div>
</body>
</html>
