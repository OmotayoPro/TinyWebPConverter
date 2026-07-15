/// PRD §6.2. Never persisted between launches — every control resets to these defaults on open.
public struct ConversionSettings: Sendable, Equatable {
    /// 0...100. Ignored when `lossless` is true.
    public var quality: Int
    public var lossless: Bool
    public var resize: ResizeOption
    /// When false, EXIF/GPS/camera metadata is stripped from the output.
    public var keepMetadata: Bool

    public init(
        quality: Int = 80,
        lossless: Bool = false,
        resize: ResizeOption = .none,
        keepMetadata: Bool = true
    ) {
        self.quality = min(max(quality, 0), 100)
        self.lossless = lossless
        self.resize = resize
        self.keepMetadata = keepMetadata
    }
}
