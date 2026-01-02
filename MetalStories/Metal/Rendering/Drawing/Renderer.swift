import MetalKit

protocol OffscreenRenderer: AnyObject {
    func renderImageToOffscreenTexture(
        size: CGSize,
        colorSpace: CGColorSpace
    ) throws -> CGImage
}

final class Renderer {

    private let gpu: GPU
    private let scene: any SceneOutput
    private let renderPass: any RenderPass

    init(
        gpu: GPU,
        scene: any SceneOutput,
        renderPass: any RenderPass
    ) {
        self.gpu = gpu
        self.scene = scene
        self.renderPass = renderPass
    }
}

extension Renderer: OffscreenRenderer {
    
    // TODO: clean up this code later
    func renderImageToOffscreenTexture(
        size: CGSize,
        colorSpace: CGColorSpace
    ) throws -> CGImage {
        let targetPixelFormat = MTLPixelFormat.bgra8Unorm
        guard
            let input = scene.getRenderPassInput(renderingViewSize: size.asFloat2)
        else {
            throw NSError() // TODO: throw normal error
        }
        
        let offscreenRenderPass = try renderPass.copy()
        offscreenRenderPass.resize(size: size)
        let offscreenTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: targetPixelFormat,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        offscreenTextureDescriptor.usage = [.renderTarget, .shaderRead]
        offscreenTextureDescriptor.storageMode = .shared
        
        guard let offscreenTexture = gpu.device.makeTexture(descriptor: offscreenTextureDescriptor) else {
            throw NSError() // TODO: throw normal error
        }
    
        guard let commandBuffer = gpu.processingCommandQueue.makeCommandBuffer() else {
            throw NSError()
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = offscreenTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        offscreenRenderPass.draw(
            commandBuffer: commandBuffer,
            descriptor: renderPassDescriptor,
            input: input
        )

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return try CGImageFromMetalTexture.getCGImage(
            from: offscreenTexture,
            colorSpace: colorSpace
        )
    }
}

extension Renderer: RenderingViewDelegate {

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderPass.resize(size: size)
    }

    func draw(in view: MTKView) {

        guard
            let input = scene.getRenderPassInput(renderingViewSize: view.drawableSize.asFloat2),
            let commandBuffer = gpu.renderingCommandQueue.makeCommandBuffer(),
            let descriptor = view.currentRenderPassDescriptor
        else {
            return
        }

        renderPass.draw(
            commandBuffer: commandBuffer,
            descriptor: descriptor,
            input: input
        )

        guard let drawable = view.currentDrawable else {
            return
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

