package com.example.mening_ilovam

import android.app.Application
import com.yandex.mapkit.MapKitFactory

/**
 * Yandex MapKit API kalitini ILOVA ishga tushishining ENG ERTA nuqtasida
 * (Application.onCreate) o'rnatamiz. Bu MainActivity.configureFlutterEngine'dan
 * ham oldin ishlaydi — shu sabab plugin `MapKitFactory.initialize()` chaqirsa
 * (oldindan-isitilgan/implicit engine holatida u erta bo'lishi mumkin), kalit
 * allaqachon o'rnatilgan bo'ladi. Aks holda xarita tile'lari yuklanmay,
 * "katak-katak" bo'sh xarita chiqadi.
 */
class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        MapKitFactory.setApiKey("b5f5440f-4907-4f18-91a2-f31397294f45")
    }
}
