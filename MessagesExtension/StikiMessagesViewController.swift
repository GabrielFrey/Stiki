import Messages
import StikiCore
import UIKit

/// iMessage extension host: pack switcher plus a sticker browser.
///
/// The extension never opens SwiftData. It reads `catalog.json` and rendered
/// PNG/GIF files from the App Group, which the main app rewrites after every
/// library change.
final class StikiMessagesViewController: MSMessagesAppViewController {
    private let packControl = UISegmentedControl(items: [])
    private let browser: StikiStickerBrowserViewController
    private var catalog: SharedStickerCatalog = .empty
    private let fileManager = FileManager.default

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        browser = StikiStickerBrowserViewController(stickerSize: .regular)
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        browser = StikiStickerBrowserViewController(stickerSize: .regular)
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        packControl.addTarget(self, action: #selector(packChanged), for: .valueChanged)
        packControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(packControl)

        addChild(browser)
        browser.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(browser.view)
        browser.didMove(toParent: self)

        NSLayoutConstraint.activate([
            packControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            packControl.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            packControl.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            browser.view.topAnchor.constraint(equalTo: packControl.bottomAnchor, constant: 8),
            browser.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            browser.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            browser.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        reloadCatalog()
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        reloadCatalog()
    }

    private var containerURL: URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: SharedPaths.appGroupIdentifier)
    }

    private func reloadCatalog() {
        guard let container = containerURL else {
            catalog = .empty
            browser.stickers = []
            packControl.removeAllSegments()
            return
        }
        let catalogURL = container.appending(path: SharedPaths.catalogFileName, directoryHint: .notDirectory)
        if let data = try? Data(contentsOf: catalogURL),
           let decoded = try? SharedStickerCatalog.decoded(from: data) {
            catalog = decoded
        } else {
            catalog = .empty
        }

        packControl.removeAllSegments()
        for (index, pack) in catalog.packs.enumerated() {
            packControl.insertSegment(withTitle: pack.name, at: index, animated: false)
        }
        if packControl.numberOfSegments > 0 {
            packControl.selectedSegmentIndex = 0
        }
        showPack(at: 0)
    }

    @objc
    private func packChanged() {
        showPack(at: packControl.selectedSegmentIndex)
    }

    private func showPack(at index: Int) {
        guard catalog.packs.indices.contains(index), let container = containerURL else {
            browser.stickers = []
            browser.reload()
            return
        }
        let rendered = container.appending(path: SharedPaths.renderedDirectory, directoryHint: .isDirectory)
        let pack = catalog.packs[index]
        browser.stickers = pack.stickers.compactMap { item in
            let url = rendered.appending(path: item.fileName, directoryHint: .notDirectory)
            guard fileManager.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
            return try? MSSticker(
                contentsOfFileURL: url,
                localizedDescription: item.resolvedAccessibilityLabel
            )
        }
        browser.reload()
    }
}

/// Browser that Messages queries for stickers.
final class StikiStickerBrowserViewController: MSStickerBrowserViewController {
    var stickers: [MSSticker] = []

    func reload() {
        stickerBrowserView.reloadData()
    }

    override func numberOfStickers(in stickerBrowserView: MSStickerBrowserView) -> Int {
        stickers.count
    }

    override func stickerBrowserView(_ stickerBrowserView: MSStickerBrowserView, stickerAt index: Int) -> MSSticker {
        stickers[index]
    }
}
