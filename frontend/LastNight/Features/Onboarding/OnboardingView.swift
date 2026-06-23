import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "moon.stars.fill",
            title: "last night",
            subtitle: "capture the night, relive it tomorrow"
        ),
        OnboardingPage(
            icon: "person.3.fill",
            title: "make a group",
            subtitle: "create a group with your friends! then, invite them to join with a link or add them by search"
        ),
        OnboardingPage(
            icon: "camera.fill",
            title: "capture the night",
            subtitle: "take photos all night — they stay hidden until they unlock"
        ),
        OnboardingPage(
            icon: "lock.open.fill",
            title: "unlock on your terms",
            subtitle: "photos unlock at sunrise, a custom time, or sunday night after the weekend"
        ),
        OnboardingPage(
            icon: "heart.fill",
            title: "save your favorites",
            subtitle: "heart the best shots to keep them in your library"
        ),
        OnboardingPage(
            icon: "square.grid.3x3.fill",
            title: "curate & find friends",
            subtitle: "pin your favorites to your profile, and search for friends to see theirs"
        ),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    if currentPage < pages.count  {
                        Button("skip") {
                            onComplete()
                        }
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                }
                .frame(height: 56)

                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        VStack(spacing: 24) {
                            Spacer()

                            Image(systemName: page.icon)
                                .font(.system(size: 72))
                                .foregroundColor(.white)
                                .frame(height: 100)

                            VStack(spacing: 12) {
                                Text(page.title)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)

                                Text(page.subtitle)
                                    .font(.body)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }

                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        onComplete()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "next" : "get started")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white)
                        .cornerRadius(27)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
}
