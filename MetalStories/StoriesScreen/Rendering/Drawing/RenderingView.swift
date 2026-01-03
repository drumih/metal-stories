import MetalKit

protocol RenderingViewDelegate: AnyObject {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)
    func draw(in view: MTKView)
}

final class RenderingView: UIView {
    
    weak var delegate: (any RenderingViewDelegate)?
    var pixelFormat: MTLPixelFormat { metalView.colorPixelFormat }

    private let metalView: MTKView

    init(device: MTLDevice) {
        self.metalView = MTKView(frame: .zero, device: device)
        super.init(frame: .zero)
        self.metalView.delegate = self
        self.metalView.clearColor = .init(red: 0, green: 0, blue: 0, alpha: 1)
        addSubview(metalView)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        metalView.frame = bounds
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension RenderingView: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        delegate?.mtkView(view, drawableSizeWillChange: size)
    }

    func draw(in view: MTKView) {
        delegate?.draw(in: view)
    }
}
