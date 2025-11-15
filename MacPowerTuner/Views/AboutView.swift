import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero section with app icon and name
                VStack(spacing: 24) {
                    // App Icon
                    if let appIcon = NSImage(named: "AppIcon") {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 128, height: 128)
                            .cornerRadius(24)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    } else {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(spacing: 8) {
                        Text("MacPowerTuner")
                            .font(.system(size: 36, weight: .bold, design: .rounded))

                        Text("Version 1.0.0")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 60)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.1),
                            Color.accentColor.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Description section
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About MacPowerTuner")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("""
                        MacPowerTuner is a powerful and intuitive system utility designed to help you optimize, customize, and maintain your macOS experience. Whether you're a power user looking to fine-tune system settings or someone who wants an easier way to manage their Mac, MacPowerTuner provides all the tools you need in one beautiful interface.

                        From system tweaks and privacy controls to disk cleanup and app management, MacPowerTuner brings terminal-level power to your fingertips with a user-friendly GUI that makes complex tasks simple.
                        """)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 30)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)

                    // Features grid
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Key Features")
                            .font(.title2)
                            .fontWeight(.semibold)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            FeatureCard(
                                icon: "gearshape.2.fill",
                                title: "System Tweaks",
                                description: "Customize hidden macOS settings with ease"
                            )

                            FeatureCard(
                                icon: "lock.shield.fill",
                                title: "Privacy & Security",
                                description: "Control your privacy settings in one place"
                            )

                            FeatureCard(
                                icon: "internaldrive.fill",
                                title: "Disk Management",
                                description: "Find large files and reclaim storage space"
                            )

                            FeatureCard(
                                icon: "trash.fill",
                                title: "App Uninstaller",
                                description: "Completely remove apps and their files"
                            )

                            FeatureCard(
                                icon: "wrench.and.screwdriver.fill",
                                title: "Maintenance Tools",
                                description: "Keep your Mac running at peak performance"
                            )

                            FeatureCard(
                                icon: "terminal.fill",
                                title: "Script Manager",
                                description: "Run custom scripts and automations"
                            )
                        }
                    }
                    .padding(.horizontal, 40)

                    Divider()
                        .padding(.vertical, 20)

                    // Developer info
                    VStack(alignment: .center, spacing: 16) {
                        VStack(spacing: 8) {
                            Text("Developed by")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text("pinperepette")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }

                        HStack(spacing: 20) {
                            InfoBadge(icon: "calendar", text: "2025")
                            InfoBadge(icon: "hammer.fill", text: "Built with SwiftUI")
                            InfoBadge(icon: "apple.logo", text: "macOS 13.0+")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)

                    // Footer
                    VStack(spacing: 8) {
                        Text("MacPowerTuner")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Made with ❤️ for macOS power users")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 40)
            }
        }
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct InfoBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(8)
        .foregroundColor(.accentColor)
    }
}

#Preview {
    AboutView()
        .frame(width: 800, height: 600)
}
