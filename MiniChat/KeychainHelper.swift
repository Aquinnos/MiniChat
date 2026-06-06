//
//  KeychainHelper.swift
//  MiniChat
//
//  Bezpieczne przechowywanie API key w Keychain.
//

import Foundation
import Security

enum KeychainHelper {
    private static let service = "com.minichat.apikey"
    private static let account = "minimax-api-key"

    enum KeychainError: LocalizedError {
        case unhandledError(status: OSStatus)
        case dataConversionError

        var errorDescription: String? {
            switch self {
            case .unhandledError(let status):
                return "Keychain error (status: \(status))"
            case .dataConversionError:
                return "Nie udało się przekonwertować danych"
            }
        }
    }

    /// Zapisuje API key w Keychain.
    static func save(_ value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.dataConversionError
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        // Spróbuj najpierw zaktualizować
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // Nie znaleziono — dodaj
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledError(status: addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.unhandledError(status: updateStatus)
        }
    }

    /// Odczytuje API key z Keychain.
    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    /// Usuwa API key z Keychain.
    @discardableResult
    static func delete() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Sprawdza, czy API key jest zapisany.
    static var hasAPIKey: Bool {
        read() != nil
    }
}
