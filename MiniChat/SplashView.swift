//
//  SplashView.swift
//  MiniChat
//
//  Ekran ładowania widoczny przez ~0.7s przy starcie aplikacji.
//  Pokazuje logo (AppIcon), nazwę, tagline + animowany progress.
//

import SwiftUI

struct SplashView: View {
    @State private var rotateLogo = false
    @State private var fadeIn = false
    @State private var pulseDot = false

    var body: some View {
        ZStack {
            // Tło - białe z subtelnym gradientem złotym
            LinearGradient(
                colors: [Color.white, Theme.gold.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Logo - kółko z 🧠 i efektem pulse
                ZStack {
                    // Zewnętrzny pierścień (animowany)
                    Circle()
                        .stroke(Theme.gold.opacity(0.3), lineWidth: 2)
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulseDot ? 1.15 : 1.0)
                        .opacity(pulseDot ? 0.0 : 0.7)
                        .animation(
                            .easeInOut(duration: 1.4)
                            .repeatForever(autoreverses: false),
                            value: pulseDot
                        )

                    // Wewnętrzne kółko z emoji
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.gold, Theme.gold.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 110, height: 110)
                        .shadow(color: Theme.gold.opacity(0.4), radius: 12, x: 0, y: 4)

                    Text("🧠")
                        .font(.system(size: 56))
                        .scaleEffect(pulseDot ? 1.05 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true),
                            value: pulseDot
                        )
                }
                .rotationEffect(.degrees(rotateLogo ? 360 : 0))
                .animation(
                    .linear(duration: 8)
                    .repeatForever(autoreverses: false),
                    value: rotateLogo
                )

                // Nazwa + tagline
                VStack(spacing: 6) {
                    Text("MiniChat")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.blue, Theme.gold],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Osobisty czat z AI")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }

                // Animowany progress (3 kropki)
                HStack(spacing: 6) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(Theme.gold)
                            .frame(width: 8, height: 8)
                            .opacity(pulseDot ? 1.0 : 0.3)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.2),
                                value: pulseDot
                            )
                    }
                }
                .padding(.top, 8)
            }
            .opacity(fadeIn ? 1.0 : 0.0)
            .scaleEffect(fadeIn ? 1.0 : 0.92)
        }
        .onAppear {
            fadeIn = true
            rotateLogo = true
            pulseDot = true
        }
    }
}

#Preview {
    SplashView()
}
