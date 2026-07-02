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
        MapKitFactory.setApiKey("d2c652fa-693a-4f40-87d5-3d604ee5f87b")
    }
}
