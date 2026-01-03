import MetalKit

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
        renderPass: any RenderPass,
    ) {
        self.gpu = gpu
        self.scene = scene
        self.renderPass = renderPass
    }

    // MARK: Private

    private let gpu: GPU
    private let scene: any SceneOutput
    private let renderPass: any RenderPass

}

// MARK: - RendererError

enum RendererError: Error {
    case failedToGetRenderPassInput
    case failedToCreateOffscreenTexture
}

// MARK: OffscreenRenderer

extension Renderer: OffscreenRenderer {

    // TODO: do I need three texture here to reuse?
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

        let offscreenRenderPass = try renderPass.copy()
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
            throw NSError()
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

// MARK: RenderingViewDelegate

extension Renderer: RenderingViewDelegate {

    func mtkView(_: MTKView, drawableSizeWillChange size: CGSize) {
        renderPass.resize(size: size)
    }

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
