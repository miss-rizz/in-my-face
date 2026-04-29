import SwiftUI

struct AlertView: View {
    let title: String
    let url: URL?
    let onAction: (URL?) -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 52) {
                Text("MEETING STARTING NOW")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(white: 0.4))
                    .tracking(6)

                Text(title)
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 120)

                HStack(spacing: 16) {
                    if let url = url {
                        Button("Join") { onAction(url) }
                            .buttonStyle(MeetingButtonStyle(isPrimary: true))
                    }
                    Button("Dismiss") { onAction(nil) }
                        .buttonStyle(MeetingButtonStyle(isPrimary: false))
                }
            }
        }
    }
}

struct MeetingButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 140, height: 50)
            .background(
                isPrimary
                    ? Color(red: 0.13, green: 0.62, blue: 0.28)
                    : Color(white: 0.16)
            )
            .opacity(configuration.isPressed ? 0.65 : 1)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
