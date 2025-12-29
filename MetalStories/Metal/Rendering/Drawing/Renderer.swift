import MetalKit

protocol OffscreenRenderer: AnyObject {
    func renderImageToOffscreenTexture(
        size: SIMD2<Float>,
        colorSpace: CGColorSpace,
        flipped: Bool
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
    func renderImageToOffscreenTexture(
        size: SIMD2<Float>,
        colorSpace: CGColorSpace,
        flipped: Bool
    ) throws -> CGImage {
        fatalError("not implemented yet")
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

