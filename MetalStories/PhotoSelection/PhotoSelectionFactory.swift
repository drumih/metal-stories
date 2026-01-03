import UIKit

enum EntryFactory {
    static func getEntryViewController() -> UIViewController {
        let viewController = EntryViewController()
        let presenter = EntryPresenter(view: viewController)
        viewController.presenter = presenter
        return viewController
    }
}
