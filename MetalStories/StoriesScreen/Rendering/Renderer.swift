import MetalKit

// MARK: - RendererError

enum RendererError: LocalizedError {
    case failedToGetRenderPassInput
    case failedToCreateOffscreenTexture
    case failedToCreateCommandBuffer

    var errorDescription: String? {
        switch self {
        case .failedToGetRenderPassInput:
            "Unable to prepare the image for rendering. Please try again."
        case .failedToCreateOffscreenTexture:
            "Unable to create output texture. The device may be low on memory."
        case .failedToCreateCommandBuffer:
            "Unable to initialize GPU rendering. Please try again."
        }
    }
}

// MARK: - OffscreenRenderer

protocol OffscreenRenderer: AnyObject {
    func renderImageToOffscreenTexture(
        size: CGSize,
        colorSpace: CGColorSpace,
    ) throws -> CGImage
}

// MARK: - Renderer

final class Renderer {

    // MARK: Lifecycle

    init(
        gpu: GPU,
        scene: any SceneOutput,
        renderPassFactory: RenderPassFactory,
    ) throws {
        self.gpu = gpu
        self.scene = scene
        self.renderPassFactory = renderPassFactory
        renderPass = try renderPassFactory.createNewRenderPass()
    }

    // MARK: Private

    private let gpu: GPU
    private let scene: any SceneOutput
    private let renderPassFactory: RenderPassFactory
    private let renderPass: any RenderPass

}

// MARK: RenderingViewDelegate

extension Renderer: RenderingViewDelegate {

    func mtkView(_: MTKView, drawableSizeWillChange size: CGSize) {
        renderPass.resize(size: size)
    }

    // TODO: do I need three texture here to reuse?
    func draw(in view: MTKView) {
        let drawableSize = SIMD2<Float>(
            Float(view.drawableSize.width),
            Float(view.drawableSize.height),
        )

        guard
            let input = scene.getRenderPassInput(renderingViewSize: drawableSize),
            let commandBuffer = gpu.renderingCommandQueue.makeCommandBuffer(),
            let descriptor = view.currentRenderPassDescriptor
        else {
            return
        }

        renderPass.draw(
            commandBuffer: commandBuffer,
            renderPassDescriptor: descriptor,
            input: input,
        )

        guard let drawable = view.currentDrawable else { return }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: OffscreenRenderer

extension Renderer: OffscreenRenderer {

    // TODO: clean up this code later
    func renderImageToOffscreenTexture(
        size: CGSize,
        colorSpace: CGColorSpace,
    ) throws -> CGImage {
        let targetPixelFormat = MTLPixelFormat.bgra8Unorm
        let renderingViewSize = SIMD2<Float>(Float(size.width), Float(size.height))
        guard
            let input = scene.getRenderPassInput(renderingViewSize: renderingViewSize)
        else {
            throw RendererError.failedToGetRenderPassInput
        }

        let offscreenRenderPass = try renderPassFactory.createNewRenderPass()
        offscreenRenderPass.resize(size: size)
        let offscreenTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: targetPixelFormat,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false,
        )
        offscreenTextureDescriptor.usage = [.renderTarget, .shaderRead]
        offscreenTextureDescriptor.storageMode = .shared

        guard let offscreenTexture = gpu.device.makeTexture(descriptor: offscreenTextureDescriptor) else {
            throw RendererError.failedToCreateOffscreenTexture
        }

        guard let commandBuffer = gpu.processingCommandQueue.makeCommandBuffer() else {
            throw RendererError.failedToCreateCommandBuffer
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = offscreenTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        offscreenRenderPass.draw(
            commandBuffer: commandBuffer,
            renderPassDescriptor: renderPassDescriptor,
            input: input,
        )

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return try CGImageFromMetalTexture.getCGImage(
            from: offscreenTexture,
            colorSpace: colorSpace,
        )
    }
}
