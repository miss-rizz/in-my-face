import Cocoa
import EventKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private let store = EKEventStore()
    private var dismissed = Set<String>()
    private var scheduled = Set<String>()
    private var alertWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var sound: NSSound?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusBar()

        dismissed = Set(UserDefaults.standard.stringArray(forKey: "dismissed") ?? [])
        requestCalendarAccess()
    }

    // MARK: - Status Bar

    private var nextMeetingItem = NSMenuItem(title: "Loading...", action: #selector(noOp), keyEquivalent: "")

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(
            systemSymbolName: "calendar.badge.clock",
            accessibilityDescription: "In My Face"
        )

        nextMeetingItem.target = self

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(NSMenuItem(title: "In My Face – Active", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(nextMeetingItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshNextMeeting()
    }

    @objc private func noOp() {}

    private func refreshNextMeeting() {
        let now = Date()
        guard let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now) else { return }

        let predicate = store.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)
        let upcoming = store.events(matching: predicate)
            .filter { !$0.isAllDay && ($0.startDate ?? now) > now }
            .sorted { ($0.startDate ?? now) < ($1.startDate ?? now) }

        let label: String
        if let next = upcoming.first, let start = next.startDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            label = "Next: \(next.title ?? "Meeting") at \(formatter.string(from: start))"
        } else {
            label = "No more meetings today"
        }

        let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.labelColor]
        nextMeetingItem.attributedTitle = NSAttributedString(string: label, attributes: attrs)
    }

    // MARK: - Calendar Access

    private func requestCalendarAccess() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, _ in
                guard granted else { return }
                DispatchQueue.main.async { self?.startScheduling() }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, _ in
                guard granted else { return }
                DispatchQueue.main.async { self?.startScheduling() }
            }
        }
    }

    // MARK: - Scheduling

    private func startScheduling() {
        scheduleTodaysEvents()

        // Re-scan every 30 minutes to catch newly added events
        Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            self?.scheduleTodaysEvents()
        }

        // React immediately when calendar syncs new data
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleTodaysEvents()
        }
    }

    private func scheduleTodaysEvents() {
        let now = Date()
        guard let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now) else { return }

        let predicate = store.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)

        for event in store.events(matching: predicate) {
            guard let id = event.eventIdentifier,
                  let startDate = event.startDate,
                  !event.isAllDay,
                  !dismissed.contains(id),
                  !scheduled.contains(id) else { continue }

            // Skip events that started more than 60 seconds ago
            let delay = startDate.timeIntervalSinceNow
            guard delay > -60 else { continue }

            scheduled.insert(id)

            DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay)) { [weak self] in
                guard let self, !self.dismissed.contains(id) else { return }
                let url = self.extractMeetingURL(from: event)
                self.showAlert(title: event.title ?? "Meeting", url: url, eventID: id)
            }
        }
    }

    // MARK: - URL Extraction

    private func extractMeetingURL(from event: EKEvent) -> URL? {
        let meetingHosts = ["meet.google.com", "zoom.us", "teams.microsoft.com", "zoom.app.link"]

        if let url = event.url, meetingHosts.contains(where: { url.absoluteString.contains($0) }) {
            return url
        }

        let textFields = [event.notes, event.location].compactMap { $0 }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }

        for text in textFields {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector.matches(in: text, range: range) {
                if let url = match.url, meetingHosts.contains(where: { url.absoluteString.contains($0) }) {
                    return url
                }
            }
        }

        return nil
    }

    // MARK: - Alert Window

    private func showAlert(title: String, url: URL?, eventID: String) {
        guard alertWindow == nil else { return }

        let screen = NSScreen.main ?? NSScreen.screens[0]

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.isOpaque = true
        window.backgroundColor = .black
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false

        let alertView = AlertView(title: title, url: url) { [weak self] joinURL in
            if let u = joinURL { NSWorkspace.shared.open(u) }
            self?.dismissAlert(eventID: eventID)
        }
        window.contentView = NSHostingView(rootView: alertView)
        window.orderFrontRegardless()

        alertWindow = window
        playFlute()
    }

    private func playFlute() {
        guard let url = Bundle.main.url(forResource: "flute", withExtension: "wav") else { return }
        sound = NSSound(contentsOf: url, byReference: false)
        sound?.loops = true
        sound?.play()
    }

    private func dismissAlert(eventID: String) {
        sound?.stop()
        sound = nil
        dismissed.insert(eventID)
        UserDefaults.standard.set(Array(dismissed), forKey: "dismissed")
        alertWindow?.close()
        alertWindow = nil
    }
}
