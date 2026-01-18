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
    
    enum RendererError: LocalizedError {
        case failedToRenderOffscreenImage
    }

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

    private static let minOffscreenTextureSize = SIMD2<Float>(128, 128)

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

    func draw(in view: MTKView) {
        let drawableSize = SIMD2<Float>(
            Float(view.drawableSize.width),
            Float(view.drawableSize.height),
        )

        guard
            let input = scene.getRenderPassInput(renderingViewSize: drawableSize, isForSaving: false),
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

    // MARK: Internal

    func renderImageToOffscreenTexture(
        size: CGSize,
        colorSpace: CGColorSpace,
    ) throws -> CGImage {
        let offscreenTextureSize = SIMD2<Float>(Float(size.width), Float(size.height))
        guard
            let input = scene.getRenderPassInput(renderingViewSize: offscreenTextureSize, isForSaving: true),
            let commandBuffer = gpu.processingCommandQueue.makeCommandBuffer()
        else {
            throw RendererError.failedToRenderOffscreenImage
        }

        let offscreenTexture = try getOffscreenTexture(for: offscreenTextureSize)

        let offscreenRenderPass = try renderPassFactory.createNewRenderPass()
        offscreenRenderPass.resize(size: size)

        let renderPassDescriptor = getOffscreenRenderPassDescriptor(texture: offscreenTexture)
        offscreenRenderPass.draw(
            commandBuffer: commandBuffer,
            renderPassDescriptor: renderPassDescriptor,
            input: input,
        )

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return try MetalTextureToCGImage.getCGImage(
            from: offscreenTexture,
            colorSpace: colorSpace,
        )
    }

    // MARK: Private

    private func getOffscreenTexture(for size: SIMD2<Float>) throws -> MTLTexture {
        guard
            size.x >= Self.minOffscreenTextureSize.x,
            size.y >= Self.minOffscreenTextureSize.y
        else {
            throw RendererError.failedToRenderOffscreenImage
        }

        return try TextureHelper.getTexture(
            device: gpu.device,
            pixelFormat: .bgra8Unorm,
            width: Int(size.x),
            height: Int(size.y),
            storageMode: .shared,
            usage: [.renderTarget, .shaderRead],
        )
    }

    private func getOffscreenRenderPassDescriptor(texture: MTLTexture) -> MTLRenderPassDescriptor {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        return renderPassDescriptor
    }
}

// MARK: - RendererError + errorDescription

extension Renderer.RendererError {

    var errorDescription: String? {
        switch self {
        case .failedToRenderOffscreenImage:
            "Failed to render offscreen image"
        }
    }
}
