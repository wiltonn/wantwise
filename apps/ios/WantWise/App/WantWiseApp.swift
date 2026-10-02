import SwiftData
import SwiftUI
import UserNotifications
import WantWiseCore

@main
struct WantWiseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let environment = AppEnvironment.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment.store)
                .environment(environment.router)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
        .modelContainer(environment.container)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Must be set before launch finishes so a tap on a reminder that launched the app is delivered.
        UNUserNotificationCenter.current().delegate = AppEnvironment.shared.notificationDelegate
        return true
    }
}

/// Builds the app's long-lived objects once.
///
/// Launch arguments (DEBUG builds only; used by UI tests and the Cloud Mac runbook):
/// - `-WantWiseInMemory`     use a throwaway in-memory store
/// - `-WantWiseResetData`    delete the on-disk store and images before launch
/// - `-WantWiseSampleData`   load sample Wants if the store is empty
/// - `-WantWiseNoReminders`  never schedule reminders or ask for notification permission
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let container: ModelContainer
    let store: WantStore
    let router: AppRouter
    let notificationDelegate: NotificationDelegate

    private init() {
        let arguments = ProcessInfo.processInfo.arguments
        var inMemory = false
        var remindersEnabled = true

        #if DEBUG
        inMemory = arguments.contains("-WantWiseInMemory")
        remindersEnabled = !arguments.contains("-WantWiseNoReminders")
        if arguments.contains("-WantWiseResetData") { Persistence.destroyLocalData() }
        #endif

        do {
            try AppPaths.ensureRoot()
            container = try Persistence.makeContainer(url: inMemory ? nil : AppPaths.storeURL)
        } catch {
            // No recovery path in V1: a store that can't open is a bug to fix, not to hide.
            fatalError("WantWise could not open its data store: \(error)")
        }

        let images = ImageFileStore(directory: AppPaths.imagesDirectory, encode: ImageEncoding.downsampledJPEG)
        let reminders = ReminderScheduler(center: SystemNotificationCenter(), isEnabled: remindersEnabled)
        store = WantStore(context: container.mainContext, images: images, reminders: reminders)
        router = AppRouter()
        notificationDelegate = NotificationDelegate(router: router)

        #if DEBUG
        if arguments.contains("-WantWiseSampleData") {
            SampleData.loadIfEmpty(into: store)
        }
        #endif
    }
}
