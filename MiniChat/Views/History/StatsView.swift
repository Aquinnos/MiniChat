//
//  StatsView.swift
//  MiniChat
//
//  Insights: łączne statystyki konwersacji + heat-mapa aktywności (Swift Charts).
//

import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject private var store: ConversationStore
    @Environment(\.dismiss) private var dismiss

    private var stats: ConversationStats { store.stats }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summaryCards
                    if !stats.dailyActivity.isEmpty {
                        activityChart
                    }
                    if !stats.topTags.isEmpty {
                        topTagsSection
                    }
                    if let longest = stats.longestConversation {
                        longestSection(longest)
                    }
                }
                .padding()
            }
            .navigationTitle("Statystyki")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") { dismiss() }
                }
            }
        }
    }

    // MARK: - Summary cards

    private var summaryCards: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            StatCard(
                title: "Rozmowy",
                value: "\(stats.totalConversations)",
                systemImage: "bubble.left.and.bubble.right",
                tint: Theme.blue
            )
            StatCard(
                title: "Wiadomości",
                value: "\(stats.totalMessages)",
                systemImage: "text.bubble",
                tint: Theme.gold
            )
            StatCard(
                title: "Tagi",
                value: "\(stats.totalTags)",
                systemImage: "tag",
                tint: Theme.blue
            )
            StatCard(
                title: "~Tokeny",
                value: formatNumber(stats.estimatedTokens),
                systemImage: "number",
                tint: Theme.gold
            )
        }
    }

    // MARK: - Activity chart

    private var activityChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aktywność (30 dni)")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            Chart(stats.dailyActivity) { day in
                BarMark(
                    x: .value("Dzień", day.date, unit: .day),
                    y: .value("Rozmowy", day.count)
                )
                .foregroundStyle(Theme.blue.gradient)
            }
            .frame(height: 160)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.narrow))
                }
            }
        }
        .padding()
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Top tags

    private var topTagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Najczęstsze tagi")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            ForEach(stats.topTags) { entry in
                HStack {
                    Text("#\(entry.tag)")
                        .foregroundColor(Theme.blue)
                    Spacer()
                    Text("\(entry.count)")
                        .foregroundColor(Theme.textSecondary)
                        .font(.caption.monospacedDigit())
                }
                .padding(.vertical, 4)
                if entry != stats.topTags.last {
                    Divider()
                }
            }
        }
        .padding()
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func longestSection(_ longest: ConversationStats.ConversationLength) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Najdłuższa rozmowa")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            Text(longest.title)
                .font(.subheadline)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(2)
            Text("\(longest.messageCount) wiadomości")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fk", Double(n) / 1_000) }
        return "\(n)"
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(tint)
                Text(title)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            Text(value)
                .font(.title.bold().monospacedDigit())
                .foregroundColor(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
}
