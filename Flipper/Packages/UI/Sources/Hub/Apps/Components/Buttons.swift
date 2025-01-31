import Core
import SwiftUI

struct UpdateAllAppButton: View {
    @EnvironmentObject var model: Applications

    @State var updatesCount: Int?

    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                Text("UPDATE ALL")
                    .foregroundColor(.white)
                    .font(.born2bSportyV2(size: 18))

                if let updatesCount {
                    Group {
                        Group {
                            Text("\(updatesCount)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.sGreenUpdate)
                                .padding(.horizontal, 4)
                        }
                        .padding(2)
                    }
                    .background(.white.opacity(0.8))
                    .cornerRadius(4)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(Color.sGreenUpdate)
            .cornerRadius(8)
        }
        .onReceive(model.$statuses) { _ in
            loadUpdates()
        }
        .task {
            loadUpdates()
        }
    }

    func loadUpdates() {
        self.updatesCount = model.outdatedCount
    }
}

struct DeleteAppButton: View {
    var action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            GeometryReader { proxy in
                Image("AppDelete")
                    .resizable()
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height)
            }
        }
    }
}

struct InstallAppButton: View {
    var action: () -> Void

    var body: some View {
        AppActionButton(
            title: "INSTALL",
            color: .a1,
            progress: 1,
            action: action
        )
    }
}

struct UpdateAppButton: View {
    var action: () -> Void

    var body: some View {
        AppActionButton(
            title: "UPDATE",
            color: .sGreenUpdate,
            progress: 1,
            action: action
        )
    }
}

struct InstalledAppButton: View {
    var action: () -> Void = {}

    var body: some View {
        AppActionButton(
            title: "INSTALLED",
            color: .black20,
            progress: 1,
            action: action
        )
        .disabled(true)
    }
}

struct InstallingAppButton: View {
    let progress: Double

    var body: some View {
        AppProgressButton(
            color: .a1,
            progress: progress
        )
    }
}

struct UpdatingAppButton: View {
    let progress: Double

    var body: some View {
        AppProgressButton(
            color: .sGreenUpdate,
            progress: progress
        )
    }
}

struct AppActionButton: View {
    let title: String
    let color: Color
    let progress: Double
    var action: () -> Void

    @Environment(\.isEnabled) var isEnabled

    var body: some View {
        Button {
            action()
        } label: {
            GeometryReader { proxy in
                HStack {
                    Text(title)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: proxy.size.height)
                .background(isEnabled ? color : .black20)
                .cornerRadius(6)
            }
        }
    }
}

struct AppProgressButton: View {
    let color: Color
    let progress: Double

    var radius: Double { 6 }

    private var progressText: String {
        "\(Int(progress * 100))%"
    }

    init(color: Color, progress: Double) {
        self.color = color
        self.progress = progress
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: radius)
                    .stroke(color, lineWidth: 2)

                GeometryReader { reader in
                    color.frame(width: reader.size.width * progress)
                }

                VStack(alignment: .center) {
                    Text(progressText)
                        .foregroundColor(.white)
                        .padding(.bottom, 2)
                }
            }
            .frame(height: proxy.size.height)
            .background(color.opacity(0.5))
            .cornerRadius(radius)
        }
    }
}
