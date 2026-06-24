//
//  BackgroundTaskManager.swift
//  MiniChat
//
//  Wrap UIApplication.beginBackgroundTask - daje ~30s w tle na dokończenie streamingu.
//

import Foundation
import UIKit

@MainActor
final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()

    private var taskId: UIBackgroundTaskIdentifier = .invalid

    private init() {}

    /// Rozpoczyna background task. Idempotentne - kolejne wywołania są no-op.
    /// Po wygaśnięciu (po ~30s) expirationHandler automatycznie kończy task.
    func beginTask(name: String) {
        guard taskId == .invalid else { return }
        taskId = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            // Expiration handler - wywoływany przez iOS tuż przed uśpieniem
            self?.endTask()
        }
    }

    /// Kończy background task. Bezpiecznie wywoływać wielokrotnie.
    func endTask() {
        guard taskId != .invalid else { return }
        UIApplication.shared.endBackgroundTask(taskId)
        taskId = .invalid
    }

    /// Czy background task jest aktywny
    var isActive: Bool {
        taskId != .invalid
    }

    /// Pozostały czas (przybliżony). iOS nie ujawnia dokładnej wartości,
    /// ale UIApplication.shared.backgroundTimeRemaining daje sensowny przybliżenie.
    var remainingTime: TimeInterval {
        UIApplication.shared.backgroundTimeRemaining
    }
}
