import os

enum AppLog {
    private static let subsystem = "com.s1korrrr.codebasecombiner"

    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    static let scan = Logger(subsystem: subsystem, category: "scan")
    static let export = Logger(subsystem: subsystem, category: "export")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
}
