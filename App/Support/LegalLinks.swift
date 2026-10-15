import Foundation

/// Public legal URLs shown in the paywall and Settings.
///
/// Guideline 3.1.2 and Apple's subscription page require functional Privacy
/// Policy and Terms of Use links in both the binary and App Store metadata
/// when an auto-renewable subscription is offered. These defaults point at
/// the GitHub Pages copies in `docs/`. Replace them after you publish the
/// pages under your own domain.
enum LegalLinks {
    static let privacy = URL(string: "https://gabrielfrey.github.io/Stiki/privacy.html")
    static let terms = URL(string: "https://gabrielfrey.github.io/Stiki/terms.html")
    static let support = URL(string: "https://gabrielfrey.github.io/Stiki/support.html")
    /// Apple's Licensed Application End User License Agreement, which applies
    /// when App Store Connect is left on the standard EULA.
    static let appleStandardEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")

    static let privacyPolicyURLString = privacy?.absoluteString ?? ""
    static let termsOfUseURLString = terms?.absoluteString ?? ""
    static let supportURLString = support?.absoluteString ?? ""
}
