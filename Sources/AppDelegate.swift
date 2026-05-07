import Cocoa
import EventKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private let store = EKEventStore()
    // Key is "eventID|startDateTimestamp" so a rescheduled meeting is never blocked
    private var dismissed = Set<String>()
    private var scheduled = [String: DispatchWorkItem]()
    private var alertWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var sound: NSSound?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusBar()

        dismissed = Set(UserDefaults.standard.stringArray(forKey: "dismissed") ?? [])
        requestCalendarAccess()
    }

    // Composite key — dismissed at a specific time, not forever
    private func dismissedKey(_ id: String, _ date: Date) -> String {
        "\(id)|\(Int(date.timeIntervalSince1970))"
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

        // Rescan every 60 seconds as a safety net for any missed events
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.scheduleTodaysEvents()
        }

        // React when calendar syncs — delay 1s to let the store finish updating
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self?.scheduleTodaysEvents()
            }
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
                  !dismissed.contains(dismissedKey(id, startDate)) else { continue }

            let delay = startDate.timeIntervalSinceNow
            guard delay > -60 else { continue }

            // Cancel existing timer — handles reschedules cleanly
            scheduled[id]?.cancel()

            let work = DispatchWorkItem { [weak self] in
                guard let self,
                      let fresh = self.store.event(withIdentifier: id),
                      let freshStart = fresh.startDate,
                      !self.dismissed.contains(self.dismissedKey(id, freshStart)) else { return }

                let title = fresh.title ?? "Meeting"
                let url = self.extractMeetingURL(from: fresh)
                self.showAlert(title: title, url: url, eventID: id, startDate: freshStart)
                self.scheduled.removeValue(forKey: id)
            }

            scheduled[id] = work
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay), execute: work)
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

    private func showAlert(title: String, url: URL?, eventID: String, startDate: Date) {
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
            self?.dismissAlert(eventID: eventID, startDate: startDate)
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

    private func dismissAlert(eventID: String, startDate: Date) {
        sound?.stop()
        sound = nil
        let key = dismissedKey(eventID, startDate)
        dismissed.insert(key)
        UserDefaults.standard.set(Array(dismissed), forKey: "dismissed")
        scheduled.removeValue(forKey: eventID)
        alertWindow?.close()
        alertWindow = nil
    }
}
