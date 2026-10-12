import SwiftUI
import ImageIO
import UIKit

/// The system launch screen is static; this view plays the bundled GIF after launch.
struct StartupView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingIntro = true
    @State private var animation = BirdAnimation.load()
    @State private var startedAt = Date()

    var body: some View {
        ZStack {
            AlarmListView()
                .allowsHitTesting(!showingIntro)
                .accessibilityHidden(showingIntro)
            if showingIntro {
                ZStack {
                    Color.white.ignoresSafeArea()
                    TimelineView(.animation(paused: reduceMotion)) { context in
                        if let frame = animation.frame(at: context.date.timeIntervalSince(startedAt)) {
                            Image(uiImage: frame)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 280, height: 280)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { showingIntro = false }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("시작 화면 건너뛰기"))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { showingIntro = false }
            }
        }
        .task {
            startedAt = Date()
            guard !reduceMotion, animation.duration > 0 else {
                showingIntro = false
                return
            }
            do {
                try await Task.sleep(for: .seconds(animation.duration))
                showingIntro = false
            } catch { /* View cancellation must not restart the intro. */ }
        }
        .onChange(of: reduceMotion) { _, enabled in
            if enabled { showingIntro = false }
        }
    }
}

private struct BirdAnimation {
    var frames: [UIImage] = []
    var ends: [TimeInterval] = []
    var duration: TimeInterval { ends.last ?? 0 }

    func frame(at elapsed: TimeInterval) -> UIImage? {
        guard !frames.isEmpty else { return nil }
        let index = ends.firstIndex(where: { elapsed < $0 }) ?? (frames.count - 1)
        return frames[index]
    }

    static func load() -> BirdAnimation {
        guard let url = Bundle.main.url(forResource: "bird", withExtension: "gif"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return BirdAnimation() }
        var result = BirdAnimation()
        for index in 0..<CGImageSourceGetCount(source) {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
            let end = result.duration + max(delay, 0.02)
            result.frames.append(UIImage(cgImage: image))
            result.ends.append(end)
        }
        return result
    }
}
