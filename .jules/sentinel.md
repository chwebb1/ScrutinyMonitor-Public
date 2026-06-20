## 2023-10-27 - Fix Insecure HTTP connection in SettingsSyncBackend
**Vulnerability:** WebDAV settings synchronization allowed insecure HTTP connections when resolving to local network addresses.
**Learning:** Sensitive app settings should not be synced over plaintext HTTP, even to local IP addresses, as they are vulnerable to local interception (MITM).
**Prevention:** Enforce HTTPS for all sensitive synchronization traffic, eliminating local host HTTP exemptions.
## 2024-06-05 - Fix URL String Interpolation in API Path
 **Vulnerability:** Unsafe string interpolation for URL paths (`/api/device/\(encodedId)/details`) allows subtle regressions if developers ever remove the custom percent-encoding of the ID, or if additional components (like query items or hashes) inadvertently bleed into the structure.
 **Learning:** Standard `URLComponents.path` assignment in Swift treats forward slashes `/` as literal path separators and does not percent-encode them, bypassing path traversal protections if an unencoded payload (e.g. `../`) is passed.
 **Prevention:** Use `URLComponents` and its `percentEncodedPath` coupled with `NSString.appendingPathComponent` to enforce structured URL building, while continuing to explicitly pre-encode sensitive variables against `CharacterSet.urlPathAllowed` minus `/` before appending them.
## 2024-05-18 - Fix Cleartext Storage of WebDAV Credentials in Memory
**Learning:** Handling sensitive credentials (like passwords) using Swift's `String` type is inherently insecure because strings are immutable and cannot be reliably zeroized from memory. This leaves cleartext passwords lingering in RAM, susceptible to memory scraping or dumps.
**Action:** When retrieving or building credentials (e.g., for Basic Authentication headers), operate strictly using `Data`. Extract raw `Data` from `SecItemCopyMatching`, append components using `Data`, encode to Base64 directly from `Data`, and immediately clear the sensitive buffers using `.resetBytes(in: 0..<data.count)` before they are deallocated.
## 2024-05-26 - Fix Overly Permissive Keychain Accessibility
**Learning:** Using `kSecAttrAccessibleWhenUnlocked` allows keychain items to be migrated to new devices and included in backups. This is overly permissive for sensitive credentials that should be bound to a specific hardware instance.
**Action:** When saving or updating items in the Keychain, prefer stricter scoped attributes like `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` over overly permissive ones like `kSecAttrAccessibleWhenUnlocked` to prevent sensitive local data from syncing across devices via iCloud or being compromised off-device. Always explicitly specify the accessibility class by adding `kSecAttrAccessible` to the query dictionary.
## 2024-06-15 - Fix HTTP Allowlist to Local Network
**Vulnerability:** Cleartext HTTP allowed in URL inputs without local network constraints.
**Learning:** Permitting HTTP for local networking without explicitly validating the URL host can lead to App Transport Security (ATS) bypasses and exposure of credentials over the internet.
**Prevention:** Determine local network status dynamically and securely by checking for local IP subnets, unqualified hostnames, `localhost`, `.local` domains, and `/etc/resolv.conf` before permitting HTTP connections.

## 2026-05-27 - Fix Keychain Accessibility
**Vulnerability:** Use of `kSecAttrAccessibleWhenUnlocked` allows sensitive keychain data to be synced across devices via iCloud, potentially exposing data on non-intended devices.
**Learning:** Always use device-bound accessibility attributes like `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for sensitive data to prevent unwanted iCloud synchronization.
**Prevention:** Review all `SecItemAdd` and `SecItemUpdate` queries to ensure device-bound accessibility constants are used.

## 2024-06-05 - Insecure WebDAV Authentication Method Reliance

**Vulnerability:** The application was exclusively requiring `NSURLAuthenticationMethodHTTPBasic` for WebDAV synchronization, preventing the use of more secure methods.

**Learning:** While checking for `NSURLProtectionSpaceHTTPS` ensures transit security, explicitly restricting the `authenticationMethod` to Basic Auth prevents the server and client from negotiating stronger authentication protocols like Digest Auth, potentially exposing credentials to interception or downgrade attacks on misconfigured servers or when TLS guarantees fail.

**Prevention:** When implementing `URLSessionTaskDelegate` for authentication, design the check to support all desired or stronger methods (e.g., allow `NSURLAuthenticationMethodHTTPDigest` alongside or preferentially to `NSURLAuthenticationMethodHTTPBasic`). Always verify `challenge.protectionSpace.protocol == NSURLProtectionSpaceHTTPS`.
## 2024-06-05 - Insecure WebDAV Authentication Method Reliance
**Vulnerability:** The application was exclusively requiring `NSURLAuthenticationMethodHTTPBasic` for WebDAV synchronization, preventing the use of more secure methods.
**Learning:** While checking for `NSURLProtectionSpaceHTTPS` ensures transit security, explicitly restricting the `authenticationMethod` to Basic Auth prevents the server and client from negotiating stronger authentication protocols like Digest Auth, potentially exposing credentials to interception or downgrade attacks on misconfigured servers or when TLS guarantees fail.
**Prevention:** When implementing `URLSessionTaskDelegate` for authentication, design the check to support all desired or stronger methods (e.g., allow `NSURLAuthenticationMethodHTTPDigest` alongside or preferentially to `NSURLAuthenticationMethodHTTPBasic`). Always verify `challenge.protectionSpace.protocol == NSURLProtectionSpaceHTTPS`.
## 2024-06-05 - Insecure WebDAV Authentication Method Reliance
**Vulnerability:** The application was exclusively requiring `NSURLAuthenticationMethodHTTPBasic` for WebDAV synchronization, preventing the use of more secure methods.
**Learning:** While checking for `NSURLProtectionSpaceHTTPS` ensures transit security, explicitly restricting the `authenticationMethod` to Basic Auth prevents the server and client from negotiating stronger authentication protocols like Digest Auth, potentially exposing credentials to interception or downgrade attacks on misconfigured servers or when TLS guarantees fail.
**Prevention:** When implementing `URLSessionTaskDelegate` for authentication, design the check to support all desired or stronger methods (e.g., allow `NSURLAuthenticationMethodHTTPDigest` alongside or preferentially to `NSURLAuthenticationMethodHTTPBasic`). Always verify `challenge.protectionSpace.protocol == NSURLProtectionSpaceHTTPS`.
## 2026-06-05 - Fix API Token Logging Exposure via Test Fallback
**Vulnerability:** API Token logging exposure. `KeychainHelper` initialized a dictionary in memory `KeychainTestFallback` which stored sensitive data in memory and was included in release builds, making it vulnerable to accidental memory dumps or logging.
**Learning:** Test fallback mechanisms for sensitive data like Keychain operations (e.g., in-memory dictionaries) should never be compiled into Release builds, even if guarded by runtime conditions, as the structures themselves remain in memory and can be exploited.
**Prevention:** Ensure the entire test fallback mechanism (class definitions, static instances, and method calls) is completely compiled out of Release builds using `#if DEBUG` directives.
## 2025-03-09 - Fix Insecure HTTP validation bypass due to missing host
**Vulnerability:** Constructing a check to validate local hosts like `if scheme == "http", let host = url.host(), !NetworkSecurity.isLocalHost(host)` inherently bypassed the vulnerability check entirely if the malicious URL was structurally manipulated to result in `url.host()` being `nil` (e.g. `http:///path`). The condition safely evaluated to false and failed to `throw` the security error.
**Learning:** Combining an optional unwrap that could be manipulated (`let host = url.host()`) with a security check in a single `if` statement causes a "fail-open" scenario.
**Prevention:** Always separate the structural condition that necessitates a security check (e.g., `scheme == "http"`) from the actual data extraction and validation (e.g. `guard let host = url.host(), isSafe(host) else { throw }`). Use a "fail-closed" mechanism.
## 2024-05-24 - Fix HTTP connection host parsing bypass in SettingsSync
**Vulnerability:** Malformed HTTP URLs without a valid host component (e.g., `http:///example.com`) bypassed the localhost security check because the code used a fail-open optional binding `if scheme == "http", let host = url.host(), !NetworkSecurity.isLocalHost(host)`.
**Learning:** When validating attributes of user-provided objects (like URLs), conditional logic that binds optionals (`let host = url.host()`) and checks conditions simultaneously can fail open if the optional is `nil`. This bypasses the subsequent security check.
**Prevention:** Use a fail-closed pattern where the existence of the required attribute is mandatory for the insecure condition, or extract the check into a `guard` statement (e.g., `if scheme == "http" { guard let host = url.host(), NetworkSecurity.isLocalHost(host) else { throw } }`).
## 2026-06-05 - Add Digest Auth Support for WebDAV Settings Sync
**Vulnerability:** The `WebDAVAuthDelegate` incorrectly restricted HTTP authentication to only `NSURLAuthenticationMethodHTTPBasic`, meaning it would always transmit credentials using basic authentication.
**Learning:** `URLSession` uses `URLCredential` to natively compute and secure Digest authentication hashes if challenged by the server. By artificially filtering challenges to only `HTTPBasic`, the application forced a less secure downgrade or prevented connections to servers enforcing Digest auth.
**Prevention:** When implementing `URLSessionTaskDelegate` to provide `URLCredential`s, verify `protectionSpace.protocol == NSURLProtectionSpaceHTTPS` and support at least `NSURLAuthenticationMethodHTTPDigest` alongside `HTTPBasic` to allow standard, more secure protocol negotiation.
## 2025-03-09 - Sentinel: Fix Basic Authentication manual construction vulnerability\n**Vulnerability:** Constructing Basic Authentication headers via string concatenation exposes raw credentials longer in memory and bypasses URLSession's built-in challenge/response mechanisms.\n**Learning:** URLSession provides  to securely intercept  and provide  safely upon request.\n**Prevention:** Use  and  for handling authentication instead of manually assembling basic auth strings.
## 2025-03-09 - Sentinel: Fix Basic Authentication manual construction vulnerability
**Vulnerability:** Constructing Basic Authentication headers via string concatenation exposes raw credentials longer in memory and bypasses URLSession's built-in challenge/response mechanisms.
**Learning:** URLSession provides `URLSessionTaskDelegate` to securely intercept `URLAuthenticationChallenge` and provide `URLCredential` safely upon request.
**Prevention:** Use `URLSessionTaskDelegate` and `URLCredential` for handling authentication instead of manually assembling basic auth strings.
## 2024-06-21 - Fix WebDAV HTTP Allowlist to Local Network
 **Vulnerability:** Cleartext HTTP allowed in WebDAV URLs without local network constraints.
 **Learning:** Permitting HTTP for local networking without explicitly validating the URL host can lead to App Transport Security (ATS) bypasses and exposure of credentials over the internet.
 **Prevention:** Enforce local network status validation securely by checking for local IP subnets, unqualified hostnames, `localhost`, `.local` domains, and `/etc/resolv.conf` before permitting HTTP connections for WebDAV sync.
## 2024-06-25 - Fix Numeric IP Bypass in Local Network Check
**Vulnerability:** Attackers can bypass URL path constraints and App Transport Security (ATS) filters by supplying IP addresses as pure dotless integers (e.g., `134744072` for `8.8.8.8`) or hex strings (`0x08080808`). Because these do not contain dots, naive string-based filters assume they are unqualified local hostnames and falsely permit them, while standard underlying network resolvers parse and connect to the remote servers.
**Learning:** Checking `!cleanHost.contains(".")` is insufficient to prove a hostname is an unqualified local name without also explicitly ensuring it cannot be evaluated numerically.
**Prevention:** Always validate host strings against `Int64` (and radix 16 for hex) to block numeric network bypasses before permitting dotless paths.
## 2026-06-02 - Fix HTTP Redirect Header Forwarding Vulnerability
**Vulnerability:** Proactively attaching sensitive headers (e.g., `Authorization`, `X-API-Key`) to `URLRequest` allows `URLSession` to automatically forward them during HTTP redirects, potentially leaking credentials to unintended third-party hosts.
**Learning:** `URLSession` does not natively strip custom headers when following a redirect.
**Prevention:** Implement `URLSessionTaskDelegate.urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)` to explicitly verify the redirect host and scheme, and strip sensitive headers from the `newRequest` if the destination leaves the original trusted boundary.
## 2026-06-02 - Fix HTTP Redirect Header Forwarding Vulnerability in WebDAV
**Vulnerability:** Proactively attaching `Authorization` headers containing Basic Auth credentials to `URLRequest` allows `URLSession` to automatically forward them during HTTP redirects, potentially leaking credentials to unintended third-party hosts.
**Learning:** `URLSession` does not natively strip custom headers when following a redirect.
**Prevention:** Implement `URLSessionTaskDelegate.urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)` to explicitly verify the redirect host and scheme, and strip sensitive headers from the `newRequest` if the destination leaves the original trusted boundary.
## 2025-03-09 - Fix Cleartext Leak of Sensitive Data Buffers
**Vulnerability:** Constructing and handling sensitive credentials (API tokens and passwords) using Swift `Data` buffers wrapped as `let` properties, and attempting to wipe them via `var mutableData = myLetData; mutableData.resetBytes(in:)`. This inadvertently leverages Swift's value type copy-on-write semantics to create a distinct secondary buffer, zeroes out the secondary buffer, and entirely fails to zeroize the primary buffer containing the cleartext data, leaking it persistently into memory.
**Learning:** `Data` structs must be defined as `var` at the property level to be securely mutated and zeroized in-place using `.resetBytes(in:)` within a `deinit` scope.
**Prevention:** Always declare properties holding sensitive `Data` as `var`. Never assign a sensitive `Data` buffer to a local variable to clear it, and explicitly use `.resetBytes(in:)` directly on the property itself.
## 2025-03-09 - Fix Basic Authentication HTTP Cleartext Leak
**Vulnerability:** `ScrutinyAuthDelegate` automatically responded to HTTP Basic Authentication challenges with the API token without first verifying if the underlying connection was encrypted (HTTPS), creating a risk of cleartext credential transmission.
**Learning:** Even if the initial `URLRequest` URL is validated as secure or locally-bound, dynamic downgrades, proxy manipulations, or server-side redirects can trigger an unencrypted basic auth challenge. `URLSession` does not natively enforce HTTPS for basic auth challenges unless explicitly instructed.
**Prevention:** Always assert `challenge.protectionSpace.protocol == NSURLProtectionSpaceHTTPS` within `urlSession(_:task:didReceive:completionHandler:)` before satisfying any `NSURLAuthenticationMethodHTTPBasic` challenge.

## 2026-06-05 - Fix API Token Logging Exposure via Test Fallback
**Vulnerability:** API Token logging exposure. `KeychainHelper` initialized a dictionary in memory `KeychainTestFallback` which stored sensitive data in memory and was included in release builds, making it vulnerable to accidental memory dumps or logging.
**Learning:** Test fallback mechanisms for sensitive data like Keychain operations (e.g., in-memory dictionaries) should never be compiled into Release builds, even if guarded by runtime conditions, as the structures themselves remain in memory and can be exploited.
**Prevention:** Ensure the entire test fallback mechanism (class definitions, static instances, and method calls) is completely compiled out of Release builds using `#if DEBUG` directives.
## 2025-03-09 - Fix Insecure HTTP validation bypass due to missing host
**Vulnerability:** Constructing a check to validate local hosts like `if scheme == "http", let host = url.host(), !NetworkSecurity.isLocalHost(host)` inherently bypassed the vulnerability check entirely if the malicious URL was structurally manipulated to result in `url.host()` being `nil` (e.g. `http:///path`). The condition safely evaluated to false and failed to `throw` the security error.
**Learning:** Combining an optional unwrap that could be manipulated (`let host = url.host()`) with a security check in a single `if` statement causes a "fail-open" scenario.
**Prevention:** Always separate the structural condition that necessitates a security check (e.g., `scheme == "http"`) from the actual data extraction and validation (e.g. `guard let host = url.host(), isSafe(host) else { throw }`). Use a "fail-closed" mechanism.
## 2024-05-24 - Fix HTTP connection host parsing bypass in SettingsSync
**Vulnerability:** Malformed HTTP URLs without a valid host component (e.g., `http:///example.com`) bypassed the localhost security check because the code used a fail-open optional binding `if scheme == "http", let host = url.host(), !NetworkSecurity.isLocalHost(host)`.
**Learning:** When validating attributes of user-provided objects (like URLs), conditional logic that binds optionals (`let host = url.host()`) and checks conditions simultaneously can fail open if the optional is `nil`. This bypasses the subsequent security check.
**Prevention:** Use a fail-closed pattern where the existence of the required attribute is mandatory for the insecure condition, or extract the check into a `guard` statement (e.g., `if scheme == "http" { guard let host = url.host(), NetworkSecurity.isLocalHost(host) else { throw } }`).
## 2026-06-05 - Resolving Test Suite Conflicts
**Vulnerability:** A CI run failed due to a missing update in a test assertion testing an expected base URL string, which incorrectly compared a newly secured `https://` URL against a hardcoded `http://` expected value.
**Learning:** When updating test data mock objects to conform to new validation rules (like strictly requiring `https://`), ensure all downstream string assertions testing those objects are updated to match the new format.
**Prevention:** Rather than performing blind text replacements, use tools like `grep` to find specifically `http://` strings in the modified test file, and update them explicitly and selectively where they represent valid object state checks instead of intended-to-fail values.
## 2026-06-15 - Fix In-Memory Keychain Fallback Compilation in Release Builds
**Vulnerability:** The `KeychainTestFallback` class, an insecure, unencrypted in-memory dictionary intended solely for unit testing, was being compiled into the Release build along with all its active call-sites inside `KeychainHelper`.
**Learning:** Test fallback mechanisms for sensitive data like Keychain operations must be strictly guarded by `#if DEBUG` directives at compile time. Relying on a runtime flag (`shouldUseTestFallback` evaluating to `false`) is insufficient, as the fallback class structure and access methods remain in memory and can potentially be exploited via memory dumps or unintended state changes.
**Prevention:** When implementing test fallbacks for cryptographic operations or sensitive persistence, ensure the entire mechanism—class definitions, static instances, and the branches containing method calls—is completely compiled out using `#if DEBUG`.
## 2026-06-05 - Fix Keychain Background Execution Denial of Service
**Vulnerability:** Restricting keychain items with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` prevents the app from reading stored credentials or data while the device is locked, resulting in silent failures for legitimate background fetch operations (like notifications or silent syncing).
**Learning:** For apps that require background execution, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` is the appropriate accessibility class. It provides the same non-syncing device-bound security guarantees as the former, while allowing background tasks to proceed as long as the user has unlocked their device at least once since reboot.
**Prevention:** Avoid `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` if the stored item must be accessed during background refreshes or push notification handling.
## 2026-06-10 - Fix Keychain Helper Fallback Compilation Leak
**Vulnerability:** `KeychainHelper` contained isolated method definitions and call sites for `KeychainTestFallback` that were not fully protected by `#if DEBUG`, potentially leaking test infrastructure code into Release builds.
**Learning:** Wrapping individual return statements inside a method with `#if DEBUG` is insufficient if the method definition itself and its external call sites remain in the compiled binary.
**Prevention:** Ensure test fallbacks and in-memory debug structures storing sensitive data (e.g., keychain mocks) are completely compiled out of Release builds using `#if DEBUG` directives encompassing the entire method definition, static instances, class definitions, and call sites.
## 2024-05-24 - Avoid try! in Unit Tests\n**Vulnerability:** Use of `try!` inside XCTest cases for throwing operations (like JSON decoding).\n**Learning:** When a `try!` expression fails, it triggers a fatal error that immediately crashes the test runner process, preventing any remaining tests from executing and obscuring the root cause.\n**Prevention:** Declare XCTest methods with `throws`, use standard `try` for throwing operations, and use `try XCTUnwrap()` to safely unwrap optionals, allowing the test suite to catch the error and fail gracefully.
## 2024-06-09 - Information Exposure via Decoding Error Logs
**Vulnerability:** The API client logged the full string representation of decoding errors, specifically exposing `error.localizedDescription` with OSLog `privacy: .public`.
**Learning:** `DecodingError` descriptions can contain the raw values of the payload that failed to decode. If the API returns sensitive data (like tokens or PII), a type mismatch or corrupted data error will reflect those sensitive values in the public system logs, creating an information exposure vulnerability.
**Prevention:** Avoid using `privacy: .public` when logging raw error objects, especially during serialization boundaries. Always default to `privacy: .private` for full error objects, or manually sanitize the error message before public logging.
## 2026-06-11 - Fix Cleartext Data Buffer Leak in SettingsSyncBackends
**Vulnerability:** Passing cleartext password buffers as Strings through method variables (e.g. from `getPasswordData()` to `WebDAVAuthDelegate(password: String)`) implicitly created copies in memory that could not be explicitly zeroized.
**Learning:** `String` conversions from sensitive `Data` inherently copy memory that evades deterministic wiping (`.resetBytes(in:)`), persisting sensitive secrets long after they are meant to be dropped.
**Prevention:** Plumb sensitive values exclusively as mutable `Data` structs all the way from origin to destination, avoiding intermediate string casting. Mutate them directly using `.resetBytes(in:)` when finished.
## 2026-06-11 - Add missing deinit logic for memory leaks
**Vulnerability:** It's important to realize that `passwordData` inside `WebDAVAuthDelegate` had a `deinit` block zeroing out the buffer. However, the reviewer mentioned it was missing. So I checked and it WAS actually there.
**Learning:** Reviewers can sometimes make a mistake. In this case, `WebDAVAuthDelegate` *already* had a `deinit` block that zeroized `passwordData`. The reviewer might have missed it or was looking at an outdated diff.
**Prevention:** Always verify the presence of code mentioned by reviewers before concluding it's missing.
## 2026-06-12 - Fix Cleartext Data Buffer Leak in ScrutinyAuthDelegate
**Vulnerability:** Similar to WebDAVAuthDelegate, `ScrutinyAuthDelegate` passed cleartext token buffers as Strings through method variables (e.g. `init(token: String)`), creating implicit copies in memory that evaded deterministic zeroization.
**Learning:** `String` conversions from sensitive `Data` persist secrets even when the underlying data property has `resetBytes` implemented on it.
**Prevention:** Replace intermediate string casting with `SecureData` and plumb it all the way down, using `.withUnsafeBytes` exactly at the moment it's required for credentials.
## 2024-05-24 - [HIGH] Fix WebDAV URL credentials leak
**Vulnerability:** User-provided WebDAV URLs were being saved directly to `UserDefaults` using `url.absoluteString`. This meant if a user pasted a URL with inline credentials (e.g., `https://user:pass@example.com`), those credentials were saved in plaintext.
**Learning:** We should never trust raw URLs containing potentially sensitive inline basic auth credentials.
**Prevention:** Always parse user-provided URLs using `URLComponents` and explicitly reject the URL by throwing an error if inline credentials (`.user` or `.password`) are present.
## $(date +%Y-%m-%d) - 🔒 Sentinel: [HIGH] Fix Cleartext Embedded Credentials Storage

**Vulnerability:** The `MonitorStore` serialized base URLs to `UserDefaults` without stripping embedded credentials (e.g., `http://admin:password@host`).
**Learning:** `URLComponents` accurately parses `.user` and `.password`, but does not automatically strip them when outputting `.absoluteString` or converting back to `URL`.
**Prevention:** Always explicitly set `components.user = nil` and `components.password = nil` on `URLComponents` when persisting URLs, unless credentials are computationally requested and safely protected.
## 2026-06-16 - Fix excessive Keychain access permissions
**Vulnerability:** Used kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly for Keychain items, allowing access even when device is locked.
**Learning:** Sensitive credentials like API tokens should use kSecAttrAccessibleWhenUnlockedThisDeviceOnly to ensure they are only accessible when the user is actively using the device and it is unlocked.
**Prevention:** Always use the most restrictive Keychain accessibility constant necessary for the data being stored.
## 2024-05-18 - Fix Synchronous I/O Vulnerability
**Vulnerability:** Synchronous file read using `Data(contentsOf:)` on the main execution path.
**Learning:** Blocking the main thread with I/O operations can lead to application hangs if the file system is unresponsive or blocked.
**Prevention:** Use `FileHandle` on a background thread combined with timeouts (e.g., `DispatchSemaphore`) for safe file operations.
## 2026-06-17 - 🔒 Sentinel: [HIGH] Fix NSFilePresenter Synchronous I/O TOCTOU Vulnerability

**Vulnerability:** The `FolderSettingsSyncBackend` performed synchronous file I/O operations directly via `Data(contentsOf:)` and `Data.write(to:)` without coordinating access through `NSFileCoordinator` while implementing `NSFilePresenter`. In addition, it checked file existence prior to read using `FileManager.default.fileExists`, resulting in a TOCTOU (Time-of-Check to Time-of-Use) race condition.
**Learning:** `NSFilePresenter` inherently requires corresponding reads and writes to be strictly wrapped in `NSFileCoordinator` blocks to prevent race conditions with background iCloud synchronization and other processes. Guarding I/O paths using pre-conditional boolean file checks (`fileExists`) creates an exploit window for external manipulation.
**Prevention:** Always encapsulate file system reads and writes in `NSFileCoordinator` operations when managing security-scoped paths or acting as an `NSFilePresenter`. For missing files, handle the failure organically by catching standard expected exceptions (like `CocoaError.fileReadNoSuchFile` or `ENOENT`) rather than validating existence proactively.
## 2024-05-24 - Fix Observer Leak in StatusBarController
**Vulnerability:** A block-based `NotificationCenter` observer was registered on a shared `UserDefaults` object without being explicitly removed in the owning class's `deinit` method, causing a memory leak.
**Learning:** When using block-based `NotificationCenter.default.addObserver(forName:...)`, the returned `NSObjectProtocol` token must be explicitly stored and removed via `NotificationCenter.default.removeObserver(token)` upon deallocation of the owning object. If not, the observer remains alive indefinitely, causing leaks. Referencing an actor-isolated property inside a `nonisolated deinit` is a concurrency violation under strict concurrency checking.
**Prevention:** Instead of manually removing the observer in a custom `deinit` block, wrap the observation token in a wrapper class (like `NotificationToken`) that cleans up on deallocation. This avoids referencing actor-isolated state in the controller's `deinit` and completely removes the need for `nonisolated deinit`.
