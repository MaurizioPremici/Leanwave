public enum TimeText {
    public static func format(_ seconds: Double) -> String {
        let total = max(0, seconds.isFinite ? Int(seconds.rounded(.down)) : 0)
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let remainingSeconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
