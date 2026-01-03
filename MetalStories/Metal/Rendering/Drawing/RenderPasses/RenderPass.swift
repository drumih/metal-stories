import Metal

protocol RenderPass: AnyObject {
    func resize(size: CGSize)
    func draw(
        commandBuffer: MTLCommandBuffer,
        descriptor: MTLRenderPassDescriptor,
        input: RenderPassInput
    )

    // TODO: fix it somehow and use better api
    func copy() throws -> any RenderPass
}
