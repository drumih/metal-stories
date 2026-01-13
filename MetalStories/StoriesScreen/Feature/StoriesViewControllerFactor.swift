import Foundation
import UIKit

enum StoriesViewControllerFactor {

    // MARK: Internal

    static func getViewController(
        imageData: Data,
        renderPassType: RenderPassType,
    ) throws -> UIViewController {
        let gpu = try GPU()

        let renderingView = RenderingView(device: gpu.device)
        let drawablesPixelFormat = renderingView.drawablesPixelFormat
        let renderPassFactory = RenderPassFactory(
            device: gpu.device,
            drawablesPixelFormat: drawablesPixelFormat,
            renderPassType: renderPassType,
        )
        let scene = Scene(
            canvasAspectRatio: 16.0 / 9.0,
            imageAspectModeType: .automatic(threshold: 4.0 / 5.0)
        )
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
