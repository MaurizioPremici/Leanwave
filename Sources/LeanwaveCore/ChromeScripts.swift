import Foundation

public struct ChromeTabReference: Equatable, Sendable {
    public let windowID: Int
    public let tabIndex: Int
    public let url: YouTubeURL

    public init(windowID: Int, tabIndex: Int, url: YouTubeURL) {
        self.windowID = windowID
        self.tabIndex = tabIndex
        self.url = url
    }
}

public enum ChromeScriptError: Error, Equatable {
    case malformedResponse
    case invalidIdentity
    case notYouTube
}

public enum ChromeScriptBuilder {
    public static let openYouTube = """
    tell application "Google Chrome"
        activate
        if (count of windows) is 0 then
            make new window
            set URL of active tab of front window to "https://www.youtube.com/"
        else
            tell front window
                make new tab at end of tabs with properties {URL:"https://www.youtube.com/"}
                set active tab index to count of tabs
            end tell
        end if
    end tell
    """

    public static let fetchActiveTab = """
    set fieldSeparator to ASCII character 9
    if application "Google Chrome" is not running then return "__LEANWAVE_NOT_RUNNING__"
    tell application "Google Chrome"
        if (count of windows) is 0 then return "__LEANWAVE_NO_WINDOW__"
        set chromeWindow to front window
        set tabNumber to active tab index of chromeWindow
        set tabURL to URL of active tab of chromeWindow
        return ((id of chromeWindow) as text) & fieldSeparator & (tabNumber as text) & fieldSeparator & tabURL
    end tell
    """

    public static let listTabs = """
    set fieldSeparator to ASCII character 9
    set rowSeparator to ASCII character 10
    if application "Google Chrome" is not running then return ""
    tell application "Google Chrome"
        set output to ""
        repeat with chromeWindow in windows
            set windowID to id of chromeWindow
            set tabCount to count of tabs of chromeWindow
            repeat with tabNumber from 1 to tabCount
                set tabURL to URL of tab tabNumber of chromeWindow
                set output to output & (windowID as text) & fieldSeparator & (tabNumber as text) & fieldSeparator & tabURL & rowSeparator
            end repeat
        end repeat
        return output
    end tell
    """

    public static let quitChrome = """
    if application "Google Chrome" is running then
        tell application "Google Chrome" to quit
    end if
    """

    public static func closeTab(_ reference: ChromeTabReference) -> String {
        """
        if application "Google Chrome" is not running then return
        tell application "Google Chrome"
            repeat with chromeWindow in windows
                if (id of chromeWindow as integer) = \(reference.windowID) then
                    if (count of tabs of chromeWindow) is greater than or equal to \(reference.tabIndex) then
                        if (count of tabs of chromeWindow) is 1 then
                            make new tab at end of tabs of chromeWindow with properties {URL:"chrome://newtab"}
                        end if
                        close tab \(reference.tabIndex) of chromeWindow
                    end if
                    return
                end if
            end repeat
        end tell
        """
    }

    public static func parseTab(_ response: String) throws -> ChromeTabReference {
        let fields = response.split(separator: "\t", omittingEmptySubsequences: false)
        guard fields.count == 3,
              let windowID = Int(fields[0]), windowID > 0,
              let tabIndex = Int(fields[1]), tabIndex > 0
        else {
            throw ChromeScriptError.malformedResponse
        }
        guard let url = YouTubeURL(String(fields[2])) else {
            throw ChromeScriptError.notYouTube
        }
        return ChromeTabReference(windowID: windowID, tabIndex: tabIndex, url: url)
    }

    public static func parseTabs(_ response: String) -> [ChromeTabReference] {
        response.split(whereSeparator: \.isNewline).compactMap { try? parseTab(String($0)) }
    }
}
