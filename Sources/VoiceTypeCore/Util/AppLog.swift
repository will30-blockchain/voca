import Foundation
import os.log

public enum AppLog {
    private static let subsystem = "com.voicetype.app"

    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let audio = Logger(subsystem: subsystem, category: "audio")
    public static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
    public static let stt = Logger(subsystem: subsystem, category: "stt")
    public static let llm = Logger(subsystem: subsystem, category: "llm")
    public static let inject = Logger(subsystem: subsystem, category: "inject")
    public static let memory = Logger(subsystem: subsystem, category: "memory")
    public static let engine = Logger(subsystem: subsystem, category: "engine")
}
