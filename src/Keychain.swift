import Foundation

enum Keychain {
    static func add(account: String, service: String, data: Data, generic: Data) -> Bool {
    // swiftlint:disable:previous function_body_length
        let dict: NSDictionary = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecAttrService: service,
            kSecAttrGeneric: generic,
            kSecValueData: data,
            ]

        let status = SecItemAdd(dict, nil)
        guard status != errSecDuplicateItem else {
            print("KEYCHAIN: DEBUG: Duplicate item: account \(account) with service \(service) - falling back to updating instead of adding")
            let updated = SecItemUpdate(dict, dict)
            // If the update gripes that it's a perfect duplicate, it succeeded, right?
            guard updated == errSecSuccess || updated == errSecDuplicateItem else {
                print("KEYCHAIN: ERROR: Failed to update account \(account) with service \(service) keychain item: error \(status)")
                return false
            }
            return true
        }

        guard status == errSecSuccess else {
            print("KEYCHAIN: ERROR: Failed to add account \(account) with service \(service) to keychain: error \(status)")
            return false
        }
        print("AUTH: DEBUG: Saved \(data.count) bytes of data for account \(account) with service \(service).")
        return true
    }

    static func find(account: String, service: String, generic: Data) -> Data? {
        // swiftlint:disable:previous function_body_length
        let query: NSDictionary = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecAttrService: service,
            kSecAttrGeneric: generic,
            kSecReturnData: true,
            ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query, &result)
        guard status == errSecSuccess else {
            print("AUTH: ERROR: Failed to fetch token from keychain: error \(status) - query \(query)")
            return nil
        }
        guard let value = result else {
            print("AUTH: ERROR: Success, but by-ref return value was nil!")
            return nil
        }
        guard let data = value as? Data else {
            print("AUTH: ERROR: Failed understanding returned value of type \(type(of: result))")
            return nil
        }
        print("AUTH: DEBUG: Found \(data.count) bytes of data for account \(account) with service \(service).")
        return data
    }
}
