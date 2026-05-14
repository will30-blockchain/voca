import Foundation
import Security

/// Generic-password Keychain wrapper. Each API key lives under a stable
/// service identifier (e.g. "com.voca.api-key.groq") and is constrained to
/// the current user account with `WhenUnlockedThisDeviceOnly` so backups
/// (Time Machine, iCloud, Migration Assistant) don't leak it.
public enum Keychain {
    public enum Key: String, CaseIterable, Sendable {
        case groq
        case openai
        case anthropic
        case deepgram

        var service: String { "com.voca.api-key.\(rawValue)" }
        var account: String { "default" }
    }

    public static func read(_ key: Key) -> String {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: key.service,
            kSecAttrAccount: key.account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(query as CFDictionary, $0)
        }
        guard status == errSecSuccess, let data = result as? Data, let s = String(data: data, encoding: .utf8) else {
            return ""
        }
        _ = query
        return s
    }

    @discardableResult
    public static func write(_ key: Key, value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // Empty value → delete the entry rather than store a blank.
        if trimmed.isEmpty {
            return delete(key)
        }
        guard let data = trimmed.data(using: .utf8) else { return false }

        let baseQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: key.service,
            kSecAttrAccount: key.account
        ]
        let attrs: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable: false
        ]

        // Try update first; fall back to add.
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attrs as CFDictionary)
        if updateStatus == errSecSuccess { return true }

        var addQuery = baseQuery
        for (k, v) in attrs { addQuery[k] = v }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        return addStatus == errSecSuccess
    }

    @discardableResult
    public static func delete(_ key: Key) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: key.service,
            kSecAttrAccount: key.account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
