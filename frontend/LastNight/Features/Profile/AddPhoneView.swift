import SwiftUI
import Contacts

struct AddPhoneView: View {
    var onSaved: () -> Void
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var phoneNumber = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var shareContacts = false
    @State private var contactsAuthorized = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    Text("we'll hash your number before storing it — your raw number is never sent to our servers.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 8)

                    // Phone input with auto +1 prefix
                    HStack(spacing: 0) {
                        Text("+1 ")
                            .foregroundColor(.white)
                            .padding(.leading, 16)
                        TextField("(555) 000-0000", text: $phoneNumber)
                            .keyboardType(.numberPad)
                            .foregroundColor(.white)
                            .padding(.vertical, 16)
                            .padding(.trailing, 16)
                    }
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .onChange(of: phoneNumber) { _, newValue in
                        let digits = newValue.filter { $0.isNumber }
                        let capped = String(digits.prefix(10))
                        phoneNumber = formatPhone(capped)
                    }

                    // Contacts opt-in toggle
                    Button {
                        if contactsAuthorized {
                            shareContacts.toggle()
                        } else {
                            Task { await requestContacts() }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                                    .frame(width: 22, height: 22)
                                if shareContacts && contactsAuthorized {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white)
                                        .frame(width: 22, height: 22)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.black)
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("find friends from your contacts")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                Text(contactsAuthorized ? "we'll never store your contacts or share them" : "tap to grant contacts access")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                    }

                    if let error = errorMessage {
                        Text(error).font(.caption).foregroundColor(.red)
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .navigationTitle("add phone number")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }.tint(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Button("save") { save() }
                            .tint(.white)
                            .fontWeight(.semibold)
                            .disabled(phoneNumber.filter { $0.isNumber }.count < 10)
                    }
                }
            }
            .task { await checkContactsStatus() }
            .preferredColorScheme(.dark)
        }
    }
    
    private func formatPhone(_ digits: String) -> String {
        var result = ""
        for (i, char) in digits.enumerated() {
            if i == 0 { result += "(" }
            if i == 3 { result += ") " }
            if i == 6 { result += "-" }
            result.append(char)
        }
        return result
    }

    private func checkContactsStatus() async {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        contactsAuthorized = status == .authorized
        if contactsAuthorized { shareContacts = true }
    }

    private func requestContacts() async {
        let store = CNContactStore()
        let granted = await withCheckedContinuation { continuation in
            store.requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
        contactsAuthorized = granted
        if granted { shareContacts = true }
    }

    private func save() {
        let digits = phoneNumber.filter { $0.isNumber }
        let fullNumber = "+1\(digits)"
        guard let hash = ContactsMatcher.hashPhone(fullNumber) else {
            errorMessage = "enter a valid 10-digit phone number"
            return
        }
        isSaving = true
        Task {
            do {
                try await APIClient.shared.savePhoneHash(hash)
                if shareContacts {
                    if let hashes = await ContactsMatcher.requestAndHashContacts() {
                        _ = try? await APIClient.shared.matchContacts(hashes: hashes)
                    }
                }
                await MainActor.run {
                    isSaving = false
                    onSaved()
                    dismiss()
                }
            } catch APIError.serverError(let msg) {
                await MainActor.run {
                    isSaving = false
                    errorMessage = msg
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "couldn't save, try again"
                }
            }
        }
    }
}
