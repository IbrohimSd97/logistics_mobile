import Flutter
import UIKit
import YandexMapsMobile

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Yandex MapKit kaliti — xarita ishlatilishidan oldin o'rnatilishi shart.
    // Kalit Info.plist'dagi `YandexMapKitApiKey` dan olinadi (uni xcconfig
    // to'ldiradi), shuning uchun repoda ochiq saqlanmaydi.
    if let key = Bundle.main.object(forInfoDictionaryKey: "YandexMapKitApiKey") as? String,
       !key.isEmpty {
      YMKMapKit.setApiKey(key)
    }

    // Ilova tili Flutter tomonda `shared_preferences`ga yoziladi. Hali
    // tanlanmagan bo'lsa — iOS ruxsat so'rovlari uchun tanlagan til
    // ({ru,uz}.lproj); Flutter ham xuddi shu qoida bilan tanlaydi.
    let saved = UserDefaults.standard.string(forKey: "flutter.alix_locale")
    let lang = saved ?? (Bundle.main.preferredLocalizations.first == "uz" ? "uz" : "ru")

    // Foydalanuvchi ilovada tilni almashtirgan bo'lsa, ruxsat so'rovlari ham
    // shu tilda chiqsin (iOS uni keyingi ishga tushirishda qo'llaydi).
    if let saved, UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first != saved {
      UserDefaults.standard.set([saved], forKey: "AppleLanguages")
    }

    // Xarita yozuvlari ilova tiliga mos bo'lsin.
    YMKMapKit.setLocale(lang == "ru" ? "ru_RU" : "uz_UZ")

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
