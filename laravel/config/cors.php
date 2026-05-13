<?php

/**
 * Bu fayl Flutter repodagi namuna: o‘z Laravel API loyihangizdagi `config/cors.php` bilan almashtiring
 * yoki faqat `allowed_origins_patterns` qismini merge qiling.
 *
 * CORS eslatmasi: Flutter web `http://localhost:<flutter-port>`, API `http://localhost:8000` — ikki xil origin
 * (port farqi), shuning uchun `allowed_origins_patterns` (localhost / 127.0.0.1 / [::1] + port) baribir kerak.
 * Wildcard `http://localhost:*` origin sifatida ishlamaydi — regex ishlatiladi.
 *
 * O‘zgartirgach: `php artisan config:clear`
 * Server: `php artisan serve --host=0.0.0.0 --port=8000`
 */

return [

    'paths' => ['api/*', 'sanctum/csrf-cookie'],

    'allowed_methods' => ['*'],

    /*
     | Aniq originlar (prod). Mahalliy uchun quyidagi patternlar yetarli bo‘lishi mumkin.
     */
    'allowed_origins' => array_values(array_filter(array_map(
        'trim',
        explode(',', (string) env('CORS_ALLOWED_ORIGINS', ''))
    ))),

    /*
     | Mahalliy Flutter web / boshqa dev frontend — istalgan port.
     | Bearer-token API uchun odatda `supports_credentials` false bo‘lsa kifoya.
     | Cookie/Sanctum SPA bo‘lsa `true` qiling va `allowed_origins`ni aniq domain bilan to‘ldiring.
     */
    'allowed_origins_patterns' => [
        '#^http://localhost(:[0-9]+)?$#i',
        '#^http://127\.0\.0\.1(:[0-9]+)?$#i',
        '#^http://\[::1\](:[0-9]+)?$#i',
    ],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 0,

    'supports_credentials' => (bool) env('CORS_SUPPORTS_CREDENTIALS', false),

];
