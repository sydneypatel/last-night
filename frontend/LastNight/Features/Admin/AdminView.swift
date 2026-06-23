//
//  AdminView.swift
//  LastNight
//
//  Created by Sydney Patel on 6/23/26.
//


import SwiftUI

// Admin user IDs — mirror of the backend list. Add/swap to change admins.
enum Admin {
    static let ids: Set<String> = [
        "3b81c5c2-7ab3-47ab-9ab9-9dfe0c8778cf", // syd
        "927f49bc-45d2-4fd9-855b-58da1815c67c", // djpaulyd (katie)
    ]
    static func isAdmin(_ userId: String?) -> Bool {
        guard let userId else { return false }
        return ids.contains(userId)
    }
}

struct AdminView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                NavigationLink {
                    AdminReportsView()
                } label: {
                    HStack {
                        Image(systemName: "flag.fill")
                        Text("reports")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(12)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .navigationTitle("admin")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }
}

struct AdminReportsView: View {
    @State private var reports: [APIClient.AdminReport] = []
    @State private var isLoading = true
    @State private var actioningId: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(.white)
            } else if reports.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundColor(.white.opacity(0.3))
                    Text("no pending reports")
                        .foregroundColor(.gray)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(reports) { report in
                            reportCard(report)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("reports")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadReports() }
        .preferredColorScheme(.dark)
    }

    private func reportCard(_ report: APIClient.AdminReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let url = URL(string: report.url) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                        .frame(maxHeight: 300)
                        .frame(maxWidth: .infinity)
                        .clipped()
                } placeholder: {
                    ProgressView().tint(.white).frame(height: 200)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("reason: \(report.reason)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Text("photo by @\(report.photoOwnerUsername)")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("reported by @\(report.reporterUsername)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            HStack(spacing: 12) {
                Button {
                    dismiss(report)
                } label: {
                    Text("dismiss")
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(12)
                }
                .disabled(actioningId == report.id)

                Button {
                    remove(report)
                } label: {
                    Text("remove photo")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(12)
                }
                .disabled(actioningId == report.id)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    private func loadReports() async {
        do {
            reports = try await APIClient.shared.getPendingReports()
        } catch {
            print("Error loading reports:", error)
        }
        isLoading = false
    }

    private func dismiss(_ report: APIClient.AdminReport) {
        actioningId = report.id
        Task {
            do {
                try await APIClient.shared.dismissReport(id: report.id)
                await MainActor.run {
                    reports.removeAll { $0.id == report.id }
                    actioningId = nil
                }
            } catch {
                print("Dismiss error:", error)
                await MainActor.run { actioningId = nil }
            }
        }
    }

    private func remove(_ report: APIClient.AdminReport) {
        actioningId = report.id
        Task {
            do {
                try await APIClient.shared.removeReportedPhoto(reportId: report.id)
                await MainActor.run {
                    reports.removeAll { $0.id == report.id }
                    actioningId = nil
                }
            } catch {
                print("Remove error:", error)
                await MainActor.run { actioningId = nil }
            }
        }
    }
}
