import ComposableArchitecture
import SwiftUI

struct SummaryView: View {
    let store: StoreOf<SummaryFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row: title + close button
            HStack(alignment: .center) {
                Text("Summary")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    store.send(.dismiss)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Dismiss (Esc)")
            }

            Divider()
                .background(Color.white.opacity(0.15))

            phaseContent
                .frame(minHeight: 60)

            Divider()
                .background(Color.white.opacity(0.15))

            Text("Press ⌥Space or Esc to dismiss")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(20)
        .frame(width: 800, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 10)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.94).combined(with: .opacity),
            removal: .scale(scale: 0.94).combined(with: .opacity)
        ))
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: store.phase)
        .onKeyPress(.escape) {
            store.send(.dismiss)
            return .handled
        }
        .onChange(of: store.phase) { _, newPhase in
            if newPhase == .idle {
                PanelManager.shared.hide()
            }
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch store.phase {
        case .idle:
            EmptyView()

        case .extracting:
            HStack(spacing: 10) {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.secondary)
                Text("Reading selection…")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

        case .thinking:
            BouncingDotsView(label: "Thinking")

        case .streaming:
            Text(store.summaryText + "▊")
                .font(.system(size: 16))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .lineSpacing(4)

        case .done:
            Text(store.summaryText)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .lineSpacing(4)

        case .error:
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .font(.callout)
                Text(store.error ?? "An unknown error occurred.")
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineSpacing(4)
            }
        }
    }
}

// MARK: - Bouncing Dots

struct BouncingDotsView: View {
    let label: String

    @State private var offsets: [CGFloat] = [0, 0, 0]

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundStyle(.secondary)
                .font(.callout)

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .offset(y: offsets[i])
                }
            }
        }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        for i in 0..<3 {
            withAnimation(
                .easeInOut(duration: 0.45)
                .repeatForever(autoreverses: true)
                .delay(Double(i) * 0.15)
            ) {
                offsets[i] = -7
            }
        }
    }
}
