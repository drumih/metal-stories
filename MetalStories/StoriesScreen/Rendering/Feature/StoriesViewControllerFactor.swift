import Foundation
import UIKit

enum StoriesViewControllerFactor {
    static func getViewController(
        imageData: Data,
        renderPassType: RenderPassType,
    ) throws -> UIViewController {

        let gpu = GPU.default

        let renderingView = RenderingView(device: gpu.device)
        let renderPass = try RenderPassFactory.getRenderPass(
            gpu: gpu,
            pixelFormat: renderingView.pixelFormat,
            forRenderPassType: renderPassType
        )
        let scene = Scene()
        let renderer = Renderer(
            gpu: gpu,
            scene: scene,
            renderPass: renderPass
        )
        renderingView.delegate = renderer

        return StoriesViewController(
            gpu: gpu,
            renderingView: renderingView,
            sceneInput: scene,
            offscreenRenderer: renderer,
            imageData: imageData
        )
    }
}
