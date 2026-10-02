import SwiftUI
import UIKit

/// Share Extension entry point (Milestone 2 skeleton): Screenshot → Share → WantWise.
///
/// Apple constraints this design follows (CAPTURE.md):
/// - The extension can't open the main app, so it completes the whole capture itself.
/// - It runs with a much lower memory limit, so images are downsampled straight from file with ImageIO.
/// - It shares data with the app only through the App Group inbox; the app imports on next foreground.
final class ShareViewController: UIViewController {
    private let model = CaptureModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Theme.background)

        model.onFinish = { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
        model.onCancel = { [weak self] in
            self?.extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
        }

        let host = UIHostingController(rootView: CaptureView(model: model))
        host.view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.didMove(toParent: self)

        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        Task { await model.load(from: items) }
    }
}
