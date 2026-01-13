import Metal

protocol RenderPass: AnyObject {
    func resize(size: CGSize)
    func draw(
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor,
        input: RenderPassInput,
    )
}
