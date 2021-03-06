import Foundation

enum Keychain {
    static func add(account: String, service: String, data: Data) -> Bool {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecAttrService: service,
            ] as NSDictionary

        let exists = SecItemCopyMatching(query, nil) == errSecSuccess
        print("KEYCHAIN: DEBUG: generic password for account «\(account)» with service «\(service)» "
            + "\(exists ? "already exists" : "does not yet exist")")
        let status: OSStatus
        if exists {
            status = SecItemUpdate(query, [ kSecValueData: data, ] as NSDictionary)
        } else {
            let attributes = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: account,
                kSecAttrService: service,
                kSecValueData: data,
            ] as NSDictionary
            status = SecItemAdd(attributes, nil)
        }
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            print("KEYCHAIN: ERROR: Failed to add or update account «\(account)» with service «\(service)» keychain item: error \(status)")
            return false
        }
        print("KEYCHAIN: DEBUG: Saved \(data.count) bytes of data for account «\(account)» with service «\(service)».")
        return true
    }

    private static func buildQuery(account: String, service: String) -> NSDictionary {
        let query: NSDictionary = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecAttrService: service,
            kSecReturnData: true,
        ]
        return query
    }

    static func find(account: String, service: String) -> Data? {
        let query = buildQuery(account: account, service: service)
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
        print("AUTH: DEBUG: Found \(data.count) bytes of data for account «\(account)» with service «\(service)».")
        return data
    }

    static func delete(account: String, service: String) {
        let query = buildQuery(account: account, service: service)
        let status = SecItemDelete(query)
        guard status == errSecSuccess else {
            print("AUTH: ERROR: Failed to delete token from keychain: error \(status) - query \(query)")
            return
        }
        print("AUTH: DEBUG: Deleted token for account=«\(account)» service=«\(service)»")
    }
}
