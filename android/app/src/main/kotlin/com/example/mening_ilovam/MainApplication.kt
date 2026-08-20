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
 *
 * Kalit `BuildConfig` orqali keladi (build.gradle.kts → local.properties yoki
 * `-Pyandex.mapkit.key=...`), shuning uchun repoda saqlanmaydi.
 */
class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        val key = BuildConfig.YANDEX_MAPKIT_KEY
        if (key.isNotEmpty()) {
            MapKitFactory.setApiKey(key)
        }

        MapKitFactory.setLocale(mapKitLocale())
    }

    /**
     * Xarita yozuvlari va geokoder javoblari ilova tiliga mos bo'lishi kerak.
     * Til Flutter tomonda `shared_preferences`ga `alix_locale` kaliti bilan
     * yoziladi (`uz` yoki `ru`) — MapKit locale'i esa Application.onCreate'da,
     * ya'ni Flutter ishga tushishidan oldin kerak, shuning uchun qiymat
     * to'g'ridan-to'g'ri o'sha SharedPreferences faylidan o'qiladi.
     *
     * Til hali tanlanmagan bo'lsa `uz_UZ` — ilovaning asosiy tili.
     */
    private fun mapKitLocale(): String {
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)

        // shared_preferences plaginida kalitlar `flutter.` prefiksi bilan saqlanadi.
        return when (prefs.getString("flutter.alix_locale", null)) {
            "ru" -> "ru_RU"
            else -> "uz_UZ"
        }
    }
}
