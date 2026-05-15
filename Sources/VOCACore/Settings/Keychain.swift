import Foundation
import Security

/// Generic-password Keychain wrapper. Items are stored in the macOS data
/// protection keychain (`kSecUseDataProtectionKeychain = true`) — the
/// iOS-style API that does NOT show the "VOCA wants to access the
/// keychain" / "type your login password" prompt every time we read.
///
/// Legacy keychain items (from earlier builds before this switch) are
/// migrated on first read transparently — if the data protection
/// keychain doesn't have the value yet but the legacy keychain does,
/// we copy it across and delete the legacy entry.
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
        if let value = readDataProtection(key), !value.isEmpty {
            return value
        }
        // Migration: silently lift any value sitting in the legacy keychain
        // (created by a build before we switched the kSec flag) over to the
        // data protection keychain. After this round the legacy entry is
        // deleted so future reads stay in the new world.
        if let legacy = readLegacy(key), !legacy.isEmpty {
            _ = writeDataProtection(key, value: legacy)
            _ = deleteLegacy(key)
            return legacy
        }
        return ""
    }

    @discardableResult
    public static func write(_ key: Key, value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return delete(key)
        }
        return writeDataProtection(key, value: trimmed)
    }

    @discardableResult
    public static func delete(_ key: Key) -> Bool {
        let dp = deleteDataProtection(key)
        // Also wipe any straggler in the legacy keychain so the value is
        // truly gone — not just hidden behind the prompt the user has been
        // dismissing.
        _ = deleteLegacy(key)
        return dp
    }

    // MARK: - Data protection keychain (preferred)

    private static func readDataProtection(_ key: Key) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: key.service,
            kSecAttrAccount: key.account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseDataProtectionKeychain: true
        ]
        var result: AnyObject?
        let status = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(query as CFDictionary, $0)
        }
        guard status == errSecSuccess, let data = result as? Data,
              let s = String(data: data, encoding: .utf8) else {
            return nil
        }
        return s
    }

    @discardableResult
    private static func writeDataProtection(_ key: Key, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let baseQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: key.service,
            kSecAttrAccount: key.account,
            kSecUseDataProtectionKeychain: true
        ]
        let attrs: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attrs as CFDictionary)
        if updateStatus == errSecSuccess { return true }

        var addQuery = baseQuery
        for (k, v) in attrs { addQuery[k] = v }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        return addStatus == errSecSuccess
    }

    @discardableResult
    private static func deleteDataProtection(_ key: Key) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: key.service,
            kSecAttrAccount: key.account,
            kSecUseDataProtectionKeychain: true
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Legacy keychain (migration only)

    private static func readLegacy(_ key: Key) -> String? {
        let query: [CFString: Any] = [
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
        guard status == errSecSuccess, let data = result as? Data,
              let s = String(data: data, encoding: .utf8) else {
            return nil
        }
        return s
    }

    @discardableResult
    private static func deleteLegacy(_ key: Key) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: key.service,
            kSecAttrAccount: key.account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
