//
//  LegalSheetView.swift
//  LastNight
//

import SwiftUI

struct LegalSheetView: View {

    enum Page: String, CaseIterable {
        case terms = "Terms & Conditions"
        case privacy = "Privacy Policy"
    }

    var initialPage: Page = .terms

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPage: Page

    init(initialPage: Page = .terms) {
        self.initialPage = initialPage
        _selectedPage = State(initialValue: initialPage)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("", selection: $selectedPage) {
                        ForEach(Page.allCases, id: \.self) { page in
                            Text(page == .terms ? "terms" : "privacy").tag(page)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    ScrollView {
                        SwiftUI.Group {
                            if selectedPage == .terms {
                                TermsContent()
                            } else {
                                PrivacyContent()
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle(selectedPage.rawValue)
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

// MARK: - Terms Content

private struct TermsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            bodyText("Effective Date: June 22, 2026").italic()
            bodyText("By downloading, installing, or using the Last Night mobile application (\"App\"), you agree to be bound by these Terms and Conditions (\"Terms\"). If you do not agree to these Terms, do not use the App.")

            sectionHeader("1. Acceptance of Terms")
            bodyText("By using the App, you agree to these Terms. We reserve the right to update or modify these Terms at any time. Continued use of the App after changes are posted constitutes your acceptance of the revised Terms. We will notify users of material changes through the App or via email.")

            sectionHeader("2. Eligibility")
            bodyText("You must be at least 18 years old to use Last Night. By using the App, you represent and warrant that you are at least 18 years old and have the legal capacity to enter into a binding agreement.")
            bodyText("Last Night does not knowingly allow access to users under the age of 18. If we become aware that a user is under 18, we will promptly delete their account.")

            sectionHeader("3. User Accounts")
            bodyText("To use the App, you must register for an account using Google or Apple sign-in. You agree to:")
            VStack(alignment: .leading, spacing: 6) {
                bulletText("Provide accurate, current, and complete information during registration.")
                bulletText("Keep your account credentials secure.")
                bulletText("Notify us immediately of any unauthorized use of your account.")
                bulletText("Take full responsibility for all activity that occurs under your account.")
            }
            bodyText("We reserve the right to suspend or terminate accounts at our sole discretion, including for violations of these Terms, without prior notice or liability.")

            sectionHeader("4. Your Content")
            subHeader("4.1 Ownership and License")
            bodyText("You retain full ownership of the photos and other content you capture, upload, or share through the App (\"Your Content\"). By posting Your Content, you grant Last Night a limited, non-exclusive, royalty-free license to store, host, and display Your Content solely for the purpose of operating the App and making it available to the members of your groups. This license exists only to make the App work. We do not use Your Content for advertising or marketing, and we do not claim ownership of it.")

            subHeader("4.2 Your Responsibility")
            bodyText("You are solely responsible for Your Content. You represent and warrant that:")
            VStack(alignment: .leading, spacing: 6) {
                bulletText("You own or have the rights to the content you post.")
                bulletText("Your content does not infringe any third-party intellectual property, privacy, or other rights.")
                bulletText("Your content complies with all applicable laws.")
            }

            subHeader("4.3 Prohibited Content")
            bodyText("You may not post content that:")
            VStack(alignment: .leading, spacing: 6) {
                bulletText("Is hateful, discriminatory, or harasses any individual or group.")
                bulletText("Is sexually explicit, obscene, or pornographic.")
                bulletText("Sexualizes or endangers minors in any way.")
                bulletText("Promotes or glorifies violence, self-harm, or illegal activity.")
                bulletText("Contains another person's private information without their consent.")
                bulletText("Is spam, misleading, or constitutes unauthorized advertising.")
                bulletText("Impersonates any person or entity.")
                bulletText("Depicts a person without their consent in a way that violates their privacy.")
            }

            sectionHeader("5. Prohibited Conduct")
            bodyText("You agree not to:")
            VStack(alignment: .leading, spacing: 6) {
                bulletText("Use the App for any unlawful purpose.")
                bulletText("Attempt to gain unauthorized access to any part of the App or its systems.")
                bulletText("Scrape, crawl, or use automated tools to extract data from the App.")
                bulletText("Interfere with or disrupt the integrity or performance of the App.")
                bulletText("Reverse engineer, decompile, or disassemble any part of the App.")
                bulletText("Create multiple accounts to evade a ban or suspension.")
                bulletText("Harass, threaten, or intimidate other users.")
            }

            sectionHeader("6. Groups and Shared Content")
            bodyText("Last Night allows you to create and join groups in which photos are shared among members and revealed at a set unlock time. When you join a group, your photos in that group are visible to other members of that group. When you share an invite link or code, anyone who uses it can join that group and view its content once unlocked. You are responsible for who you invite to your groups.")

            sectionHeader("7. Reporting and Moderation")
            bodyText("We are committed to maintaining a safe and respectful community. We reserve the right to remove any content and to suspend or terminate any account that violates these Terms. Moderation decisions are made at our sole discretion. We are not obligated to remove content or take action in response to every report.")

            sectionHeader("8. Intellectual Property")
            bodyText("All content, features, and functionality of the App — including the Last Night name, logo, design, code, and graphics — are the exclusive property of Last Night and its licensors and are protected by applicable intellectual property laws. You may not copy, reproduce, modify, distribute, or create derivative works of any part of the App without our prior written consent.")

            sectionHeader("9. Privacy")
            bodyText("Your use of the App is also governed by our Privacy Policy, which is incorporated into these Terms by reference. By using the App, you consent to the collection and use of your information as described in the Privacy Policy.")

            sectionHeader("10. Third-Party Services")
            bodyText("The App integrates with third-party services such as Firebase (Google) and Amazon Web Services. We are not responsible for the practices, content, or availability of any third-party services. Your use of third-party services is subject to their respective terms and privacy policies.")

            sectionHeader("11. Disclaimers")
            bodyText("THE APP IS PROVIDED \"AS IS\" AND \"AS AVAILABLE\" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED. We do not warrant that the App will be uninterrupted, error-free, or free of harmful components, or that it will always be available. We do not warrant the accuracy, completeness, or reliability of any content posted by other users.")

            sectionHeader("12. Limitation of Liability")
            bodyText("TO THE FULLEST EXTENT PERMITTED BY LAW, LAST NIGHT AND ITS OWNERS SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES ARISING OUT OF OR RELATED TO YOUR USE OF THE APP. In no event shall our total liability to you exceed the greater of (a) the amount you paid to use the App in the twelve months preceding the claim, or (b) $100 USD.")

            sectionHeader("13. Indemnification")
            bodyText("You agree to indemnify, defend, and hold harmless Last Night and its owners from and against any claims, liabilities, damages, losses, and expenses (including reasonable attorneys' fees) arising out of or related to: (a) your use of the App; (b) Your Content; or (c) your violation of these Terms.")

            sectionHeader("14. Termination")
            bodyText("We may suspend or terminate your account and access to the App at any time, for any reason, with or without notice, including for violations of these Terms. You may also delete your account at any time through the App settings. Upon termination, your right to use the App will immediately cease. Sections that by their nature should survive termination shall survive.")

            sectionHeader("15. Governing Law and Dispute Resolution")
            bodyText("These Terms are governed by the laws of the United States and the state in which Last Night is based, without regard to conflict of law provisions. Any disputes shall first be attempted to be resolved through informal negotiation. If not resolved within 30 days, disputes shall be submitted to binding arbitration in accordance with the rules of the American Arbitration Association. You waive any right to participate in a class action lawsuit or class-wide arbitration.")

            sectionHeader("16. Contact Us")
            bodyText("If you have any questions about these Terms, please contact us at:")
            bodyText("Last Night\nEmail: sydney.j.patel@gmail.com")
        }
    }
}

// MARK: - Privacy Content

private struct PrivacyContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            bodyText("Effective Date: June 22, 2026")
                .italic()
            bodyText("This Privacy Policy explains how Last Night ('we,' 'us,' or 'our') collects, uses, stores, and shares information about you when you use the Last Night mobile application ('App'). By using the App, you acknowledge that you have read and understood this Privacy Policy.")

            sectionHeader("1. Information We Collect")
            subHeader("1.1 Information You Provide")
            bodyText("When you create an account or use the App, we collect:")
            VStack(alignment: .leading, spacing: 6) {
                bulletText("Name and email address provided at registration via Google or Apple Sign-In.")
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
                bulletText("Apple — for authentication via Sign in with Apple and push notification delivery via APNs.")
            }

            subHeader("3.3 Legal Requirements")
            bodyText("We may disclose your information if required to do so by law or in response to valid legal process, or if we believe disclosure is necessary to protect the rights, property, or safety of Last Night, our users, or the public.")

            subHeader("3.4 We Do Not Sell Your Data")
            bodyText("We do not sell, rent, or trade your personal information to third parties for their marketing or commercial purposes.")

            sectionHeader("4. Data Retention and Deletion")
            bodyText("We retain your personal information for as long as your account is active. When you delete a photo, it is removed from our storage. When you delete your account, we will delete your personal data, including your profile, photos, and group memberships, within 30 days, except where retention is required by law. Note that copies may persist briefly in temporary caches before being fully cleared.")

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
            bodyText("If you are located in the EEA or UK, you have rights under the GDPR, including the right to access, correct, or delete your personal data. Contact us at the address in Section 9 to make a request.")

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
