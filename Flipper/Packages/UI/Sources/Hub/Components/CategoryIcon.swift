import Core
import SwiftUI
import Foundation
import SVGKit

struct CategoryIcon: View {
    @Environment(\.colorScheme) var colorScheme

    let url: URL?
    let fixme: Bool

    init(_ url: URL?, fixme: Bool = false) {
        self.url = url
        self.fixme = fixme
    }

    private var color: Color {
        switch colorScheme {
        case .dark: return .black40
        default: return .black60
        }
    }

    var body: some View {
        Group {
            if let url = url {
                RemoteImage(url: url)
            } else {
                Image("UnknownCategory")
            }
        }
        .foregroundColor(fixme ? .primary : color)
    }

    struct RemoteImage: View {
        let url: URL

        @State var svgkImage: SVGKImage?

        var body: some View {
            Group {
                if let svgkImage = svgkImage {
                    Image(uiImage: svgkImage.uiImage)
                        .renderingMode(.template)
                        .interpolation(.none)
                        .resizable()
                } else {
                    AnimatedPlaceholder()
                }
            }
            .task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    self.svgkImage = SVGKImage(data: data)
                } catch {
                    print(error)
                }
            }
        }
    }
}
