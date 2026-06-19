//
//  LegalSheetView.swift
//  LastNight
//
//  Created by Sydney Patel on 6/19/26.
//

import SwiftUI

struct LegalSheetView: View {

    enum Page: String, CaseIterable {
        case privacy = "Privacy Policy"
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    PrivacyContent()
                        .padding(20)
                }
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Shared helpers

private func sectionHeader(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 16, weight: .bold))
        .foregroundColor(.white)
        .padding(.top, 8)
}

private func subHeader(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 14, weight: .bold))
        .foregroundColor(.white.opacity(0.85))
        .padding(.top, 4)
}

private func bodyText(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 14))
        .foregroundColor(Color.white.opacity(0.7))
        .fixedSize(horizontal: false, vertical: true)
}

private func bulletText(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
        Text("•").foregroundColor(.white.opacity(0.5))
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(Color.white.opacity(0.7))
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Privacy Content

private struct PrivacyContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            bodyText("Effective Date: June 19, 2026")
                .italic()
            bodyText("This Privacy Policy explains how Last Night ('we,' 'us,' or 'our') collects, uses, stores, and shares information about you when you use the Last Night mobile application ('App'). By using the App, you acknowledge that you have read and understood this Privacy Policy.")

            sectionHeader("1. Information We Collect")
            subHeader("1.1 Information You Provide")
            bodyText("When you create an account or use the App, we collect:")
            VStack(alignment: .leading, spacing: 6) {
                bulletText("Name and email address provided at registration via Google Sign-In.")
                bulletText("Profile photo and display name you set within the App.")
                bulletText("Photos you capture and upload within groups.")
                bulletText("Bio and other profile information you choose to share.")
            }

            subHeader("1.2 Information Collected Automatically")
            bodyText("When you use the App, we and our service providers may automatically collect:")
            VStack(alignment: .leading, spacing: 6) {
                bulletText("Device information such as device type, operating system version, and unique device identifiers.")
                bulletText("Device push notification tokens for delivering notifications.")
                bulletText("Log data including IP address, timestamps, and crash reports.")
            }

            subHeader("1.3 Information We Do Not Collect")
            bodyText("We do not collect payment information, precise GPS location, or any biometric data. We do not serve advertisements and do not collect data for advertising purposes.")

            sectionHeader("2. How We Use Your Information")
            bodyText("We use the information we collect to:")
            VStack(alignment: .leading, spacing: 6) {
                bulletText("Create and manage your account.")
                bulletText("Display your profile and content to other users of the App.")
                bulletText("Operate, maintain, and improve the App.")
                bulletText("Enable group photo sharing with time-locked unlock functionality.")
                bulletText("Send push notifications related to your activity, such as when group photos unlock.")
                bulletText("Respond to your support requests and communications.")
                bulletText("Detect and prevent fraud, abuse, and violations of our Terms.")
            }

            sectionHeader("3. How We Share Your Information")
            subHeader("3.1 With Other Users")
            bodyText("Your profile information (display name, profile photo, bio) and photos you post are visible to members of your groups as part of the core functionality of the service.")

            subHeader("3.2 With Service Providers")
            bodyText("We share information with third-party service providers who help us operate the App, including:")
            VStack(alignment: .leading, spacing: 6) {
                bulletText("Firebase (Google LLC) — for authentication. Governed by Google's Privacy Policy at https://policies.google.com/privacy.")
                bulletText("Amazon Web Services — for photo storage (S3), content delivery (CloudFront), and backend infrastructure (EC2, RDS, Lambda).")
                bulletText("Apple — for push notification delivery via APNs.")
            }

            subHeader("3.3 Legal Requirements")
            bodyText("We may disclose your information if required to do so by law or in response to valid legal process, or if we believe disclosure is necessary to protect the rights, property, or safety of Last Night, our users, or the public.")

            subHeader("3.4 We Do Not Sell Your Data")
            bodyText("We do not sell, rent, or trade your personal information to third parties for their marketing or commercial purposes.")

            sectionHeader("4. Data Retention")
            bodyText("We retain your personal information for as long as your account is active. When you delete your account, we will delete your personal data, including your profile, photos, and group memberships, within 30 days, except where retention is required by law.")

            sectionHeader("5. Your Rights and Choices")
            subHeader("5.1 Account Deletion")
            bodyText("You may delete your account at any time through the App settings. Upon deletion, your personal information and content will be permanently removed from our systems within 30 days.")

            subHeader("5.2 Updating Your Information")
            bodyText("You may update your display name, profile photo, and bio at any time through your account settings within the App.")

            subHeader("5.3 Push Notifications")
            bodyText("You can control notification preferences through your device settings at any time.")

            subHeader("5.4 California Residents (CCPA)")
            bodyText("If you are a California resident, you have the right to know what personal information we collect, request deletion, and opt out of the sale of your personal information (note: we do not sell personal information).")

            subHeader("5.5 Users in the EEA/UK (GDPR)")
            bodyText("If you are located in the EEA or UK, you have rights under the GDPR, including the right to access, correct, or delete your personal data. Contact us at the address in Section 8 to make a request.")

            sectionHeader("6. Children's Privacy")
            bodyText("Last Night is not intended for individuals under the age of 18. We do not knowingly collect personal information from individuals under 18. If we become aware that a user under 18 has provided personal information, we will delete such information promptly.")

            sectionHeader("7. Security")
            bodyText("We implement reasonable technical and organizational measures to protect your personal information against unauthorized access, loss, or misuse, including HTTPS data transmission, encrypted storage, and access controls on our backend systems. No method of transmission over the internet is 100% secure.")

            sectionHeader("8. Changes to This Privacy Policy")
            bodyText("We may update this Privacy Policy from time to time. When we do, we will revise the effective date at the top of this document. We encourage you to review this policy periodically.")

            sectionHeader("9. Contact Us")
            bodyText("If you have any questions, concerns, or requests regarding this Privacy Policy, please contact us at:")
            bodyText("Last Night\nEmail: sydney.j.patel@gmail.com")
        }
    }
}
