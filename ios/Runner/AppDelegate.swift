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

    // Xarita yozuvlari ilova tiliga mos bo'lsin. Til Flutter tomonda
    // `shared_preferences`ga yoziladi; u yerda hali qiymat bo'lmasa — uz_UZ.
    let saved = UserDefaults.standard.string(forKey: "flutter.alix_locale")
    YMKMapKit.setLocale(saved == "ru" ? "ru_RU" : "uz_UZ")

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
