import simd

// MARK: - Clamp
@inlinable
func clamp<T: Comparable>(value: T, min minValue: T, max maxValue: T) -> T {
    max(minValue, min(value, maxValue))
}

@inlinable
func clamp01<T: BinaryFloatingPoint>(_ value: T) -> T {
    min(T(1), max(T.zero, value))
}

@inlinable
func clamp01<T: BinaryInteger>(_ value: T) -> T {
    min(T(1), max(T.zero, value))
}
