#!/usr/bin/env swift

import ApplicationServices
import AppKit
import CoreGraphics
import Foundation

struct AXFailure: Error, CustomStringConvertible {
    let description: String
}

func attribute(_ element: AXUIElement, _ name: CFString) -> AnyObject? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name, &value) == .success else { return nil }
    return value as AnyObject?
}

func children(of element: AXUIElement) -> [AXUIElement] {
    (attribute(element, kAXChildrenAttribute as CFString) as? [AXUIElement]) ?? []
}

func identifier(of element: AXUIElement) -> String? {
    attribute(element, kAXIdentifierAttribute as CFString) as? String
}

func find(_ element: AXUIElement, identifier target: String) -> AXUIElement? {
    if identifier(of: element) == target { return element }
    for child in children(of: element) {
        if let match = find(child, identifier: target) { return match }
    }
    return nil
}

func pressableDescendant(of element: AXUIElement) -> AXUIElement? {
    let role = attribute(element, kAXRoleAttribute as CFString) as? String
    if role == kAXButtonRole || role == "AXLink" { return element }
    for child in children(of: element) {
        if let match = pressableDescendant(of: child) { return match }
    }
    return nil
}

func application(named name: String) throws -> AXUIElement {
    let workspace = NSWorkspace.shared
    let candidates = workspace.runningApplications + NSRunningApplication.runningApplications(withBundleIdentifier: "dev.qsb.QSBMacApp")
    guard let process = candidates.first(where: {
        $0.localizedName == name || $0.bundleIdentifier == name || $0.executableURL?.lastPathComponent == name
    }) else {
        throw AXFailure(description: "Running application not found: \(name)")
    }
    return AXUIElementCreateApplication(process.processIdentifier)
}

func press(_ element: AXUIElement, identifier: String) throws {
    guard let control = find(element, identifier: identifier) else {
        throw AXFailure(description: "Accessibility identifier not found: \(identifier)")
    }
    let target = pressableDescendant(of: control) ?? control
    guard AXUIElementPerformAction(target, kAXPressAction as CFString) == .success else {
        throw AXFailure(description: "Could not press accessibility identifier: \(identifier)")
    }
}

func resize(_ element: AXUIElement, width: CGFloat, height: CGFloat) throws {
    guard let window = children(of: element).first(where: { (attribute($0, kAXRoleAttribute as CFString) as? String) == kAXWindowRole }) else {
        throw AXFailure(description: "Application window not found")
    }
    var size = CGSize(width: width, height: height)
    guard AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!) == .success else {
        throw AXFailure(description: "Could not resize application window")
    }
}

func listIdentifiers(_ element: AXUIElement) {
    if let value = identifier(of: element) {
        let role = attribute(element, kAXRoleAttribute as CFString) as? String ?? "?"
        let title = attribute(element, kAXTitleAttribute as CFString) as? String ?? ""
        print("\(value)\t\(role)\t\(title)")
    }
    for child in children(of: element) { listIdentifiers(child) }
}

func read(_ element: AXUIElement, identifier target: String) throws {
    guard let control = find(element, identifier: target) else {
        throw AXFailure(description: "Accessibility identifier not found: \(target)")
    }
    let title = attribute(control, kAXTitleAttribute as CFString) as? String ?? ""
    let value = attribute(control, kAXValueAttribute as CFString) as? String ?? ""
    print(title.isEmpty ? value : title)
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    fputs("usage: axui.swift <process-name> --press <identifier> | --resize <width> <height> | --list-identifiers | --read <identifier>\n", stderr)
    exit(2)
}

do {
    let app = try application(named: arguments[1])
    switch arguments[2] {
    case "--press":
        guard arguments.count == 4 else { throw AXFailure(description: "--press requires an identifier") }
        try press(app, identifier: arguments[3])
    case "--resize":
        guard arguments.count == 5, let width = Double(arguments[3]), let height = Double(arguments[4]) else {
            throw AXFailure(description: "--resize requires width and height")
        }
        try resize(app, width: width, height: height)
    case "--list-identifiers":
        guard arguments.count == 3 else { throw AXFailure(description: "--list-identifiers takes no additional arguments") }
        listIdentifiers(app)
    case "--read":
        guard arguments.count == 4 else { throw AXFailure(description: "--read requires an identifier") }
        try read(app, identifier: arguments[3])
    default:
        throw AXFailure(description: "Unknown action: \(arguments[2])")
    }
} catch {
    fputs("axui: \(error)\n", stderr)
    exit(1)
}
