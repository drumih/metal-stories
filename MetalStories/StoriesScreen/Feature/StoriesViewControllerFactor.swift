import Foundation
import UIKit

enum StoriesViewControllerFactor {

    // MARK: Internal

    static func getViewController(
        imageData: Data,
        renderPassType: RenderPassType,
    ) throws -> UIViewController {
        let gpu = GPU.default

        let renderingView = RenderingView(device: gpu.device)
        let pixelFormat = renderingView.pixelFormat
        let renderPassFactory = RenderPassFactory(
            device: gpu.device,
            pixelFormat: pixelFormat,
            renderPassType: renderPassType,
        )
        let scene = Scene()
        let renderer = try Renderer(
            gpu: gpu,
            scene: scene,
            renderPassFactory: renderPassFactory,
        )
        renderingView.delegate = renderer

        let title = titleForRenderPassType(renderPassType)
        return StoriesViewController(
            gpu: gpu,
            renderingView: renderingView,
            sceneInput: scene,
            offscreenRenderer: renderer,
            inputImageData: imageData,
            title: title,
        )
    }

    // MARK: Private

    private static func titleForRenderPassType(_ type: RenderPassType) -> String {
        switch type {
        case .simple:
            "Simple"
        case .withIntermediateTexture:
            "Intermediate"
        case .tileMemory:
            "Tile"
        }
    }
}
