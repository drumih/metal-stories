import Foundation
import UIKit

enum StoriesViewControllerFactory {

    // MARK: Internal

    static func getViewController(
        imageData: Data,
        renderPassType: RenderPassType,
    ) throws -> UIViewController {
        let gpu = try GPU()
        /// Total number of filters: 1 "Original" + 8 color grading effects
        let availableFiltersCount: Int16 = 9

        let renderingView = RenderingView(device: gpu.device)
        let drawablesPixelFormat = renderingView.drawablesPixelFormat
        let renderPassFactory = RenderPassFactory(
            device: gpu.device,
            drawablesPixelFormat: drawablesPixelFormat,
            renderPassType: renderPassType,
            availableFilterCount: availableFiltersCount,
        )
        let scene = Scene(
            canvasAspectRatio: 16.0 / 9.0,
            imageAspectModeType: .automatic(threshold: 4.0 / 5.0),
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
            titleString: title,
            availableFiltersCount: availableFiltersCount,
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
        case .directWithDepth:
            "Direct"
        }
    }
}
