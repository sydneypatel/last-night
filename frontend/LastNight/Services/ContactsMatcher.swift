//
//  ContactsMatcher.swift
//  LastNight
//
//  Created by Sydney Patel on 6/27/26.
//


import Foundation
import Contacts
import CryptoKit

struct ContactsMatcher {
    
    // Request contacts permission and return hashed phone numbers
    static func requestAndHashContacts() async -> [String]? {
        let store = CNContactStore()
        
        let granted = await withCheckedContinuation { continuation in
            store.requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
        
        guard granted else { return nil }
        
        let keys = [CNContactPhoneNumbersKey] as [CNKeyDescriptor]
        var hashes: [String] = []
        
        let fetchRequest = CNContactFetchRequest(keysToFetch: keys)
        await Task.detached(priority: .userInitiated) {
            try? store.enumerateContacts(with: fetchRequest) { contact, _ in
                for phone in contact.phoneNumbers {
                    let normalized = ContactsMatcher.normalizePhone(phone.value.stringValue)
                    if !normalized.isEmpty {
                        hashes.append(ContactsMatcher.sha256(normalized))
                    }
                }
            }
        }.value
        
        return hashes.isEmpty ? nil : hashes
    }
    
    // Normalize phone: strip everything except digits, ensure E.164-ish
    static func normalizePhone(_ raw: String) -> String {
        let digits = raw.filter { $0.isNumber }
        if digits.count == 10 {
            return "+1\(digits)" // assume US
        } else if digits.count == 11, digits.hasPrefix("1") {
            return "+\(digits)"
        } else if digits.count > 10 {
            return "+\(digits)"
        }
        return ""
    }
    
    // SHA-256 hash
    static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // Hash a single phone number (for saving user's own number)
    static func hashPhone(_ raw: String) -> String? {
        let normalized = normalizePhone(raw)
        guard !normalized.isEmpty else { return nil }
        return sha256(normalized)
    }
}
