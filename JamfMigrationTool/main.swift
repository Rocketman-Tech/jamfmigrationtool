//
//  main.swift
//  JamfMigrationTool
//
//  Created by Bruno Cerciliar on 09/05/25.
//

import Foundation

// Constants
let abeProfileIdentifier = "com.apple.profile.mdm"
let logoPath = "/Library/Application Support/Rocketman/funcfi-logo-small.png"

// Check if ABE profile exists
func checkProfileExists(identifier: String) -> Bool {
    let process = Process()
    let pipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/usr/bin/profiles")
    process.arguments = ["list"]
    process.standardOutput = pipe

    do {
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            return output.contains(identifier)
        }
    } catch {
        print("Error checking profiles: \(error)")
    }

    return false
}

// Try to remove ABE profile
func removeProfile(identifier: String) -> Bool {
    let process = Process()

    process.executableURL = URL(fileURLWithPath: "/usr/bin/profiles")
    process.arguments = ["remove", "-identifier", identifier]

    do {
        try process.run()
        process.waitUntilExit()

        // Wait a moment for the system to update
        sleep(2)

        // Check if profile was successfully removed
        return !checkProfileExists(identifier: identifier)
    } catch {
        print("Error removing profile: \(error)")
        return false
    }
}

// Show dialog to user
func showDialog(title: String, message: String, buttonText: String, iconPath: String) -> Bool {
    let process = Process()
    let dialogPath = "/usr/local/bin/dialog"

    // Check if dialog exists
    if !FileManager.default.fileExists(atPath: dialogPath) {
        print("SwiftDialog not found at \(dialogPath)")
        return false
    }

    process.executableURL = URL(fileURLWithPath: dialogPath)
    process.arguments = [
        "--title", title,
        "--message", message,
        "--icon", iconPath,
        "--button1text", buttonText,
    ]

    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    } catch {
        print("Error showing dialog: \(error)")
        return false
    }
}

// Start Jamf enrollment
func startJamfEnrollment() {
    let process = Process()

    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = [
        "https://funcfi.jamfcloud.com/enroll/?invitation=34575975136649195478078314224683433652"
    ]

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        print("Error starting Jamf enrollment: \(error)")
    }
}

// Check if running with admin privileges
func isRunningAsAdmin() -> Bool {
    let process = Process()
    let pipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/usr/bin/id")
    process.arguments = ["-u"]
    process.standardOutput = pipe

    do {
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(
            in: .whitespacesAndNewlines),
            let uid = Int(output)
        {
            return uid == 0
        }
    } catch {
        print("Error checking privileges: \(error)")
    }

    return false
}

// Main function
func main() {
    print("Starting migration from Apple Business Essentials to Jamf Pro...")

    // Check for admin privileges
    guard isRunningAsAdmin() else {
        print("Error: This tool must be run with administrator privileges")
        exit(1)
    }

    // Try to remove ABE profile
    let removed = removeProfile(identifier: abeProfileIdentifier)

    if removed {
        print("ABE profile successfully removed.")

        // Show dialog to user
        let dialogShown = showDialog(
            title: "Migrating to Jamf Pro",
            message: "Your Mac needs to be migrated to Jamf Pro. Please press Continue when ready.",
            buttonText: "Continue",
            iconPath: logoPath
        )

        if dialogShown {
            // Start Jamf enrollment
            print("Starting Jamf enrollment...")
            startJamfEnrollment()
        } else {
            print("Failed to show dialog. Please enroll in Jamf Pro manually.")
        }
    } else {
        print(
            "ABE profile could not be removed directly."
        )
    }
}

// Run the main function
main()
