import SwiftUI

struct CreateGroupView: View {
    var onCreated: (Group) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var unlockMode: Group.UnlockMode = .sunrise
    @State private var customUnlockDate = Date().addingTimeInterval(86400)
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 28) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("group name")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("saturday night, coachella...", text: $name)
                            .textFieldStyle(LNTextFieldStyle())
                            .autocapitalization(.none)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("photos unlock")
                            .font(.caption)
                            .foregroundColor(.gray)

                        ForEach([Group.UnlockMode.sunrise, .sundayNight, .custom], id: \.self) { mode in
                            Button {
                                unlockMode = mode
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mode.label)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                        Text(mode.description)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    if unlockMode == mode {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding()
                                .background(unlockMode == mode ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
                                .cornerRadius(12)
                            }
                        }
                    }

                    if unlockMode == .custom {
                        DatePicker("unlock at", selection: $customUnlockDate, displayedComponents: [.date, .hourAndMinute])
                            .colorScheme(.dark)
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                    }

                    if let error = errorMessage {
                        Text(error).foregroundColor(.red).font(.caption)
                    }

                    Spacer()

                    Button {
                        create()
                    } label: {
                        if isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text("create group").fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(name.isEmpty ? Color.white.opacity(0.2) : Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(14)
                    .disabled(name.isEmpty || isLoading)
                }
                .padding(24)
            }
            .navigationTitle("new group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func create() {
        isLoading = true
        Task {
            do {
                let group = try await APIClient.shared.createGroup(
                    name: name,
                    unlockMode: unlockMode.rawValue,
                    unlockAt: unlockMode == .custom ? customUnlockDate : nil,
                    timezone: TimeZone.current.identifier
                )
                onCreated(group)
                dismiss()
            } catch APIError.badRequest(let msg) {
                errorMessage = msg
            } catch {
                errorMessage = "Something went wrong"
            }
            isLoading = false
        }
    }
}

extension Group.UnlockMode {
    var label: String {
        switch self {
        case .sunrise: return "at sunrise"
        case .sundayNight: return "sunday night"
        case .custom: return "custom time"
        }
    }
    var description: String {
        switch self {
        case .sunrise: return "photos unlock the next morning"
        case .sundayNight: return "perfect for weekend trips"
        case .custom: return "you choose when they reveal"
        }
    }
}
