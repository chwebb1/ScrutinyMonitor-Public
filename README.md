# Scrutiny Monitor

Scrutiny Monitor is a macOS native client designed to monitor Scrutiny (disk health) servers. It provides a clean, native interface for tracking the health and status of your drives across multiple Scrutiny installations.

## Features

*   **Multiple Server Support:** Monitor multiple Scrutiny installations from a single unified interface.
*   **Auto-Refresh:** Configurable automatic refreshing to keep your drive status up-to-date.
*   **Notifications:** Receive system notifications for drive failure alerts and critical warnings.
*   **Native macOS Experience:** Built using SwiftUI for a seamless, native feel on macOS.

## Architecture

The project is structured into the following main components:

*   **App:** Contains the main application entry point and lifecycle management (`ScrutinyMonitorApp.swift`).
*   **Models:** Defines the core data structures used throughout the app, such as `ScrutinyInstallation`, `DriveDetail`, and `InstallationSnapshot`.
*   **Stores:** Manages the application state and data persistence, primarily through `MonitorStore`.
*   **Views:** Contains all the SwiftUI views that make up the user interface.
*   **Services:** Handles external communication and background tasks, such as API interactions and notification services.
*   **Support:** Includes helper utilities, extensions, and app preferences.

## Requirements

*   macOS 14.0 or later

## Building and Running

This project uses the Swift Package Manager. You can build and run it from the command line:

1.  Clone the repository.
2.  Navigate to the project directory in your terminal.
3.  Build the project:
    ```bash
    swift build
    ```
4.  Run the application:
    ```bash
    swift run ScrutinyMonitor
    ```

Alternatively, you can open the `Package.swift` file in Xcode to build and run the project using the IDE.
