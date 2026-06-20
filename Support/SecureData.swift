import Foundation

// @unchecked Sendable: Thread-safe because all access is via withUnsafeBytes which guarantees no concurrent access to the pointer during allocation, and the data is immutable thereafter.
final class SecureData: @unchecked Sendable {
    private let pointer: UnsafeMutablePointer<UInt8>?
    let count: Int
    
    var isEmpty: Bool { count == 0 }

    /// ⚠️ WARNING: Converting to String creates a heap-allocated copy that cannot
    /// be deterministically zeroized. Do not use for passwords or sensitive API tokens.
    var stringValue: String? {
        withUnsafeBytes { buffer in
            guard buffer.baseAddress != nil, !buffer.isEmpty else { return nil }
            return String(bytes: buffer, encoding: .utf8)
        }
    }

    init(data: Data) {
        let count = data.count
        self.count = count
        if count > 0 {
            let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
            data.copyBytes(to: ptr, count: count)
            self.pointer = ptr
        } else {
            self.pointer = nil
        }
    }

    init(trimmingASCIIWhitespace data: Data) {
        let whitespace: Set<UInt8> = [0x20, 0x09, 0x0A, 0x0B, 0x0C, 0x0D]
        guard let first = data.firstIndex(where: { !whitespace.contains($0) }),
              let last = data.lastIndex(where: { !whitespace.contains($0) }) else {
            self.count = 0
            self.pointer = nil
            return
        }
        
        let count = last - first + 1
        self.count = count
        let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        data.copyBytes(to: ptr, from: first..<(last + 1))
        self.pointer = ptr
    }

    deinit {
        if let pointer = pointer, count > 0 {
#if canImport(Darwin)
            _ = memset_s(pointer, count, 0, count)
#elseif canImport(Glibc)
            explicit_bzero(pointer, count)
#elseif canImport(Musl)
            explicit_bzero(pointer, count)
#else
            var volatilePtr = pointer
            for i in 0..<count {
                volatilePtr.advanced(by: i).pointee = 0
            }
#endif
            pointer.deallocate()
        }
    }

    func withUnsafeBytes<T>(_ body: (UnsafeRawBufferPointer) throws -> T) rethrows -> T {
        guard let pointer = pointer, count > 0 else {
            return try body(UnsafeRawBufferPointer(start: nil, count: 0))
        }
        return try withExtendedLifetime(self) {
            try body(UnsafeRawBufferPointer(start: pointer, count: count))
        }
    }
}
