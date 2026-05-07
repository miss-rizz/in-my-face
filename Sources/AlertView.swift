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

                HStack(spacing: 48) {
                    if let url = url {
                        PulsingButton(
                            label: "Join",
                            buttonColor: Color(red: 0.13, green: 0.62, blue: 0.28),
                            ringColor: Color(red: 0.13, green: 0.62, blue: 0.28)
                        ) { onAction(url) }
                    }
                    PulsingButton(
                        label: "Dismiss",
                        buttonColor: Color(white: 0.16),
                        ringColor: Color(white: 0.55)
                    ) { onAction(nil) }
                }
            }
        }
    }
}

struct PulsingButton: View {
    let label: String
    let buttonColor: Color
    let ringColor: Color
    let action: () -> Void

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                PulsingRing(color: ringColor, delay: Double(i) * 0.65)
            }
            Button(label, action: action)
                .buttonStyle(MeetingButtonStyle(color: buttonColor))
        }
    }
}

struct PulsingRing: View {
    let color: Color
    let delay: Double

    @State private var animating = false

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 1.5)
            .frame(width: 90, height: 90)
            .scaleEffect(animating ? 16 : 1)
            .opacity(animating ? 0 : 0.7)
            .animation(
                .easeOut(duration: 2.8)
                .repeatForever(autoreverses: false)
                .delay(delay),
                value: animating
            )
            .onAppear { animating = true }
    }
}

struct MeetingButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 140, height: 50)
            .background(color)
            .opacity(configuration.isPressed ? 0.65 : 1)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
