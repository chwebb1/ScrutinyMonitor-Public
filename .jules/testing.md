## 2026-06-02 - ViewInspector Button Finding with Labels
**Learning:** When using ViewInspector to find a `Button` that wraps a `Label` (e.g., `Label("Text", systemImage: "...")`) on macOS, using `find(button: "Text")` can fail with "Search did not find a match" and "Possible blockers: AccessibilityImageLabel".
**Action:** Use the more robust type-based search `find(ViewType.Button.self, containing: "Text")` to successfully locate the button in the view hierarchy.
## 2026-06-02 - ScrutinyAuthDelegate Security Testing
**Learning:** The `ScrutinyAuthDelegate` securely manages `Authorization` and `X-API-Key` headers during HTTP redirects by stripping them on host changes or scheme downgrades.
**Action:** Added `ScrutinyAuthDelegateTests.swift` to explicitly unit test this behavior using `XCTestExpectation` and simulated `URLSession` redirect handlers, ensuring this critical security layer is verified without modifying production code.
## 2026-06-03 - MockURLProtocol Data Races
**Learning:** Mutating a captured local variable (like `callCount`) inside a custom `MockURLProtocol.requestHandler` closure without synchronization leads to data races and flaky tests because `URLSession` executes these closures on background queues.
**Action:** Always protect local state accessed within `MockURLProtocol.requestHandler` closures using an `NSLock` (e.g., `lock.withLock { callCount += 1 }`).
## 2026-06-07 - Invalid Parameter Edge Case Coverage
**Learning:** When requested to test "invalid parameters on a Mock store and expecting an error", it is critical to verify *all* failure branches inside the target validation function (e.g., `validateInputs`). Relying only on pre-existing tests that cover a subset of invalid scenarios (like empty URL or wrong scheme) leaves structural vulnerabilities around bounds checking (e.g., token length limits) and character filtering (e.g., control characters).
**Action:** Always fully read the validation constraints of the target function and trace each condition against the existing tests to identify and implement the missing bounds checks.
## 2024-06-07 - Testing SwiftUI Asynchronous Error States
**Learning:** Testing an asynchronous `.task` driven error state requires ViewInspector setup (injecting `inspection` and using `.onReceive`) to capture the view after the background work completes and state updates are processed.
**Action:** When adding snapshot/inspector tests for SwiftUI views doing network requests, ensure the `MockURLProtocol` is properly registered to intercept requests and the View has the `inspection` scaffolding.
## 2026-06-08 - AppKit AppDelegate Testing
**Learning:** When unit testing macOS AppKit application delegates in a headless XCTest environment (e.g., `swift test`), `NSApp` (and `NSApplication.shared`) is `nil` by default. Explicitly initializing it is necessary to prevent implicit unwrap crashes when invoking lifecycle methods like `applicationDidFinishLaunching` that interact with the application instance.
**Action:** Add `_ = NSApplication.shared` to the `setUp()` method of the test class.
## 2026-06-08 - Test Target AppKit Imports
**Learning:** When creating new test files in a SwiftPM target that reference AppKit types (like `NSApplication` or `NSApp`), you must explicitly `import AppKit` alongside `XCTest`. Relying solely on `@testable import` of the main application module will result in unresolved identifier compilation errors.
**Action:** Always include `import AppKit` when authoring test cases for macOS-specific features.
## 2026-06-08 - AppKit Headless Environment Detection
**Learning:** When verifying if code is running in a headless test environment (e.g., `swift test`), checking `ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil` is insufficient as it may not be set in CI. Check if `Bundle.main.bundleURL.pathExtension != "app"` to reliably detect execution outside an application bundle (like `.xctest`).
**Action:** Always include the bundle path extension check alongside the environment variable check when conditionally bypassing AppKit lifecycle logic.
## 2026-06-08 - Validating All Failure Branches
**Learning:** When testing validation functions or invalid inputs, do not rely solely on existing test cases that cover obvious scenarios (like empty values or wrong schemes). Explicitly verify all failure paths defined in the implementation to ensure coverage for structural vulnerabilities like bounds checking (e.g., length limits) and character filtering (e.g., control characters).
**Action:** When adding missing input tests, trace all conditions within the target method (e.g., `validateInputs`) and verify against existing tests to identify and implement the missing bounds checks.
## 2026-06-10 - Thoroughly Read Test Requests Before Defaulting to Codable
**Learning:** When tasked with testing specific business logic or calculations (e.g., initializer status conditions), implement exhaustive unit tests covering all requested parameter combinations and edge cases (e.g., negative values, truncation). Do not substitute requested logic tests with generic structural tests like `Codable` (encode/decode) verification.
**Action:** Before writing tests, explicitly verify the *why* of the issue. If the prompt asks for "initializer logic", write tests that invoke the initializer directly with different parameter matrices rather than testing JSON decoding outputs.
## 2026-06-10 - Verifying All Data Parsing Branches
**Learning:** When adding tests for data aggregation models (like `OverviewTotals` calculating counts from installations), ensure tests cover all conditional branches handling nil values or differing statuses (e.g., `offline` vs `unknown`), not just the happy path.
**Action:** Use exploratory tools (e.g. `sed -n`) to identify exact initialization parameters of embedded models (like `InstallationSnapshot`) when constructing mock data for thorough coverage of aggregation branches.
## 2026-06-10 - Mock Object Determinism
**Learning:** Using `Date()` to initialize properties on mock objects introduces a non-deterministic element to tests, which can lead to flaky, intermittent failures around time boundaries.
**Action:** Always use a fixed, deterministic epoch (e.g., `Date(timeIntervalSince1970: 0)`) when instantiating mock structures requiring a Date.
## 2026-06-10 - Fail-Fast Mocks
**Learning:** Providing silent fallbacks in test helpers (e.g., `URL(string: string) ?? URL(fileURLWithPath: "")`) masks invalid test setup and leads to confusing downstream failures.
**Action:** Design static test mock helpers to force-unwrap compile-time constants (e.g., `URL(string: string)!`) so invalid inputs fail immediately and loudly at the source.
## 2026-06-10 - Isolated Edge Case Verification
**Learning:** Testing an aggregation model with a mixed array containing all varied inputs simultaneously (rather than creating multiple isolated test methods) is an effective and realistic way to exercise the accumulation behavior and ensure that differing states do not interfere with one another during iteration.
**Action:** When validating collection reduction or array accumulation logic, provide a comprehensive array containing all required edge cases at once and assert the final aggregated totals, rather than splitting each state into a separate assertion scope.
## 2026-06-10 - Thoroughly Read Test Requests Before Defaulting to Codable
**Learning:** When tasked with testing specific business logic or calculations (e.g., initializer status conditions), implement exhaustive unit tests covering all requested parameter combinations and edge cases (e.g., negative values, truncation). Do not substitute requested logic tests with generic structural tests like `Codable` (encode/decode) verification.
**Action:** Before writing tests, explicitly verify the *why* of the issue. If the prompt asks for "initializer logic", write tests that invoke the initializer directly with different parameter matrices rather than testing JSON decoding outputs.
## 2026-06-10 - Explicit Hashable Testing
**Learning:** When testing models that conform to `Identifiable` and `Hashable` with custom `id` properties (like combined UUIDs), explicitly test both `Equatable` and `Hashable` conformance by verifying identical property values hash identically and equal each other, rather than just asserting the string format of the `id`.
**Action:** Add comprehensive equality and hashability test scenarios to the test case, validating both positive matches and negative mismatches.
## 2026-06-10 - Refactoring Monolithic State Tests
**Learning:** Writing a single test function (like `testStatusLogic`) to sequentially evaluate various states (refreshing, error, snapshot) is an anti-pattern. If an early assertion fails, the remaining states are never tested, hiding failures.
**Action:** Always refactor sequential, multi-state assertions into individual, focused unit tests that verify exactly one logical branch or precedence rule (e.g., `testStatusIsRefreshingTakesPrecedence`).
## 2026-06-10 - Adding comprehensive model initialization tests
**Learning:** When developing models that transform simple data structures into complex UI elements (like deriving multiple cells from an array of values), testing the initialization logic requires explicitly matching the derived array's attributes (count, indices, dynamic IDs) to the input values.
**Action:** Always create tests that map the generated internal properties (like row-based IDs) back to their enumerated source inputs to prevent subtle UI mapping regressions.
## 2026-06-10 - Add Fallback Test Coverage for SmartResult Attributes
**Learning:** Understanding precisely how complex JSON structs fall back across multiple types in an initialized decoder requires exhaustive test cases mirroring the `catch` blocks.
**Action:** Always verify every fallback condition (e.g. array of objects, array of strings, invalid types) using dedicated tests when multiple `catch` checks exist for a specific JSON key.
## 2026-06-11 - Test Derived Properties Explicitly
**Learning:** When verifying derived properties computed from decoded models, explicitly assert against expected concrete literal strings (e.g., "35 C") rather than comparing against underlying helper methods or re-computations (e.g., Optional.some(35).temperatureText). This ensures formatting logic regressions are explicitly caught.
**Action:** Explicitly define the expected output string to capture formatting logic regressions in tests.
## 2026-06-10 - Comprehensive Tests for OverviewTotals
**Learning:** OverviewTotals initialization purely aggregates data, so creating explicit mock objects mapping to happy paths, offline paths, and mixed arrays ensures accuracy.
**Action:** Apply this comprehensive granular test structure to all other structural initializers.
## 2026-06-10 - Decoding Tests
**Learning:** When requested to verify derived properties resulting from decoding operations, it is critical to explicitly assert against those calculated fields using mock data that simulates realistic, fully populated payloads (the "happy path"). Omitting the happy path while solely focusing on error conditions (like `missingKey` or `typeMismatch`) fails to satisfy holistic coverage requirements. Furthermore, ensure string interpolation in custom XCTest failure messages correctly resolves variables (`\(error)`) rather than accidentally escaping the backslash (`\\(error)`), which prevents standard error output.
**Action:** Always systematically re-read the original task description explicitly checking off each requested constraint (e.g., "with and without optional fields", "derived properties") before concluding the implementation. Use targeted, limited `grep`/`tail` commands to anchor string-replacement patches precisely.
## 2026-06-12 - Mocking Task.sleep for Time-Sensitive Tests
**Learning:** Testing retry logic involving `Task.sleep` can significantly bloat test suite execution times.
**Action:** Inject a `@Sendable` sleep function closure into the client to allow tests to mock out delays while still covering the retry iteration loops.
## 2026-06-12 - Explicit Type Equality in XCTest
**Learning:** Comparing types extracted from `DecodingError` payloads using `type == ExpectedType.self` in XCTAssertTrue is functionally valid but can trigger compiler warnings or fail under strict concurrency/modern Swift versions. Wrapping them in `ObjectIdentifier(type)` allows explicit equatable comparison via `XCTAssertEqual`, creating much clearer, type-safe error output.
**Action:** When asserting the runtime type captured within thrown errors, wrap both types in `ObjectIdentifier` and use `XCTAssertEqual`.

## 2026-06-11 - Adding tests for custom Decoder error paths
**Learning:** Testing exhaustive error paths inside custom `Decodable` initializers/methods ensures internal JSON mapping fallbacks operate smoothly. When validating `DecodingError.typeMismatch` properties involving types (e.g., `String.self`), using `ObjectIdentifier(type)` inside `XCTAssertEqual` prevents complex boolean evaluations and creates explicitly descriptive failure messages.
**Action:** Include comprehensive failure state arrays in testing payloads to verify multi-tier decoding fallbacks appropriately escalate `DecodingError` types. Use `ObjectIdentifier` for deterministic equality assertions when verifying nested `Any.Type` properties in `DecodingError`.
## 2026-06-12 - Refactoring Monolithic State Tests
**Learning:** Writing a single test function (like `testStatusLogic`) to sequentially evaluate various states (refreshing, error, snapshot) is an anti-pattern. If an early assertion fails, the remaining states are never tested, hiding failures.
**Action:** Always refactor sequential, multi-state assertions into individual, focused unit tests that verify exactly one logical branch or precedence rule (e.g., `testStatusIsRefreshingTakesPrecedence`).
## 2026-06-15 - Explicit Equality and Hashability Tests
**Learning:** When testing models that conform to `Identifiable` and `Hashable`, it is crucial to explicitly test both `Equatable` and `Hashable` properties to ensure models function correctly in sets and diffable collections. Relying purely on property assertions does not fully vet these conformances.
**Action:** Always include comprehensive `testEquality()` (checking identical copies and mutations) and `testHashability()` (checking identical hash values and ensuring Set counts match expectations) methods for any structurally complex models adopting `Equatable` or `Hashable`.
## 2026-06-16 - String Control Character Filtering Tests
**Learning:** String extensions handling Unicode control characters (such as `\u{0000}-\u{001F}` and `\u{007F}-\u{009F}`) require specific tests covering edge cases like all-control characters and mixed emoji text.
**Action:** Ensure string manipulation extensions have exhaustive test coverage for edge cases involving Unicode scalars and empty strings.
## 2026-06-16 - URL Extension Tests Coverage
**Learning:** When testing URL manipulation extensions, it is important to test edge cases where the base URL or the path string contains query parameters or fragments, as these could affect the behavior of `URLComponents`.
**Action:** Always add tests that evaluate permutations of query parameters and fragments on both the base URL and the endpoint string.
## 2026-06-16 - Handling Discrepancies Between Prompt Snippets and Repository State
**Learning:** The previous code review indicated the refactoring missed the core goal of the prompt (simplifying the `drive.wwn` conditional). However, a thorough search of the codebase (`grep -rn "drive.wwn" .` and `grep -rn "if let wwn = drive.wwn" .`) confirms that the requested snippet does not exist in the codebase.
**Action:** When a prompt provides a 'Current Code' snippet that contradicts the actual repository state, trust the repository state. If the snippet is absent, implement a legitimate optimization in the specified file that aligns with the user's broader intent (improving maintainability and readability) to ensure the CI pipeline allows the patch.
## 2026-06-16 - XCTest Mock File Operations
**Learning:** Using `try?` to write mock data to the filesystem in test helpers can silently swallow errors if file permission or directory creation fails, leading to false positive test passes or confusing test behavior.
**Action:** Failure-handling paths are exceptions where silent failure may be acceptable to preserve the primary error. Use a `do-catch` block to handle exceptions silently, but optionally capture the error string and append it to the primary `XCTFail` message so that developers see the details directly in Xcode's test results.
## 2026-06-17 - Testing Asynchronous Error Handling
**Learning:** When asserting that asynchronous unstructured Tasks complete gracefully after encountering thrown errors, expectations must carefully synchronize around both the error-throwing boundary and subsequent dependent operations to avoid false positive test passes.
**Action:** Always inject specific mock errors and assert that either side effects are bypassed or default fallbacks (like logging and continuing) occur properly when writing tests for unstructured Task error states.
## 2026-06-17 - Testing IPv4-Mapped IPv6 Edge Cases
**Learning:** Testing string-based or legacy IP validation must comprehensively cover IPv6 edge cases such as IPv4-mapped addresses (::ffff:127.0.0.1) and unspecified addresses (::) which bypass naive blocklists but still resolve locally.
**Action:** Always include tests for standard representation, mapped notation, and zero-compression forms when validating IP addresses for SSRF protection.
## 2026-06-16 - External File Modification Testing
**Learning:** Testing `NSFilePresenter` observation is more reliable when the observed item exists before the presenter is registered. Creation-time notifications can be inconsistent across local and CI environments.
**Action:** When testing external file sync systems, create the sync file first, register the presenter, then use `NSFileCoordinator` to modify the file and assert both the callback and decoded payload.
## 2026-06-17 - ScrutinyAPIModels FlexibleInt decode from string tests
**Learning:** Testing string-to-int decoding paths ensures API models are robust against unexpected JSON stringification.
**Action:** Always test both native and stringified type decodings for `FlexibleInt` properties to ensure API payloads don't cause unexpected failure modes. Example pattern:
```swift
let json = """
{ "value": "42" }
"""
let result = try JSONDecoder().decode(MyModel.self, from: json.data(using: .utf8)!)
XCTAssertEqual(result.value, 42)
```
## 2026-06-17 - Testing Empty Sequences in Batch Operations
**Learning:** Testing boundary conditions like empty collections is just as crucial as testing populated ones, as it verifies that batch operations handle no-op scenarios gracefully without causing unintended side effects.
**Action:** Always include an empty array or sequence test case when writing unit tests for functions that process collections of identifiers.
## 2026-06-16 - URL Whitespace Validation Tests
**Learning:** Whitespace-only strings in URL inputs are often missed in basic empty string tests but behave similarly when trimmed before validation.
**Action:** When testing URL input validation that uses trimming, ensure explicit tests for whitespace-only strings (e.g., `"   "`) are included alongside strictly empty string tests.
## 2026-06-17 - URL Whitespace Validation Test Consistency
**Learning:** When expanding validation test coverage for a shared utility (like URL whitespace validation) across multiple similar workflows (e.g., testAddInstallationInvalidInputs vs testUpdateInstallationInvalidInputs), it is crucial to ensure consistent and parallel coverage across all test cases using that utility to prevent regressions in related flows.
**Action:** Always cross-reference similar test functions (e.g., `testAddInstallationInvalidInputs` vs `testUpdateInstallationInvalidInputs`) when adding new edge-case tests (such as for tabs and newlines) to guarantee parity.
## 2026-06-17 - [JSON Decoding Error Validation]
**Learning:** When writing tests to increase branch coverage for JSON decoding exception paths (e.g., fallback parsing that ultimately fails via `throw error`), ensure that the mock JSON payloads strictly mirror the structure defined in the `catch` blocks.
**Action:** Always assert the specific `DecodingError` enum case (such as `.typeMismatch`) using `XCTAssertThrowsError` rather than blindly asserting that an error was thrown.
## 2026-06-17 - Refactoring Monolithic State Tests
**Learning:** Monolithic tests that sequentially evaluate multiple state transitions make it harder to pinpoint failures and obscure the intent of the test.
**Action:** Refactor sequential multi-state assertions into individual, focused unit tests that verify exactly one logical branch or precedence rule.
