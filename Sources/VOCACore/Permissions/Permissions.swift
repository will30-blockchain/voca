import Foundation
import AVFoundation
import ApplicationServices
import AppKit

public enum Permissions {
    public enum MicStatus: Sendable {
        case granted, denied, undetermined, restricted
    }

    public static func microphoneStatus() -> MicStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .undetermined
        @unknown default: return .undetermined
        }
    }

    public static func requestMicrophone() async -> Bool {
        let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                cont.resume(returning: granted)
            }
        }
        AppLog.app.info("Microphone request returned granted=\(granted, privacy: .public)")
        return granted
    }

    /// Actually opens a tiny capture session so macOS *registers* VOCA in
    /// the Microphone privacy list, even if the user dismisses the prompt.
    /// `requestAccess` alone sometimes doesn't surface the app in System
    /// Settings on ad-hoc signed builds.
    public static func forceMicrophoneRegistration() async -> MicStatus {
        _ = await requestMicrophone()
        let session = AVCaptureSession()
        if let device = AVCaptureDevice.default(for: .audio),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
            session.startRunning()
            try? await Task.sleep(nanoseconds: 200_000_000)
            session.stopRunning()
            session.removeInput(input)
        }
        return microphoneStatus()
    }

    public static var accessibilityTrusted: Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    @discardableResult
    public static func requestAccessibility(prompt: Bool = true) -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    public static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public static func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
