import MetalKit

// MARK: - RenderingViewDelegate

protocol RenderingViewDelegate: AnyObject {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)
    func draw(in view: MTKView)
}

// MARK: - RenderingView

final class RenderingView: UIView {

    // MARK: Lifecycle

    init(device: MTLDevice) {
        metalView = MTKView(frame: .zero, device: device)
        super.init(frame: .zero)
        metalView.delegate = self
        metalView.clearColor = .init(red: 0, green: 0, blue: 0, alpha: 1)
        addSubview(metalView)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Internal

    weak var delegate: (any RenderingViewDelegate)?

    var drawablesPixelFormat: MTLPixelFormat { metalView.colorPixelFormat }

    override func layoutSubviews() {
        super.layoutSubviews()
        metalView.frame = bounds
    }

    // MARK: Private

    private let metalView: MTKView

}

// MARK: MTKViewDelegate

extension RenderingView: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        delegate?.mtkView(view, drawableSizeWillChange: size)
    }

    func draw(in view: MTKView) {
        delegate?.draw(in: view)
    }
}
