import Foundation
import Security

/// Generic-password Keychain wrapper.
///
/// We use the legacy macOS keychain (no kSecUseDataProtectionKeychain).
/// The data protection keychain is cleaner but requires either a real
/// Apple Team Identifier (impossible for self-signed builds) or a
/// keychain-access-groups entitlement (which launchd refuses to honour
/// on self-signed builds — error 163). So legacy it is.
///
/// Consequence: macOS will show "VOCA wants to access the keychain"
/// the first time it reads each API key. The user can pick "Always
/// allow" once per key (4 max — groq, openai, anthropic, deepgram)
/// and the prompts stop. The real fix is shipping with an Apple
/// Developer ID signature + notarisation — at that point macOS trusts
/// the binary fully and never prompts.
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
        guard status == errSecSuccess,
              let data = result as? Data,
              let s = String(data: data, encoding: .utf8) else {
            if status != errSecItemNotFound && status != errSecSuccess {
                AppLog.app.error("Keychain read failed for \(key.service, privacy: .public): OSStatus \(status)")
            }
            return ""
        }
        return s
    }

    @discardableResult
    public static func write(_ key: Key, value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
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

        // Update if already present; otherwise add.
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attrs as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        if updateStatus != errSecItemNotFound {
            AppLog.app.error("Keychain update failed for \(key.service, privacy: .public): OSStatus \(updateStatus)")
        }

        var addQuery = baseQuery
        for (k, v) in attrs { addQuery[k] = v }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus != errSecSuccess {
            AppLog.app.error("Keychain add failed for \(key.service, privacy: .public): OSStatus \(addStatus)")
        }
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
