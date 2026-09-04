import Foundation

public protocol AppleScriptExecuting: AnyObject {
    func execute(_ source: String) throws -> String
}

public final class SystemAppleScriptExecutor: AppleScriptExecuting {
    public init() {}

    public func execute(_ source: String) throws -> String {
        guard let script = NSAppleScript(source: source) else {
            throw ChromeControllerError.scriptFailure("Unable to create the Chrome automation script.")
        }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let message = errorInfo[NSAppleScript.errorMessage] as? String
                ?? "Chrome automation was denied or failed."
            throw ChromeControllerError.scriptFailure(message)
        }
        return result.stringValue ?? ""
    }
}

public enum ChromeControllerError: Error, Equatable, LocalizedError {
    case notRunning
    case noWindow
    case notYouTube
    case malformedResponse
    case tabChanged
    case scriptFailure(String)

    public var errorDescription: String? {
        switch self {
        case .notRunning: "Google Chrome is not running."
        case .noWindow: "Google Chrome has no open window."
        case .notYouTube: "The active Chrome tab is not a YouTube page."
        case .malformedResponse: "Chrome returned an unreadable tab reference."
        case .tabChanged: "The YouTube tab changed, so Leanwave left it open."
        case .scriptFailure(let message): "Chrome automation failed: \(message)"
        }
    }
}

public final class ChromeController {
    private let executor: AppleScriptExecuting

    public init(executor: AppleScriptExecuting = SystemAppleScriptExecutor()) {
        self.executor = executor
    }

    public func fetchActiveTab() throws -> ChromeTabReference {
        let response = try executor.execute(ChromeScriptBuilder.fetchActiveTab)
        if response == "__LEANWAVE_NOT_RUNNING__" { throw ChromeControllerError.notRunning }
        if response == "__LEANWAVE_NO_WINDOW__" { throw ChromeControllerError.noWindow }
        do {
            return try ChromeScriptBuilder.parseTab(response)
        } catch ChromeScriptError.notYouTube {
            throw ChromeControllerError.notYouTube
        } catch {
            throw ChromeControllerError.malformedResponse
        }
    }

    public func findTab(matching url: YouTubeURL) throws -> ChromeTabReference? {
        let response = try executor.execute(ChromeScriptBuilder.listTabs)
        return ChromeScriptBuilder.parseTabs(response).first {
            $0.url.normalizedString == url.normalizedString
        }
    }

    public func closeTab(_ reference: ChromeTabReference) throws {
        let response = try executor.execute(ChromeScriptBuilder.listTabs)
        let stillMatches = ChromeScriptBuilder.parseTabs(response).contains {
            $0.windowID == reference.windowID
                && $0.tabIndex == reference.tabIndex
                && $0.url.normalizedString == reference.url.normalizedString
        }
        guard stillMatches else { throw ChromeControllerError.tabChanged }
        _ = try executor.execute(ChromeScriptBuilder.closeTab(reference))
    }

    public func quitChrome() throws {
        _ = try executor.execute(ChromeScriptBuilder.quitChrome)
    }
}
