// ios/Runner/AppDelegate.swift

import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {

  // MARK: - Properties for Screen Protection
  var screenProtectionView: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // --- Your existing UNUserNotificationCenterDelegate setup ---
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    // --- End of your existing code ---

    // Add the notification observers to handle screen protection
    setupScreenProtectionObservers()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Screen Protection Logic (Replaces all old channel code)
  
  private func setupScreenProtectionObservers() {
    // App is moving to background (app switcher)
    NotificationCenter.default.addObserver(self, selector: #selector(showProtection), name: UIApplication.willResignActiveNotification, object: nil)
    
    // App is coming back to foreground
    NotificationCenter.default.addObserver(self, selector: #selector(hideProtection), name: UIApplication.didBecomeActiveNotification, object: nil)
    
    // User takes a screenshot
    NotificationCenter.default.addObserver(self, selector: #selector(showProtection), name: UIApplication.userDidTakeScreenshotNotification, object: nil)
    
    // Check for screen recording status changes
    if #available(iOS 11.0, *) {
      NotificationCenter.default.addObserver(self, selector: #selector(handleScreenCaptureChange), name: UIScreen.capturedDidChangeNotification, object: nil)
    }
  }
  
  // This function is called when screen recording starts or stops
  @objc private func handleScreenCaptureChange() {
      if UIScreen.main.isCaptured {
          showProtection()
      } else {
          // Important: Only hide if the app is active. Don't hide if it's in the background.
          if UIApplication.shared.applicationState == .active {
              hideProtection()
          }
      }
  }

  // This function displays the black overlay
  @objc private func showProtection() {
    guard let window = window, screenProtectionView == nil else { return }

    screenProtectionView = UIView(frame: window.bounds)
    screenProtectionView?.backgroundColor = .black

    let label = UILabel()
    label.text = "Content is Secured"
    label.textColor = .white
    label.textAlignment = .center
    
    screenProtectionView!.addSubview(label)
    label.frame = window.bounds

    window.addSubview(screenProtectionView!)
  }

  // This function removes the black overlay
  @objc private func hideProtection() {
    screenProtectionView?.removeFromSuperview()
    screenProtectionView = nil
  }
}