enum ImageAspectMode {
    case scaleAspectFit
    case scaleAspectFill
    case automatic(threshold: Float)
    
    static var `default`: ImageAspectMode {
        .automatic(threshold: 4.0 / 5.0)
    }
}
