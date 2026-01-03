import UIKit

enum PhotoSelectionFactory {
    static func getPhotoSelectionViewController() -> UIViewController {
        
        let viewController = PhotoSelectionViewController()
        let presenter = PhotoSelectionPresenter(view: viewController)
        viewController.presenter = presenter
        return viewController
    }
}
