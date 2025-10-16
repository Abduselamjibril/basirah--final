import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {

  // A view to cover the screen when recording is detected
  var screenProtectionView: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    
    // Set up screen recording protection
    setupScreenRecordingProtection()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setupScreenRecordingProtection() {
    // Listen for screen recording status changes
    NotificationCenter.default.addObserver(self, selector: #selector(handleScreenRecordingStateChanged), name: UIScreen.capturedDidChangeNotification, object: nil)
    
    // Also listen for screenshot notifications
    NotificationCenter.default.addObserver(self, selector: #selector(handleScreenshotTaken), name: UIApplication.userDidTakeScreenshotNotification, object: nil)

    // Initial check
    handleScreenRecordingStateChanged()
  }

  @objc private func handleScreenRecordingStateChanged() {
    DispatchQueue.main.async {
      let isRecording = UIScreen.main.isCaptured
      if isRecording {
        self.showProtectionView()
      } else {
        self.hideProtectionView()
      }
    }
  }
    
  @objc private func handleScreenshotTaken() {
    // When a screenshot is taken, we flash the protection view briefly
    // This obscures the content in the screenshot itself
    showProtectionView()
    // Hide it after a very short delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        self.handleScreenRecordingStateChanged() // Re-check recording state
    }
  }

  private func showProtectionView() {
    guard self.screenProtectionView == nil, let window = self.window else { return }

    let protectionView = UIView(frame: window.bounds)
    protectionView.backgroundColor = .black

    let label = UILabel()
    label.text = "Screen recording and screenshots are not permitted."
    label.textColor = .white
    label.textAlignment = .center
    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false
    
    protectionView.addSubview(label)
    
    NSLayoutConstraint.activate([
        label.centerXAnchor.constraint(equalTo: protectionView.centerXAnchor),
        label.centerYAnchor.constraint(equalTo: protectionView.centerYAnchor),
        label.leadingAnchor.constraint(equalTo: protectionView.leadingAnchor, constant: 20),
        label.trailingAnchor.constraint(equalTo: protectionView.trailingAnchor, constant: -20)
    ])

    window.addSubview(protectionView)
    self.screenProtectionView = protectionView
  }

  private func hideProtectionView() {
    self.screenProtectionView?.removeFromSuperview()
    self.screenProtectionView = nil
  }
}