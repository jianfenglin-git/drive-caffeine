import SwiftUI
import AppKit
import DriveCaffeineKit

struct MenuContentView: View {
    @ObservedObject var controller: KeepAliveController
    @State private var addError: String?      // inline message when a picked drive is rejected

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if controller.volumes.isEmpty {
                emptyState
            } else {
                // Dividers BETWEEN rows only — not a trailing one butting against
                // the footer. enumerate so we can skip the divider after the last.
                ForEach(Array(controller.volumes.enumerated()), id: \.element.id) { idx, volume in
                    VolumeRow(volume: volume, controller: controller)
                    if idx < controller.volumes.count - 1 {
                        Divider().padding(.leading, 38)   // align under the indented column
                    }
                }
            }

            Divider()
            footer
        }
        .padding(.vertical, 8)
        // No modal alert here. Alerts steal focus, which dismisses a menu-bar
        // popover, which re-presents the alert → endless cycle. All toggle
        // feedback is inline per-row instead.
    }

    private var header: some View {
        HStack(spacing: 7) {
            // Same custom cup-on-drive icon as the menu bar, for consistency.
            Image(nsImage: AppIcon.image(size: 18))
                .foregroundStyle(.primary)
            Text("Drive Caffeine").font(.headline)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No drives added yet.")
                .foregroundStyle(.secondary)
            Text("Add an external drive to keep it from spinning down.")
                .font(.caption).foregroundStyle(.secondary)
            // Primary action lives WITH the prompt — the right choice is the
            // most visible choice (Krug). Footer button stays for the populated case.
            Button {
                pickDrive()
            } label: {
                Label("Add Drive…", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 2)

            if let addError {
                Text(addError).font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !controller.volumes.isEmpty, let addError {
                Text(addError).font(.caption).foregroundStyle(.orange)
            }
            HStack {
                // Add Drive lives in the empty state when there are no drives;
                // showing it here too would be a duplicate button. Only show the
                // footer Add when drives already exist.
                if !controller.volumes.isEmpty {
                    Button {
                        pickDrive()
                    } label: {
                        Label("Add Drive…", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)   // match the empty-state CTA (blue)
                }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    private func pickDrive() {
        addError = nil

        // CRITICAL for LSUIElement (menu-bar-only) apps: we are an accessory app
        // and are NOT the active application when the popover is clicked. Without
        // activating first, the NSOpenPanel opens but isn't the key window — it
        // can't receive mouse clicks, so the drive won't select and the OK button
        // stays disabled until macOS eventually activates us (~10s later).
        // Activating makes the panel key immediately so clicks register.
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = "Add Drive"
        panel.message = "Choose an external drive to keep awake, then click Add Drive."
        panel.prompt = "Add Drive"
        // Float above other windows and ensure it comes to the front as key.
        panel.level = .modalPanel
        // Start INSIDE /Volumes so the external drives are the visible items the
        // user picks — not /Volumes itself (which is read-only and not a drive).
        panel.directoryURL = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        // Don't restore the last-used frame, and center on screen each time.
        // Otherwise the panel reopens stuck in the lower-left where it last sat.
        panel.setFrameAutosaveName("")
        panel.makeKeyAndOrderFront(nil)
        panel.center()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        // Reject bad targets (internal disk, /Volumes, /) with a clear inline
        // message instead of adding a drive that fails later with a yellow bang.
        if let reason = controller.addVolume(url: url) {
            addError = reason
        }
    }
}

private struct VolumeRow: View {
    let volume: VolumeState
    @ObservedObject var controller: KeepAliveController

    // Inline, per-row error (e.g. "Write needs a writable drive"). Shown as a
    // line of text in THIS row — never a modal alert, which would steal focus
    // and collapse the menu-bar popover.
    @State private var inlineError: String?
    @State private var removeHovering = false   // red-tint the remove button on hover

    // Local state ONLY for smooth slider dragging; committed on release.
    // The toggles are NOT mirrored in @State — they read and write the model
    // directly (single source of truth). A mirrored copy drifted from reality:
    // the checkbox showed Read=on while the model had it off, so nothing poked
    // the drive and it slept. It also needed two clicks because the mirror, the
    // binding, and the @Published model fought over one value.
    @State private var draggingInterval: Double?

    var body: some View {
        // Hierarchy: the status icon is a BULLET at the far left; everything
        // about this drive (name, status, controls) hangs in an indented column
        // to its right. This groups the row visually instead of three things all
        // starting at the left edge with a ragged feel.
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            // firstTextBaseline aligns the status icon with the NAME line's
            // baseline (not the top of the whole column), so the checkmark sits
            // level with the volume label instead of floating above it.
            statusIcon
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 5) {
                // Line 1: drive name (the anchor) + remove button.
                HStack(spacing: 6) {
                    Text(volume.settings.identity.name)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Spacer()
                    Button(role: .destructive) {
                        controller.removeVolume(key: volume.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            // .secondary (not .tertiary) so it's findable; turns
                            // red on hover so the destructive action is obvious
                            // when reached for, without shouting at rest.
                            .foregroundStyle(removeHovering ? Color.red : Color.secondary)
                            .font(.system(size: 14))
                            .frame(width: 24, height: 24)   // hit target (HIG)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .onHover { removeHovering = $0 }
                    .help("Remove")
                    .accessibilityLabel("Remove \(volume.settings.identity.name)")
                }

                // Line 2: status. When access has gone stale, offer a one-click
                // Re-grant instead of making the user remove and re-add (which
                // would lose nothing but feels like redoing setup).
                if case .needsRegrant = volume.status {
                    HStack(spacing: 6) {
                        Text("Access expired")
                            .font(.caption).foregroundStyle(.orange)
                        Button("Re-grant…") { regrant() }
                            .controlSize(.small)
                    }
                } else {
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Line 3: controls — Read · Write · "Every Ns" all at the same
                // 12pt rhythm, then the slider fills the remaining width.
                HStack(spacing: 12) {
                    Toggle("Read", isOn: Binding(
                        get: { volume.settings.modes.contains(.read) },
                        set: { setMode(.read, $0) }
                    ))
                    Toggle("Write", isOn: Binding(
                        get: { volume.settings.modes.contains(.write) },
                        set: { setMode(.write, $0) }
                    ))

                    // Same font as the toggle labels. Hug the text (fixedSize,
                    // no padded frame) so the gap to the slider equals the 12pt
                    // HStack rhythm — same as Read→Write. Tabular digits keep the
                    // width steady as the number changes (30s ↔ 120s).
                    Text("Every \(Int((displayedInterval / 5).rounded() * 5))s")
                        .monospacedDigit()
                        .fixedSize()

                    // Plain continuous slider — no `step`, so macOS draws NO tick
                    // marks: a clean blue filled track to the left of the white
                    // system thumb. We round to 5s on commit instead of stepping,
                    // keeping the elegant look while still storing sane values.
                    Slider(
                        value: Binding(
                            get: { displayedInterval },
                            set: { draggingInterval = $0 }     // local while dragging
                        ),
                        in: KeepAliveDefaults.minInterval...KeepAliveDefaults.maxInterval,
                        onEditingChanged: { editing in
                            if !editing, let v = draggingInterval {
                                let rounded = (v / 5).rounded() * 5   // snap to 5s on release
                                controller.setInterval(rounded, forKey: volume.id)
                                draggingInterval = nil
                            }
                        }
                    )
                    .controlSize(.small)
                    .tint(.accentColor)           // blue filled track (thumb is the system knob)
                    .frame(maxWidth: .infinity)   // slider takes all remaining width
                }
                .toggleStyle(.checkbox)

                if let inlineError {
                    Text(inlineError)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // Show the in-progress drag value if dragging, else the committed model value.
    private var displayedInterval: Double {
        draggingInterval ?? volume.settings.intervalSeconds
    }

    private func setMode(_ mode: KeepAliveMode, _ enabled: Bool) {
        // Controller is the single writer. On failure (e.g. Write on a read-only
        // drive) it returns a reason and leaves the model unchanged; the toggle
        // re-renders from the model and reverts itself. We show the reason
        // INLINE in this row — no modal. Disabling both modes is NOT a failure;
        // it returns nil and the status becomes "Disabled".
        if let reason = controller.setMode(mode, enabled: enabled, forKey: volume.id) {
            inlineError = reason
        } else {
            inlineError = nil
        }
    }

    // Re-grant access to this specific drive after its bookmark went stale.
    // Reopens the picker; addVolume restores the existing read/write/interval.
    private func regrant() {
        inlineError = nil
        NSApp.activate(ignoringOtherApps: true)   // LSUIElement must activate for the panel to take focus
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = "Re-grant Access"
        panel.message = "Re-select \(volume.settings.identity.name) to restore keep-alive."
        panel.prompt = "Re-grant"
        panel.directoryURL = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        panel.setFrameAutosaveName("")
        panel.makeKeyAndOrderFront(nil)
        panel.center()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let reason = controller.regrant(key: volume.id, pickedURL: url) {
            inlineError = reason
        }
    }

    // Status is encoded redundantly: SHAPE (SF Symbol) + COLOR + a VoiceOver
    // label. Never color alone — ~8% of men can't distinguish red/green, and a
    // screen-reader user gets the label. This is the app's core signal, so it
    // must survive without color.
    private var statusIcon: some View {
        Image(systemName: statusSymbol)
            .foregroundStyle(statusColor)
            .font(.system(size: 11))
            .accessibilityLabel("Status: \(statusText)")
    }

    private var statusSymbol: String {
        switch volume.status {
        case .active:       return "checkmark.circle.fill"
        case .checking:     return "circle.dotted"
        case .disabled:     return "pause.circle"
        case .failed:       return "exclamationmark.triangle.fill"
        case .needsRegrant: return "lock.circle.fill"
        case .unmounted:    return "circle.dotted"
        case .idle:         return "circle"
        }
    }

    private var statusColor: Color {
        switch volume.status {
        case .active: return .green
        case .failed, .needsRegrant: return .orange
        case .checking, .disabled, .unmounted, .idle: return .secondary
        }
    }

    private var statusText: String {
        switch volume.status {
        case .idle: return "Idle"
        case .checking: return "Checking…"
        case .active(let m):
            var parts: [String] = []
            if m.contains(.read) { parts.append("read") }
            if m.contains(.write) { parts.append("write") }
            return "Active — keeping awake via \(parts.joined(separator: " + "))"
        case .disabled: return "Disabled — this drive may sleep"
        case .failed(let why): return "Failed — \(why)"
        case .needsRegrant: return "Access expired — remove and re-add to re-grant"
        case .unmounted: return "Not connected"
        }
    }
}
