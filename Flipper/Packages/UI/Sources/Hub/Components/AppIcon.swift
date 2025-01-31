import Catalog

import SwiftUI

struct AppIcon: View {
    let source: ImageSource

    init(_ source: ImageSource) {
        self.source = source
    }

    var body: some View {
        Group {
            Group {
                switch source {
                case .url(let url):
                    URLImage(url: url)
                case .data(let data):
                    DataImage(data: data)
                }
            }
            .foregroundColor(.black)
            .scaledToFit()
            .padding(4)
        }
        .background(Color.a1)
        .cornerRadius(6)
    }

    struct URLImage: View {
        let url: URL

        var body: some View {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .renderingMode(.template)
                        .interpolation(.none)
                        .resizable()
                }
            }
        }
    }

    struct DataImage: View {
        let data: Data

        var body: some View {
            Image(uiImage: .init(data: data)!)
                .renderingMode(.template)
                .interpolation(.none)
                .resizable()
        }
    }
}
