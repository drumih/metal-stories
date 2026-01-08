import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options _: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = PhotoSelectionViewController()
        window?.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_: UIScene) {
        // --
    }

    func sceneDidBecomeActive(_: UIScene) {
        // --
    }

    func sceneWillResignActive(_: UIScene) {
        // --
    }

    func sceneWillEnterForeground(_: UIScene) {
        // --
    }

    func sceneDidEnterBackground(_: UIScene) {
        // --
    }
}
