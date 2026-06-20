import XCTest
import SwiftUI
import ViewInspector
@testable import ScrutinyMonitor



final class AddInstallationViewTests: XCTestCase {
    var userDefaults: UserDefaults!
    var store: MonitorStore!
    let suiteName = "com.scrutinymonitor.tests.addinstallationview"

    @MainActor
    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)

        let persistence = InstallationPersistence(userDefaults: userDefaults, migratesLegacyDefaults: false)
        let cloudSync = CloudSettingsSynchronizer(defaults: userDefaults)
        let notificationService = DriveFailureNotificationService(defaults: userDefaults)

        store = MonitorStore(
            client: .shared,
            persistence: persistence,
            cloudSync: cloudSync,
            notificationService: notificationService
        )
    }

    @MainActor
    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        store = nil
        userDefaults = nil
        super.tearDown()
    }

    @MainActor
    func testAddModeLayout() throws {
        let view = AddInstallationView(store: store)
        
        // Assert correct title for Add mode
        let titleText = try view.inspect().find(text: "Add Scrutiny Installation")
        XCTAssertNotNil(titleText)

        // Assert text fields exist for Name and URL
        let textFields = try view.inspect().findAll(ViewType.TextField.self)
        XCTAssertEqual(textFields.count, 2, "Should have text fields for Name and URL")
        
        let secureField = try view.inspect().find(ViewType.SecureField.self)
        XCTAssertNotNil(secureField, "Should have a secure field for the API token")

        // Assert button presence
        let cancelButton = try view.inspect().find(button: "Cancel")
        XCTAssertNotNil(cancelButton)

        let addButton = try view.inspect().find(button: "Add")
        XCTAssertTrue(addButton.isDisabled(), "Add button should start disabled when required fields are empty")
    }

    @MainActor
    func testEditModeLayout() throws {
        let editingInstallation = ScrutinyInstallation(
            id: UUID(),
            name: "Home Server",
            baseURL: URL(string: "https://home.local")!,
            apiToken: "secret".data(using: .utf8)!
        )
        
        let view = AddInstallationView(store: store, editingInstallation: editingInstallation)
        
        // Assert correct title for edit mode
        let titleText = try view.inspect().find(text: "Edit Scrutiny Installation")
        XCTAssertNotNil(titleText)

        // Assert buttons
        let saveButton = try view.inspect().find(button: "Save")
        XCTAssertFalse(saveButton.isDisabled(), "Save button should be enabled by default when editing a valid installation")
        
        let cancelButton = try view.inspect().find(button: "Cancel")
        XCTAssertNotNil(cancelButton)
    }

    @MainActor
    func testAddInstallationErrorDisplay() throws {
        var view = AddInstallationView(store: store)

        let exp = view.on(\.didAppear) { v in
            let textFields = v.findAll(ViewType.TextField.self)
            try textFields[0].setInput("Test") // name
            try textFields[1].setInput("ftp://invalid") // url

            let addButton = try v.find(button: "Add")
            try addButton.tap()

            let errorPanel = try v.find(ErrorPanel.self)
            let text = try errorPanel.find(ViewType.Label.self).find(ViewType.Text.self).string()
            XCTAssertEqual(text, "Scrutiny servers must use HTTP or HTTPS.")
        }

        ViewHosting.host(view: view)
        wait(for: [exp], timeout: 1.0)
    }
}
