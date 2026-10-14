import Foundation

/// Checks a pack against a target's published limits *before* hand-off.
///
/// "Pack too large / wrong dimensions" at the WhatsApp hand-off is the single
/// most common one-star complaint in this category. The validator turns that
/// class of failure into a badge the user sees while building the pack.
public enum ExportValidator {
    /// Validates a whole pack, including pack-level rules (count, name, tray).
    public static func validate(pack: PackSpec, target: ExportTarget) -> ValidationReport {
        let limits = ExportLimits.limits(for: target)
        var issues: [ValidationIssue] = []

        issues.append(contentsOf: packLevelIssues(pack: pack, limits: limits))
        issues.append(contentsOf: trayIconIssues(pack: pack, limits: limits))

        for sticker in pack.stickers {
            let scope = ValidationIssue.Scope.sticker(id: sticker.id, name: sticker.name)
            issues.append(
                contentsOf: validate(sticker: sticker, target: target).map {
                    ValidationIssue(scope: scope, problem: $0)
                }
            )
        }

        return ValidationReport(target: target, issues: issues)
    }

    /// Validates one sticker in isolation, used for the per-sticker badges in
    /// the library and editor.
    public static func validate(sticker: StickerSpec, target: ExportTarget) -> [ValidationProblem] {
        let limits = ExportLimits.limits(for: target)
        var problems: [ValidationProblem] = []

        if !limits.canvas.isSatisfied(by: sticker.pixelSize) {
            problems.append(
                .wrongCanvasSize(
                    actual: sticker.pixelSize,
                    expected: limits.canvas.fittedSize(for: sticker.pixelSize)
                )
            )
        }

        let isAnimated = sticker.isAnimated
        if isAnimated && !limits.supportsAnimation {
            problems.append(.animationNotSupported)
        } else {
            let allowed = limits.formats(isAnimated: isAnimated)
            if !allowed.contains(sticker.format) {
                problems.append(.unsupportedFormat(actual: sticker.format, allowed: allowed))
            }
        }

        let maxBytes = limits.maxBytes(isAnimated: isAnimated)
        if sticker.byteCount > maxBytes {
            problems.append(.fileTooLarge(actualBytes: sticker.byteCount, maxBytes: maxBytes))
        }

        if isAnimated {
            if let maxDuration = limits.maxAnimationDurationMilliseconds,
               sticker.animationDurationMilliseconds > maxDuration {
                problems.append(
                    .animationTooLong(
                        actualMilliseconds: sticker.animationDurationMilliseconds,
                        maxMilliseconds: maxDuration
                    )
                )
            }
            if let minimumFrame = limits.minFrameDurationMilliseconds,
               sticker.frameDurationMilliseconds < minimumFrame {
                problems.append(
                    .frameDurationTooShort(
                        actualMilliseconds: sticker.frameDurationMilliseconds,
                        minimumMilliseconds: minimumFrame
                    )
                )
            }
        }

        if let emojiRange = limits.emojiTagsRange {
            let count = sticker.emojiTags.count
            if count < emojiRange.lowerBound {
                problems.append(.tooFewEmojiTags(count: count, minimum: emojiRange.lowerBound))
            } else if count > emojiRange.upperBound {
                problems.append(.tooManyEmojiTags(count: count, maximum: emojiRange.upperBound))
            }
        }

        return problems
    }

    /// Readiness for every badged target, in display order.
    public static func readinessByTarget(pack: PackSpec) -> [ExportTarget: Readiness] {
        var result: [ExportTarget: Readiness] = [:]
        for target in ExportTarget.badgedTargets {
            result[target] = validate(pack: pack, target: target).readiness
        }
        return result
    }

    // MARK: - Private

    private static func packLevelIssues(pack: PackSpec, limits: ExportLimits) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let count = pack.stickers.count

        if count < limits.packSizeRange.lowerBound {
            issues.append(
                ValidationIssue(
                    scope: .pack,
                    problem: .tooFewStickers(count: count, minimum: limits.packSizeRange.lowerBound)
                )
            )
        } else if count > limits.packSizeRange.upperBound {
            issues.append(
                ValidationIssue(
                    scope: .pack,
                    problem: .tooManyStickers(count: count, maximum: limits.packSizeRange.upperBound)
                )
            )
        }

        let trimmedName = pack.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            issues.append(ValidationIssue(scope: .pack, problem: .packNameMissing))
        } else if trimmedName.count > limits.maxPackNameLength {
            issues.append(
                ValidationIssue(
                    scope: .pack,
                    problem: .packNameTooLong(
                        count: trimmedName.count,
                        maximum: limits.maxPackNameLength
                    )
                )
            )
        }

        return issues
    }

    private static func trayIconIssues(pack: PackSpec, limits: ExportLimits) -> [ValidationIssue] {
        guard let rule = limits.trayIcon else { return [] }
        guard let tray = pack.trayIcon else {
            return [ValidationIssue(scope: .trayIcon, problem: .missingTrayIcon(expected: rule.size))]
        }

        var issues: [ValidationIssue] = []
        if tray.pixelSize != rule.size {
            issues.append(
                ValidationIssue(
                    scope: .trayIcon,
                    problem: .trayIconWrongSize(actual: tray.pixelSize, expected: rule.size)
                )
            )
        }
        if tray.format != rule.format {
            issues.append(
                ValidationIssue(
                    scope: .trayIcon,
                    problem: .trayIconUnsupportedFormat(actual: tray.format, expected: rule.format)
                )
            )
        }
        if tray.byteCount > rule.maxBytes {
            issues.append(
                ValidationIssue(
                    scope: .trayIcon,
                    problem: .trayIconTooLarge(actualBytes: tray.byteCount, maxBytes: rule.maxBytes)
                )
            )
        }
        return issues
    }
}
