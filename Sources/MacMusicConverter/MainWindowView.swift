import SwiftUI
import UniformTypeIdentifiers
import MacMusicConverterKit

struct MainWindowView: View {
    @Bindable var model: AppModel
    @State private var showAdvanced = false
    @State private var dropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $model.mode) {
                ForEach(AppModel.Mode.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding([.horizontal, .top], 20)
            .padding(.bottom, 4)
            .disabled(model.running)

            form
        }
        .frame(minWidth: 540, minHeight: 600)
        .dropDestination(for: URL.self) { urls, _ in
            guard !model.running, model.mode == .local, let url = urls.first else { return false }
            model.setSource(url)
            return true
        } isTargeted: { dropTargeted = $0 }
        .overlay {
            if dropTargeted && model.mode == .local {
                RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: 3).padding(6)
            }
        }
        .alert("The file is already an MP3", isPresented: $model.askReencode) {
            Button("Re-encode") { model.reencodeAnswered(.reencode) }
            Button("WAV Only") { model.reencodeAnswered(.wavOnly) }
            Button("Cancel", role: .cancel) { model.reencodeAnswered(.cancel) }
        } message: {
            Text("Making a new MP3 from it re-encodes it, which loses a little quality; a higher bitrate can't bring it back. Make the MP3 anyway, or just the MacMusic WAV?")
        }
        .alert(conflictTitle, isPresented: $model.askConflicts) {
            Button("Keep Both") { model.conflictsAnswered(.uniqueName) }
                .keyboardShortcut(.defaultAction)
            Button("Replace", role: .destructive) { model.conflictsAnswered(.replace) }
            Button("Cancel", role: .cancel) { model.conflictsAnswered(nil) }
        } message: {
            Text("Keep Both saves the new \(model.conflicts.count == 1 ? "file" : "files") under the next free name. Replace puts \(model.conflicts.count == 1 ? "it" : "them") in place of what's there.")
        }
    }

    var conflictTitle: String {
        let names = model.conflicts.map { "“\($0.name)”" }.joined(separator: " and ")
        return "\(names) already \(model.conflicts.count == 1 ? "exists" : "exist") in “\(model.prefs.folder.lastPathComponent)”"
    }

    // MARK: The form

    var form: some View {
        VStack(spacing: 0) {
            Form {
                if let problem = model.toolsProblem {
                    Section { MessageView(message: problem, symbol: "xmark.octagon.fill", tint: .red) }
                }
                switch model.mode {
                case .local: sourceSection
                case .youtube: youtubeSection
                }
                outputSection
                soundSection
                folderSection
                advancedSection
                if model.result != nil || model.jobMessage != nil { resultsSection }
            }
            .formStyle(.grouped)
            .disabled(model.running)
            Divider()
            actionBar
        }
    }

    var sourceSection: some View {
        Section("Source") {
            HStack {
                if let source = model.source {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.lastPathComponent).font(.headline)
                        Text(source.deletingLastPathComponent().path)
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                } else {
                    Text("Choose a sound file, or drop one on this window.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(model.source == nil ? "Choose File…" : "Choose Another…") { model.chooseSource() }
            }
            if let info = model.sourceInfo {
                Text(describe(info)).font(.callout).foregroundStyle(.secondary)
            } else if let problem = model.sourceProblem {
                MessageView(message: problem, symbol: "exclamationmark.triangle.fill", tint: .orange)
            } else if model.source != nil {
                ProgressView().controlSize(.small)
            }
        }
    }

    /// A YouTube video (Y2-Y4): the address, Look Up, its details.
    var youtubeSection: some View {
        Section("YouTube Video") {
            if let problem = model.youTubeProblem {
                MessageView(message: problem, symbol: "xmark.octagon.fill", tint: .red)
            }
            HStack {
                TextField("Address", text: $model.urlText, prompt: Text("https://www.youtube.com/watch?v=…"))
                    .labelsHidden()
                    .onSubmit { model.lookUp() }
                    .onChange(of: model.urlText) { model.urlChanged() }
                Button("Look Up") { model.lookUp() }
                    .disabled(model.urlText.trimmingCharacters(in: .whitespaces).isEmpty || model.lookingUp
                              || model.youTubeTools == nil)
            }
            if model.lookingUp {
                HStack { ProgressView().controlSize(.small); Text("Looking it up…").foregroundStyle(.secondary) }
            } else if let d = model.details {
                VStack(alignment: .leading, spacing: 2) {
                    Text(d.title).font(.headline)
                    Text([d.channel, d.duration.map { duration($0) }].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else if let problem = model.lookUpProblem {
                MessageView(message: problem, symbol: "exclamationmark.triangle.fill", tint: .orange)
            }
            Label("Only for videos you own or have permission to save.", systemImage: "hand.raised")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    var outputSection: some View {
        Section("Output") {
            Picker("Make", selection: $model.prefs.selection) {
                Text("MacMusic WAV").tag(OutputSelection.wav)
                Text("MP3").tag(OutputSelection.mp3)
                Text("Both").tag(OutputSelection.both)
            }
            .pickerStyle(.segmented)
            if model.sourceIsMP3, model.prefs.selection != .wav {
                Label("This file is already an MP3: a new MP3 re-encodes it, losing a little quality. You'll be asked first.",
                      systemImage: "info.circle")
                    .font(.callout).foregroundStyle(.secondary)
            }
            TextField("Title", text: $model.title, prompt: Text("Shown in MacMusic when you import it"))
            TextField("File name", text: $model.name,
                      prompt: Text(model.title.isEmpty
                                   ? (model.mode == .youtube ? (model.details?.title ?? "From the video's title")
                                      : model.source?.deletingPathExtension().lastPathComponent ?? "From the title or the source")
                                   : model.title))
            if !model.savesAs.isEmpty {
                LabeledContent("Saves as") {
                    VStack(alignment: .trailing, spacing: 2) {
                        ForEach(model.savesAs, id: \.name) { p in
                            HStack(spacing: 4) {
                                Text(p.name)
                                if p.taken {
                                    Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                                        .help(p.isSource ? "This is the source: it will get the next free name."
                                                         : "Already there: you'll be asked.")
                                }
                            }
                        }
                    }
                    .font(.callout)
                }
            }
        }
    }

    var soundSection: some View {
        Section("Sound") {
            Toggle(isOn: $model.prefs.normalise) {
                Text("Normalise")
                Text(String(format: "Raise or lower the loudest peak to %.1f dBFS. Not loudness levelling: songs may still sound different.", model.prefs.target))
            }
            Toggle(isOn: $model.prefs.trimSilence) {
                Text("Trim silence at the ends")
                Text("Silence longer than this at the start or end is cut to half a second. The middle is never touched.")
            }
            Picker("Longer than", selection: $model.prefs.trimThreshold) {
                Text("2 seconds").tag(2.0)
                Text("3 seconds").tag(3.0)
            }
            .disabled(!model.prefs.trimSilence)
        }
    }

    var folderSection: some View {
        Section("Save To") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.prefs.folder.lastPathComponent).font(.headline)
                    Text(model.prefs.folder.deletingLastPathComponent().path)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                if model.prefs.folderPath != nil {
                    Button("Use Default") { model.useDefaultFolder() }
                }
                Button("Choose…") { model.chooseFolder() }
            }
        }
    }

    var advancedSection: some View {
        Section {
            DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                LabeledContent("Normalise to") {
                    Stepper(value: $model.prefs.target, in: -6...0, step: 0.5) {
                        Text(String(format: "%.1f dBFS", model.prefs.target)).monospacedDigit()
                    }
                }
                LabeledContent("MacMusic WAV", value: "22,050 Hz · mono · 8-bit (fixed: what MacMusic plays)")
                LabeledContent("MP3") {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("192 kbps · stereo if the source is")
                        Text("A compressed source (an MP3, or YouTube's audio) made into an MP3 can't be improved by it.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                    }
                }
                LabeledContent("FFmpeg") {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(model.ffmpegVersion.isEmpty ? "—" : model.ffmpegVersion).lineLimit(1)
                        if let tools = model.tools {
                            Text(tools.ffmpeg.deletingLastPathComponent().path)
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                    }
                }
                LabeledContent("yt-dlp", value: model.ytdlpVersion.isEmpty ? "—" : model.ytdlpVersion)
                LabeledContent("Deno", value: model.denoVersion.isEmpty ? "—" : model.denoVersion)
                LabeledContent("Version") {
                    HStack {
                        Text(AppVersion.string)
                        if model.noticesURL != nil {
                            Button("Licences…") { model.showNotices() }
                        }
                    }
                }
            }
        }
    }

    var resultsSection: some View {
        Section("Results") {
            if let message = model.jobMessage {
                MessageView(message: message, symbol: "exclamationmark.triangle.fill", tint: .orange)
            }
            if let r = model.result {
                if let line = summary(r) {
                    Text(line).font(.callout).foregroundStyle(.secondary)
                }
                ForEach(Array(r.outputs.enumerated()), id: \.offset) { _, o in
                    OutputRow(output: o) { model.show($0) }
                }
            }
        }
    }

    var actionBar: some View {
        HStack(spacing: 12) {
            if model.running, let p = model.progress {
                VStack(alignment: .leading, spacing: 4) {
                    Text(describe(p)).font(.callout)
                    if let fraction = p.fraction {
                        ProgressView(value: fraction)
                    } else {
                        ProgressView().progressViewStyle(.linear)
                    }
                }
                Button("Cancel") { model.cancel() }
                    .keyboardShortcut(.cancelAction)
            } else {
                Spacer()
                Button("Convert") { model.convert() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canConvert)
            }
        }
        .padding(16)
    }

    // MARK: Words

    func describe(_ info: AudioInfo) -> String {
        var parts = [info.codec.uppercased(), "\(info.sampleRate.formatted()) Hz",
                     info.channels == 1 ? "mono" : info.channels == 2 ? "stereo" : "\(info.channels) channels"]
        if let d = info.duration { parts.append(duration(d)) }
        return parts.joined(separator: " · ")
    }

    func describe(_ p: JobProgress) -> String {
        let what: String
        switch p.stage {
        case .retrieving: what = "Retrieving the audio from YouTube"
        case .validating: what = "Checking the file"
        case .analysing: what = "Analysing the sound"
        case .converting: what = p.output == .mp3 ? "Making the MP3" : "Making the MacMusic WAV"
        case .validatingOutputs: what = "Checking the results"
        default: what = "Finishing"
        }
        if let f = p.fraction { return "\(what)… \(Int((f * 100).rounded()))%" }
        return "\(what)…"
    }

    func summary(_ r: JobResult) -> String? {
        var parts: [String] = []
        switch r.normalisation {
        case .off: break
        case .skipped(let why): parts.append(why)
        case .gain(let dB, let capped):
            parts.append(String(format: "Normalised by %+.1f dB", dB) + (capped ? " (the most allowed)." : "."))
        }
        if let t = r.trim {
            if let note = t.note { parts.append(note) }
            else if t.trims { parts.append(String(format: "Trimmed %.1f s from the start and %.1f s from the end.", t.cutFromStart, t.cutFromEnd)) }
            else { parts.append("No long silence at the ends to trim.") }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

func duration(_ seconds: Double) -> String {
    let s = Int(seconds.rounded())
    return String(format: "%d:%02d", s / 60, s % 60)
}

/// One output in the results (§4.1): its mark, name, format, size, and
/// Show in Finder; warnings and problems beneath.
struct OutputRow: View {
    let output: OutputResult
    let show: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: symbol).foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(output.url?.lastPathComponent ?? "\(output.kind.rawValue): not saved").font(.headline)
                    Text(details).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let url = output.url {
                    Button("Show in Finder") { show(url) }
                }
            }
            ForEach(output.problems, id: \.self) { p in
                Label(p, systemImage: "xmark.circle").font(.callout).foregroundStyle(.red)
            }
            ForEach(output.warnings, id: \.self) { w in
                Label(w, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    var symbol: String {
        !output.succeeded ? "xmark.octagon.fill" : output.warnings.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }
    var tint: Color { !output.succeeded ? .red : output.warnings.isEmpty ? .green : .orange }

    var details: String {
        var parts = [output.kind.rawValue]
        if output.succeeded {
            if let r = output.report { parts.append(duration(r.duration)) }
            else if let d = output.checked?.duration { parts.append(duration(d)) }
            if let size = output.size { parts.append(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) }
            if let peak = output.peak, peak.isFinite { parts.append(String(format: "peak %.1f dBFS", peak)) }
        } else {
            parts.append("failed: nothing was saved")
        }
        return parts.joined(separator: " · ")
    }
}

/// A message (§11.3): the plain summary, with the technical detail tucked
/// beneath it.
struct MessageView: View {
    let message: UserMessage
    let symbol: String
    let tint: Color
    @State private var showDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(message.summary, systemImage: symbol).foregroundStyle(tint)
            if let detail = message.detail {
                DisclosureGroup("Details", isExpanded: $showDetail) {
                    Text(detail).font(.caption.monospaced()).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.caption)
            }
        }
    }
}
