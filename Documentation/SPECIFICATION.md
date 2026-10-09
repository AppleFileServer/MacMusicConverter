<!-- The project's requirements baseline, as given by the owner on
2026-10-08, kept word for word below the line. Changes and decisions made
since are recorded in §18 at the end, not edited into the text. -->

---

# MacMusic Audio Converter

## Software Development Specification

**Version:** 1.0 — Initial development specification
**Target platform:** Apple Silicon macOS, MacBook Neo
**Application type:** Native desktop application
**Working name:** MacMusic Audio Converter
**Primary purpose:** Extract audio from a single authorised YouTube video URL or convert existing local audio files, producing standard MP3 files and/or PCM WAV files compatible with the Macintosh Plus MacMusic Player.

---

# 1. Project objectives

Develop a reliable, self-contained macOS application that makes audio conversion straightforward without requiring the user to operate Terminal or understand audio encoding.

The application must provide two main input modes:

1. **YouTube Audio:** Enter one YouTube video URL, retrieve its audio where permitted, and export an MP3, a MacMusic-compatible PCM WAV, or both.
2. **Local File Conversion:** Select an existing audio file on the Mac and convert it to a MacMusic-compatible PCM WAV. Optionally, allow MP3 output or dual output where appropriate.

The application must use one shared audio-processing engine for both input modes, ensuring that resampling, channel conversion, normalisation, encoding and validation behave consistently.

## 1.1 Design principles

* Native macOS experience.
* Apple Silicon compatibility.
* Simple interface with minimal configuration required for routine use.
* Correct audio encoding over convenience shortcuts.
* No unnecessary re-encoding or repeated source retrieval.
* Preserve original source files.
* Transparent progress reporting and useful error messages.
* Reliable handling of interrupted operations.
* Maintainable code with clear separation of responsibilities.
* Persistent documentation so development can resume months or years later without relying on conversation history.

## 1.2 Out of scope for version 1

The following are explicitly excluded:

* Playlist downloading.
* Simultaneous multi-URL processing.
* Batch conversion of multiple local files.
* Video downloading or video conversion.
* Music library management.
* Automatic tagging or retrieval of album artwork.
* Cloud storage or remote processing.
* User accounts or a hosted service.
* DRM circumvention or bypassing access controls.
* An installer for Windows, Linux or Intel-only Macs.

The application processes one job at a time. A job may generate two output files.

---

# 2. Supported workflows

## 2.1 Workflow A — YouTube URL to MP3

1. The user selects YouTube Audio mode.
2. The user pastes a single video URL.
3. The application validates the URL and checks whether it can retrieve the video information.
4. The application displays the available video title when obtainable.
5. The user selects MP3 output.
6. The user chooses an output directory and, optionally, a filename.
7. The application retrieves the authorised source audio and converts it.
8. The MP3 is written to disk and validated.
9. The application displays success, the saved filename and the output location.

The application must not assume that every URL is supported or accessible. Private videos, unavailable videos, unsupported formats, authentication requirements, network failures and service changes must be handled gracefully.

## 2.2 Workflow B — YouTube URL to PCM WAV

Follow the same procedure, but generate an uncompressed PCM WAV suitable for the MacMusic Player.

The PCM output must use the exact encoding defined by the project's verified audio-format contract.

## 2.3 Workflow C — YouTube URL to MP3 and PCM WAV

This is a primary feature, not an optional future enhancement.

1. Paste one URL.
2. Select both output formats.
3. Configure the shared audio-processing settings.
4. Start one job.
5. Retrieve the source audio once.
6. Analyse and process the audio as required.
7. Generate both outputs.
8. Validate each output independently.
9. Report the outcome for each file.

The job must not be marked completely successful if one requested output has failed.

If the MP3 succeeds but the PCM WAV fails, retain the valid MP3 and report the partial failure. Do not present the operation as a complete success.

## 2.4 Workflow D — Existing local MP3 to PCM WAV

1. The user selects Local File Conversion mode.
2. The user selects an existing MP3 using the macOS file picker.
3. The application displays the source filename and, where available, duration and basic audio properties.
4. The user selects PCM WAV output.
5. The application applies the configured channel conversion, resampling, normalisation and sample encoding.
6. The output is written to the chosen destination.
7. The application validates the resulting file.
8. The original MP3 remains unchanged.

The local conversion engine should be extensible to other common audio formats, such as M4A, FLAC, AAC and supported WAV variants. These formats must only be enabled once their decoding and validation paths have been tested.

## 2.5 Workflow E — Existing audio to both MP3 and PCM WAV

Allow the user to select both outputs for a local source file.

For an existing MP3, the application should not unnecessarily re-encode the source into another MP3. If the user requests a new MP3 output, make that action explicit and explain that re-encoding can reduce quality.

---

# 3. Target platform and technical stack

## 3.1 Native application

Use:

* **Swift** for application logic.
* **SwiftUI** for the graphical interface.
* **AVFoundation or Core Audio**, where useful, for native audio information and playback-independent audio utilities.
* **Foundation and FileManager** for filesystem operations.
* **Process** or a suitably designed process-management abstraction for invoking external command-line tools.

The interface should follow normal macOS conventions, including keyboard navigation, native file selection, accessible controls and sensible window resizing.

Use Apple's native application APIs rather than building an Electron application or web-based interface.

## 3.2 External processing tools

Use established tools instead of implementing audio codecs and source retrieval from scratch.

### yt-dlp

Responsible for retrieving metadata and authorised audio streams from supported YouTube URLs.

It must be isolated behind a `YouTubeAudioSource` or equivalent abstraction. The rest of the application must not depend on yt-dlp's internal output format or command-line behaviour.

### FFmpeg

Responsible for decoding supported input formats, analysing audio, resampling, channel conversion, peak normalisation, sample-format conversion, encoding and writing output files.

The exact FFmpeg configuration must be verified against the version selected for distribution.

### Dependency strategy

Prefer a reproducible distribution in which the required tool versions and their provenance are documented.

Investigate whether to:

* Bundle compatible binaries inside the application, subject to licensing and signing requirements; or
* Provide a managed dependency installation and update mechanism.

Do not assume that Homebrew is installed on the end user's Mac. The finished application must not depend on a developer's local Homebrew paths.

The chosen distribution model must be documented, including tool versions, licence notices, update procedures and any required macOS permissions.

Never silently download or replace executable dependencies without verifying their source and integrity.

---

# 4. User interface specification

## 4.1 Main window

The application should open to a compact window with two clearly identifiable modes:

* YouTube Audio
* Local File Conversion

Use a straightforward interface with minimal visual clutter.

### YouTube Audio mode

Required controls:

* URL text field.
* Paste URL action, with ordinary system paste support.
* Retrieve information / Validate URL action.
* Video title and source information area.
* Output format selection.
* Normalisation control.
* Output location selector.
* Output filename controls.
* Start Conversion button.
* Progress indicator.
* Status and error area.

### Local File Conversion mode

Required controls:

* Choose Input File button.
* Selected filename and path.
* Basic source audio information.
* Output format selection.
* PCM settings, using the MacMusic preset by default.
* Normalisation control.
* Output location selector.
* Output filename controls.
* Start Conversion button.
* Progress indicator.
* Status and error area.

### Completion state

Display each requested output separately, showing:

* Filename.
* Format.
* File size.
* Success or failure status.
* An action to reveal the file in Finder.

A failed output must not be represented as a successful file.

## 4.2 Output format selection

Provide three choices:

1. MP3 only.
2. PCM WAV only.
3. MP3 and PCM WAV.

In local conversion mode, output choices must be appropriate to the selected source and must not require unnecessary re-encoding.

## 4.3 Settings

Expose advanced settings in a separate, expandable area rather than cluttering the main window.

Initial settings should include:

* MP3 bitrate or quality.
* PCM sample rate.
* PCM channel count.
* PCM bit depth and signedness where applicable.
* Peak normalisation on/off.
* Normalisation target.
* Default output directory.
* Default filename convention.
* Dependency status and version information.

The MacMusic preset must be clearly identified and protected against accidental changes. Advanced users may create alternative presets.

---

# 5. Audio format contract

This section is critical to the compatibility of the application with the Macintosh Plus player.

## 5.1 MacMusic PCM target

The current intended PCM format is:

| Property              | Target                  |
| --------------------- | ----------------------- |
| Container             | WAV                     |
| Encoding              | Uncompressed linear PCM |
| Sample rate           | 22,050 samples/second   |
| Channels              | Mono                    |
| Sample depth          | 8-bit                   |
| Sample representation | Unsigned PCM            |

These values are the initial target based on the MacMusic project design. They must be verified against the actual MacMusic importer and playback implementation before being treated as final.

The converter must not assume that a `.wav` extension proves compatibility.

## 5.2 Validation requirements

The application must validate the actual output properties:

* WAV container is readable.
* Audio codec is the expected PCM codec.
* Sample rate is correct.
* Channel count is correct.
* Bit depth is correct.
* Sample representation is correct.
* Duration is plausible.
* The file contains audio data.
* The file can be decoded successfully.

Where possible, compare the resulting file against the expected PCM properties using FFprobe or an equivalent independent inspection method.

The MacMusic preset should fail validation if the resulting file does not match its declared requirements.

## 5.3 MP3 output defaults

Initial defaults:

* Container: MP3.
* Encoding: MPEG Layer III.
* Target bitrate: 192 kbps CBR.
* Output extension: `.mp3`.

Allow a small selection of common bitrates, such as 128, 192 and 320 kbps, if supported by the chosen encoder.

The default should prioritise convenience and reasonable file size. Users must be told that encoding a lossy source at a higher bitrate cannot restore lost audio information.

The application should not silently change the requested bitrate.

## 5.4 Resampling

Resampling must use a proper audio resampler rather than simply changing the sample-rate metadata.

Conversion to mono must combine the source channels using an appropriate downmix operation, not merely discard the right channel.

The implementation should guard against clipping, invalid samples and unexpected duration changes.

---

# 6. Normalisation and audio processing

## 6.1 Normalisation objective

Provide optional peak normalisation so that the maximum absolute audio peak reaches a configurable target level.

Suggested initial target: **−1.0 dBFS**.

This is peak normalisation, not loudness normalisation. It does not guarantee that songs will sound equally loud because their average levels and dynamic ranges may differ.

The interface and documentation must distinguish these concepts.

## 6.2 Processing sequence

Use a shared audio-processing pipeline:

1. Read or retrieve the source audio.
2. Decode it into a suitable high-quality intermediate representation.
3. Analyse the signal when peak normalisation is enabled.
4. Determine the required gain.
5. Apply the gain, respecting the target peak.
6. Branch into the requested output encoders.
7. Resample and convert channels as needed for each output.
8. Encode each output independently.
9. Validate each file.

Use floating-point or sufficiently high-precision intermediate audio so that conversion does not introduce avoidable quantisation loss before the final output stage.

Do not use the low-bit-depth MacMusic output as the intermediate source for MP3 generation.

## 6.3 Consistent output levels

When dual export is requested, the MP3 and PCM WAV should originate from the same source audio and use the same normalisation analysis and gain decision.

The final measured peak may differ slightly between outputs because of resampling, quantisation and MP3 encoding. This is expected and should be documented.

## 6.4 Clipping and silence

* Detect invalid or non-finite samples where supported.
* Avoid applying gain that exceeds the configured peak target.
* Handle silent or near-silent recordings without division-by-zero errors or arbitrary amplification.
* Report normalisation as skipped where the source contains no meaningful signal.
* Do not silently remove silence or alter the track's duration.

---

# 7. Shared application architecture

Use a modular architecture with clear boundaries between the interface, retrieval, conversion and filesystem operations.

Suggested project structure:

```text
MacMusicAudioConverter/
├── App/
│   ├── MacMusicAudioConverterApp.swift
│   └── AppState.swift
├── UI/
│   ├── MainWindowView.swift
│   ├── YouTubeAudioView.swift
│   ├── LocalConversionView.swift
│   ├── OutputSettingsView.swift
│   ├── ProgressView.swift
│   └── CompletionView.swift
├── Domain/
│   ├── ConversionJob.swift
│   ├── AudioSource.swift
│   ├── AudioFormat.swift
│   ├── OutputConfiguration.swift
│   └── ConversionResult.swift
├── Sources/
│   ├── YouTubeAudioSource.swift
│   └── LocalAudioSource.swift
├── Processing/
│   ├── AudioConversionEngine.swift
│   ├── AudioAnalyser.swift
│   ├── AudioNormaliser.swift
│   ├── AudioResampler.swift
│   └── PCMEncoder.swift
├── Outputs/
│   ├── MP3OutputWriter.swift
│   ├── WAVOutputWriter.swift
│   └── OutputValidator.swift
├── Infrastructure/
│   ├── ProcessRunner.swift
│   ├── DependencyManager.swift
│   ├── FileManagerService.swift
│   └── LoggingService.swift
├── Tests/
│   ├── UnitTests/
│   ├── IntegrationTests/
│   └── TestFixtures/
├── Resources/
├── Documentation/
│   ├── SPECIFICATION.md
│   ├── ARCHITECTURE.md
│   ├── BUILDING.md
│   ├── TESTING.md
│   ├── RELEASES.md
│   └── CHANGELOG.md
└── README.md
```

This is a proposed logical structure, not a requirement to create an individual Swift file for every small type. Keep the implementation proportionate and avoid needless abstraction.

## 7.1 Conversion job model

Represent each conversion as an explicit job containing:

* Source type.
* Source URL or local file URL.
* Requested output formats.
* Output destination.
* Output naming configuration.
* Normalisation configuration.
* PCM configuration.
* MP3 configuration.
* Current job state.
* Per-output results.
* Structured errors.

Suggested job states:

`idle → validating → retrieving → analysing → converting → validatingOutputs → completed`

Where appropriate, include `cancelled`, `failed` and `completedWithErrors`.

A local conversion may skip the retrieval stage. A conversion without normalisation may skip the analysis stage.

## 7.2 Shared conversion engine

The conversion engine must not depend on SwiftUI views.

The interface should create a job, submit it to the engine and observe state changes.

Both YouTube retrieval and local file conversion must use the same engine after the source has been obtained.

The engine must be testable independently of the graphical interface.

## 7.3 Process management

Wrap external command-line execution in a dedicated process runner.

Requirements:

* No blocking of the main UI thread.
* Capture standard output and standard error.
* Record process exit status.
* Support cancellation.
* Terminate child processes when a job is cancelled, where safe.
* Prevent shell injection by passing executable arguments separately rather than constructing shell command strings.
* Distinguish executable-not-found errors from conversion errors.
* Avoid logging credentials, cookies or other sensitive values.
* Parse progress output robustly, without assuming all output is valid JSON.

Use structured argument arrays. Never concatenate user-supplied URLs or filenames into a shell command.

---

# 8. YouTube source retrieval

## 8.1 URL validation

Accept a single supported video URL.

Reject:

* Empty input.
* Malformed URLs.
* Unsupported domains.
* Playlist-only URLs when no individual video is selected.
* URLs that resolve to unsupported or unavailable content.

Where a URL contains both video and playlist information, process only the explicitly selected video and do not traverse the playlist.

URL validation is a usability and safety measure; it is not proof that downloading the content is authorised.

## 8.2 Retrieval implementation

Use yt-dlp as an external source adapter.

The adapter should:

* Retrieve metadata where available.
* Identify a supported audio stream.
* Retrieve audio without downloading video unnecessarily.
* Preserve the original source audio quality as far as practicable.
* Provide progress and useful diagnostics.
* Support cancellation.
* Return a well-defined source result to the shared conversion engine.

Prefer a direct source-audio download followed by local conversion, rather than generating an intermediate MP3 unnecessarily.

## 8.3 Access restrictions

The application is intended for content the user owns, has permission to download, or is otherwise entitled to save.

Do not implement DRM circumvention, access-control bypasses or covert credential extraction.

Do not claim that all YouTube videos can be downloaded. Network availability, service restrictions, content permissions and changes to the retrieval tool may prevent retrieval.

If a video requires authentication, the application should explain the restriction and stop safely unless an explicitly supported, lawful authentication method is implemented.

Any later authentication feature must be separately designed and reviewed for secure credential handling.

---

# 9. Local file conversion

## 9.1 File selection

Use a native macOS file picker.

Request access only to files selected by the user and the destination directory chosen for output. Follow macOS sandboxing requirements if the application is sandboxed.

The application must not scan the user's music folders without explicit selection or permission.

## 9.2 Source inspection

Inspect the selected file before processing.

Check:

* File existence and readability.
* Supported audio format.
* Successful decoding.
* Duration where available.
* Sample rate.
* Channel count.
* Bit depth or codec properties where available.
* Sufficient free disk space for the requested output, where practical.

Do not trust file extensions alone.

## 9.3 Original-file protection

The original file must never be overwritten or modified.

If the output filename conflicts with an existing file, ask the user whether to replace it or generate a unique filename. Default to preserving the existing file.

The same protection applies when the source and output directories are identical.

## 9.4 Future format expansion

Keep source-format support separate from output-format support.

New input formats should be added through the source decoding layer without rewriting the MacMusic PCM conversion logic.

Do not advertise a format as supported until its actual decoding, processing and validation path has passed tests.

---

# 10. File naming and destination management

Provide a default output naming scheme.

For example, a source named `Example Song.mp3` might produce:

```text
Example Song.mp3
Example Song.wav
```

For YouTube input, derive a safe base filename from the video title where available.

Filename handling must:

* Remove or replace invalid filesystem characters.
* Avoid unintended path traversal.
* Handle Unicode names correctly.
* Handle duplicate names predictably.
* Preserve useful extensions.
* Avoid collisions between generated outputs.
* Never use an untrusted title as an unrestricted filesystem path.

The user should be able to select a default output directory and change it for an individual job.

Use temporary files during conversion and validation. Only move completed outputs into their final locations once the relevant checks pass.

For dual output, each output should have an independent result. If one output fails, do not destroy the other valid output.

---

# 11. Progress, cancellation and error handling

## 11.1 Progress reporting

Display meaningful stages:

* Validating input.
* Retrieving source information.
* Retrieving audio.
* Analysing audio.
* Converting audio.
* Writing output.
* Validating output.
* Completed.

Show a percentage only when the underlying process provides sufficiently reliable information.

Do not fabricate precise progress values for operations whose duration cannot be estimated.

## 11.2 Cancellation

Provide a Cancel button while a job is active.

Cancellation should:

1. Signal the active operation to stop.
2. Terminate managed child processes where appropriate.
3. Remove incomplete temporary files.
4. Preserve completed and validated outputs.
5. Report that the job was cancelled.

A cancellation must not leave a partial output with a normal-looking final filename.

## 11.3 Error categories

At minimum, distinguish:

* Invalid URL.
* Unsupported URL.
* Video unavailable.
* Retrieval blocked or not authorised.
* Network failure.
* Dependency missing or incompatible.
* Source file unreadable.
* Unsupported audio codec.
* Corrupt audio.
* Insufficient disk space.
* Destination unavailable.
* Output filename conflict.
* Conversion failure.
* Output validation failure.
* Cancellation.
* Partial success.

Show a concise explanation to the user and retain useful technical diagnostics for troubleshooting.

Avoid presenting raw FFmpeg or yt-dlp output as the only error message.

---

# 12. Security, privacy and licensing

* No telemetry by default.
* No account system.
* No transmission of local audio files to a remote conversion service.
* No collection of a user's music library.
* No embedded secrets.
* No unsafe shell command construction.
* No automatic execution of files derived from a video title or audio metadata.
* No unnecessary retention of temporary files.
* No logging of sensitive authentication information.
* No claim that the application is officially affiliated with YouTube or Apple.

All bundled dependencies must be reviewed for redistribution rights, licence notices and applicable source-code obligations.

The application must follow applicable platform rules and the terms governing access to the source content. Download functionality must not be marketed as a means to circumvent restrictions.

If sandboxing, code signing or notarisation is used, document the requirements and build process.

---

# 13. Testing requirements

Testing must be designed into the project rather than postponed until the application appears complete.

## 13.1 Unit tests

Test:

* URL validation.
* Filename sanitisation.
* Output naming.
* Configuration validation.
* Conversion state transitions.
* Normalisation calculations.
* Silence handling.
* Error mapping.
* Output selection logic.
* Cancellation state transitions.
* Duplicate filename handling.

## 13.2 Audio conversion tests

Use locally stored, legally usable test fixtures so that routine tests do not depend on YouTube availability.

Include:

* Mono MP3.
* Stereo MP3.
* Low-bitrate MP3.
* Different input sample rates.
* Very short audio.
* Long audio.
* Silent audio.
* Near-silent audio.
* Audio with peaks near full scale.
* Audio with different channel levels.
* Corrupt and truncated input files.

Verify the resulting audio properties with an independent inspection tool.

For MacMusic PCM output, assert the required WAV codec, sample rate, mono channel count, sample depth and unsigned sample representation.

Check duration and decoded audio content within appropriate tolerances.

## 13.3 Dual-output tests

Verify that:

* Both requested outputs are created.
* Both outputs originate from the same input.
* Shared normalisation settings are applied consistently.
* The MP3 is a valid MP3.
* The PCM file meets the MacMusic format contract.
* Failure of one branch is reported accurately.
* Successful output from one branch is preserved if the other fails.
* No incomplete file is reported as complete.

## 13.4 YouTube integration tests

Use only a controlled test video that the developer is authorised to download.

Test:

* A valid video URL.
* Invalid input.
* Unavailable content.
* Network interruption.
* Retrieval failure.
* Cancellation during retrieval.
* Cancellation during conversion.
* Dependency incompatibility.

Integration tests should be optional where external network access is required. The core automated test suite must run without a live YouTube connection.

Do not build the tests around one permanent public video whose availability or accessibility may change.

## 13.5 User acceptance tests

On the target MacBook Neo:

1. Launch the application from a clean installation.
2. Confirm dependency detection or installation works.
3. Convert a local MP3 to PCM WAV.
4. Verify the PCM file's properties.
5. Import the result into the MacMusic Player.
6. Confirm that playback works correctly.
7. Convert one authorised YouTube video to MP3.
8. Convert the same source to both MP3 and PCM WAV.
9. Verify both outputs.
10. Cancel an active job.
11. Test a missing or invalid input.
12. Test a destination filename conflict.
13. Confirm that the original files remain unchanged.
14. Restart the application and verify that saved preferences persist.

MacMusic compatibility is not complete until the generated PCM file has been successfully imported and played on the actual player or an appropriately validated development build.

---

# 14. Development roadmap

Use staged development. Each stage must have a clear acceptance criterion before the next stage begins.

## Stage 0 — Repository and environment inspection

* Inspect the existing MacBook Neo development environment.
* Confirm Xcode and the macOS SDK version.
* Check the target deployment version.
* Establish a dedicated repository for this application.
* Create the initial specification and project documentation.
* Confirm the intended distribution and dependency strategy.

**Acceptance criterion:** The project builds a minimal native SwiftUI application on the target machine, and the initial repository is committed.

## Stage 1 — Audio format proof of concept

* Select a local MP3.
* Invoke FFmpeg through the process-management abstraction.
* Produce the target PCM WAV.
* Inspect its actual properties.
* Import the file into MacMusic and test playback.
* Document any discrepancies between the proposed format and the actual player requirements.

**Acceptance criterion:** A reproducible local test produces a WAV that meets the verified format contract and plays correctly in MacMusic.

Do not begin the YouTube integration until this stage succeeds.

## Stage 2 — Shared conversion engine

* Implement conversion job models.
* Implement source inspection.
* Implement PCM conversion.
* Implement optional peak normalisation.
* Implement output validation.
* Add unit and audio fixture tests.

**Acceptance criterion:** Local conversion works reliably through the engine without relying on the graphical interface.

## Stage 3 — MP3 output and dual export

* Implement MP3 output.
* Add output format selection.
* Implement shared normalisation analysis.
* Add dual-output processing.
* Implement per-output success and failure handling.
* Add tests for both outputs and partial failures.

**Acceptance criterion:** A local source can generate a valid MP3 and MacMusic-compatible PCM WAV in one job.

## Stage 4 — Native user interface

* Build the main window.
* Add YouTube and Local File Conversion modes.
* Implement file selection and destination selection.
* Add progress reporting and cancellation.
* Add completion and error states.
* Persist user preferences.

**Acceptance criterion:** All local conversion workflows are accessible through the graphical interface without Terminal interaction.

## Stage 5 — YouTube source integration

* Implement the yt-dlp source adapter.
* Add URL validation and metadata retrieval.
* Retrieve audio without downloading unnecessary video data.
* Connect the retrieved source to the shared conversion engine.
* Test supported, unavailable and interrupted sources.
* Ensure dual export works from one retrieval job.

**Acceptance criterion:** An authorised test video can produce an MP3, a PCM WAV and both outputs in one operation.

## Stage 6 — Reliability and security hardening

* Test cancellation and process cleanup.
* Test filenames and path handling.
* Test disk-space and destination failures.
* Review logging and privacy.
* Review bundled dependency licensing.
* Test the application from a clean installation.

**Acceptance criterion:** The application handles expected failures safely and does not leave incomplete files represented as successful outputs.

## Stage 7 — Packaging and release

* Choose the final dependency distribution strategy.
* Configure code signing and notarisation if appropriate.
* Produce a clean release build.
* Verify operation outside the Xcode development environment.
* Complete the README and release notes.
* Archive the source, dependency versions, build instructions and test results.

**Acceptance criterion:** The app launches and performs its documented functions on the target MacBook Neo without relying on development-only paths or manually prepared test state.

---

# 15. Documentation and project continuity

The project must remain understandable without access to the original development conversation.

Maintain the following files:

* `README.md` — project overview, installation and normal use.
* `SPECIFICATION.md` — this document, updated when requirements change.
* `ARCHITECTURE.md` — module responsibilities, dependencies and data flow.
* `BUILDING.md` — exact build commands and environment requirements.
* `TESTING.md` — test commands, fixtures, expected results and compatibility checks.
* `RELEASES.md` — release and packaging procedure.
* `CHANGELOG.md` — meaningful changes between versions.

Document all important deviations from the specification and the reason for each.

Use version control. Make small, coherent commits after each verified milestone.

Do not leave the project dependent on undocumented manual changes, uncommitted fixes or temporary build artefacts.

A future developer must be able to open the repository, read the documentation, rebuild the application and understand the current implementation without needing the original conversation.

---

# 16. Definition of done

Version 1.0 is complete when all the following conditions are met:

* [ ] A native Apple Silicon macOS application builds successfully.
* [ ] YouTube mode accepts one video URL at a time.
* [ ] Local conversion accepts an existing MP3.
* [ ] The application can generate MP3 output.
* [ ] The application can generate a MacMusic-compatible PCM WAV.
* [ ] The application can generate both outputs in one job.
* [ ] Both outputs use a consistent source and normalisation decision.
* [ ] PCM output is verified against the final audio-format contract.
* [ ] PCM output successfully imports into and plays in MacMusic.
* [ ] The original local input is never overwritten.
* [ ] Progress and cancellation work as documented.
* [ ] Partial failures are reported accurately.
* [ ] Incomplete outputs are not mistaken for successful files.
* [ ] Core automated tests pass.
* [ ] The dependency distribution and licensing approach is documented.
* [ ] The application works outside the development environment.
* [ ] The repository contains sufficient documentation to resume development later.

---

# 17. Instructions for Claude Code

Treat this document as the project's initial requirements baseline.

Before implementing the application:

1. Inspect the current development environment.
2. Confirm the available Xcode version, target macOS SDK and deployment target.
3. Review the specification and identify any unresolved technical decisions.
4. Verify the MacMusic PCM format contract against the existing player implementation if that project is available.
5. Propose the initial repository structure and Stage 0 implementation plan.

Then proceed stage by stage.

Do not attempt to implement the entire application in one large change. Establish the local PCM conversion proof of concept first, because compatibility with the Macintosh Plus player is a critical project requirement.

At the end of each stage:

* Run the relevant tests.
* Report what has actually been implemented.
* Record test results and any limitations.
* Update the documentation.
* Identify any deviations from the specification.
* Commit the verified work to version control.

Do not claim that a feature works until it has been built and tested. If a technical decision cannot be verified, document the uncertainty rather than guessing.

The final objective is a reliable, maintainable macOS utility that can be returned to in the future and rebuilt from its archived source and documentation.

---

# 18. Decisions and findings (kept up to date)

## 18.1 Stage 0 decisions (2026-10-08, approved by the owner)

- **T1, the name:** *MacMusic Transfer Utility* (the spec's working name,
  "MacMusic Audio Converter", is replaced). It sits with the companion
  manual *MacMusic Utilities*.
- **T2, the scope of version 1:** the conversion described above.
  Getting files onto the Mac (a disk image, BlueSCSI) is a later stage of
  its own, despite the name.
- **T3, the repository:** its own git repository,
  `~/MacPlusProjects/MacMusicTransfer/`, beside the MacMusic project
  (`~/MacPlusProjects/MacMusicPlayer/`).
- **T4, the project form:** a Swift package: the engine as a library
  (`MacMusicTransferKit`, no SwiftUI), tested with `swift test`; the
  SwiftUI app as an executable (`MacMusicTransfer`); `tools/build-app.sh`
  wraps it into a signed `.app`. Built from the terminal; no Xcode
  project. (Deviation from §7's suggested layout: the same parts, in
  SwiftPM's folders.)
- **T5, the engine:** FFmpeg throughout (§3.2), plus a Swift validator
  that applies MacMusic's own WAV rules (§18.2), so "MacMusic will accept
  it" is tested directly, not inferred.
- **T6, the tools:** pinned, checksum-verified FFmpeg and yt-dlp
  binaries, kept outside the repository (like the MacMusic manual's
  tools), copied into the app bundle at build time, and included in the
  MacMusic environment archive. yt-dlp is updated by hand, checksum
  checked, never silently. Licences recorded in `RELEASES.md`.
- **T7, MacMusic extras:** the WAV carries `LIST/INFO` tags (title,
  artist, album, genre, track) in Latin-1, each at most 63 characters, so
  MacMusic fills in the song's details on import; WAV file names at most
  31 characters, no colon (the Mac's HFS limit); dither when reducing to
  8 bits. Carrying the source's own details over is not the "automatic
  tagging" §1.2 excludes.
- **T8, the target:** macOS 26 on the owner's MacBook Neo; signed ad hoc;
  not sandboxed; not notarised (own use). To revisit if it is ever
  shared.

## 18.2 The MacMusic PCM contract, verified (§5.1, §17 item 4)

Checked against MacMusic 1.0's importer, `src/wav.c` (`Wav_Read`), in
the MacMusic repository, 2026-10-08. A file is accepted when:

| Check | Rule |
|---|---|
| Container | `RIFF` ... `WAVE` in the first 12 bytes |
| Chunks | each chunk's size within the file; chunks padded to even lengths |
| `fmt ` chunk | present, at least 16 bytes |
| Format tag | 1 (plain PCM). 0xFFFE (extensible) and all others refused |
| Channels | 1 |
| Sample rate | 22,050 |
| Bits per sample | 8 (unsigned, as 8-bit WAV always is) |
| Block align | 1 |
| Byte rate | 22,050 |
| `data` chunk | present, length above 0 |
| `iPod` chunk | if present, must end the file (MacMusic's own, added on import; a converter never writes it) |

This is the §5.1 target exactly. MacMusic also:
- reads a `LIST`/`INFO` chunk, the first 1,024 bytes of it, for
  `INAM` (title), `IART` (artist), `IPRD` (album), `IGNR` (genre) and
  `ITRK` (track), as Latin-1, converted to Mac Roman; details are cut to
  63 characters;
- plays at the Macintosh Plus's 22,254 samples a second, so songs run
  about 0.9% fast (a property of the Mac, not of the file);
- needs about 1.3 MB of disk a minute.

To be confirmed in Stage 1: a converted file imports and plays in
MacMusic (Mini vMac, then the real Plus).

## 18.3 The environment (2026-10-08)

- MacBook Neo (Mac17,5, Apple A18 Pro), macOS 26.4.1.
- Xcode 26.6 (17F113), macOS SDK 26.5, Swift 6.3.3.
- `xcrun`'s default SDK lookup fails on this Mac (it looks in the
  Command Line Tools); `xcrun --sdk macosx` works. See `BUILDING.md`.
- FFmpeg and yt-dlp: not installed (Stage 1 fetches pinned copies, T6).

## 18.4 Stage 1 decisions (2026-10-09, approved by the owner)

- **S1, FFmpeg:** Martin Riedl's static Apple silicon builds
  (ffmpeg.martin-riedl.de): signed and notarised, with published SHA-256
  checksums, LAME and the SoX resampler included. One release pinned;
  checksum and signature checked. A GPL build: fine for own use
  (RELEASES.md).
- **S2, where the tools live:** `~/MacPlusProjects/transfer-tools/`,
  outside the repository, with a manifest (version, URL, checksum).
- **S3, the conversion:** the first audio stream; decoded to 32-bit
  float; downmixed to mono by averaging; resampled to 22,050 Hz with the
  SoX resampler; triangular dither to unsigned 8-bit; plain WAV (format
  1), bitexact (FFmpeg adds no tags).
  - **The title only (the owner's change):** the user may type a title,
    written as the WAV's one INFO tag (`INAM`), Latin-1, at most 63
    characters; blank, no tag (MacMusic then uses the file name). No
    other details are carried over: artist, album and the rest are
    entered in MacMusic's import dialog. (Replaces T7's tags.)
  - **A plain WAV, ready for import:** never a MacMusic library file;
    never an `iPod` chunk (the validator checks).
- **S4, test fixtures:** generated by FFmpeg during the tests (tones,
  silence, a truncated file); no music in the repository.
- **S5:** a developer's command-line tool, `mmt-convert`, converting one
  file, until the window does.
- **S6, the MacMusic check:** the WAV copied onto MacMusic's
  `Transfer.dsk` with hfsutils (Mini vMac closed), imported and played by
  the owner. The test song: the owner's "Good Luck, Babe!" MP3.
- **S7, trimming silence at the ends (the owner's addition; Stage 2):**
  an option, off by default: silence below −50 dBFS at the start or end
  lasting longer than 2 s (or 3 s, the user's choice) is cut down to a
  half-second gap. Never in the middle. Measured in the analysis pass,
  applied to every output alike, and reported ("Trimmed 3.4 s from the
  start"). **Deviation from §6.4** ("do not silently remove silence or
  alter the track's duration"): chosen by the owner; not silent, as it's
  an option and reported, but it does change the duration.

## 18.5 Stage 1 findings (2026-10-09)

- **No SoX resampler** in the pinned FFmpeg (not built with libsoxr), so
  S3's resampler is FFmpeg's own at high-quality settings (filter size
  128, phase shift 14, cutoff 0.97, linear interpolation). At 8 bits the
  difference can't be heard. (Deviation from S3 as approved.)
- **Real length:** an MP3's header only estimates its length, so the
  converter decodes the source once to measure it, checks the output
  against that, and warns when the header disagrees (a damaged or
  cut-short file). Stage 2's analysis pass will measure it with the peak.
- **The title's text:** MacMusic drops bytes 0x80-0x9F, so typographic
  punctuation is made plain ASCII and letters outside Latin-1 are
  transliterated, before the title is stored.
- **The title's place:** the LIST/INFO chunk is appended after the audio
  (MacMusic reads it wherever it is), which keeps FFmpeg's output as it
  is and avoids FFmpeg's UTF-8 tags.
- **Real song:** "Good Luck, Babe!" (MP3, 44.1 kHz stereo, 218.34 s) to a
  4.8 MB WAV, 218.33 s, passing MacMusic's rules, ffprobe and a decode;
  the MP3 unchanged. Copied onto MacMusic's Transfer.dsk, imported and
  played in MacMusic under Mini vMac by the owner (2026-10-09): it plays,
  and the title came in from the WAV. **Stage 1's acceptance criterion is
  met.** Still to do: the same on the real Macintosh Plus.

## 18.6 Stage 2 decisions (2026-10-09, approved by the owner)

- **N1, the analysis:** FFmpeg decodes the source to 32-bit float at its
  own rate and channels and streams it into Swift, which measures the
  real length, each channel's peak, the silent ends and any broken
  (NaN or infinite) samples, sample by sample. Not `volumedetect` or
  `silencedetect` logs.
- **N2, the gain:** once, from the source's loudest channel, before the
  mixdown, in float; it may raise or lower; default target −1 dBFS; the
  same gain for every output (Stage 3's MP3 too). Neither output can
  clip; a mono WAV from uneven channels may peak below the target, and
  the result says so.
- **N3, quiet sources:** a peak below −50 dBFS: normalisation skipped,
  and why. Otherwise the gain is capped at +20 dB, and the cap reported.
- **N4, the trim (S7):** silence means every channel below −50 dBFS,
  sample by sample; longer than 2 s (or 3 s) at an end, it's cut to a
  half-second gap; never the middle; an all-silent source isn't trimmed
  away; reported. Applied before the gain.
- **N5, progress:** stages now (validating, analysing, converting,
  validating outputs, then completed, completed with errors, failed or
  cancelled); percentages in Stage 4.
- **N6, PCM settings:** the MacMusic format only; §4.3's alternative PCM
  presets are left out of version 1 (MacMusic accepts only the one).
  **Deviation from §4.3.**
- **N7, names:** made safe (no slashes, colons, control characters or
  leading dots; letters the Mac can't show transliterated); the WAV's
  name at most 31 characters with ".wav", cut at a word where it can be;
  a taken name is refused, given the next free name ("Song 2.wav"), or
  replaced (only once the user confirms, Stage 4). `mmt-convert` takes
  the next free name.
- **N8, free space:** the WAV's size (1.3 MB a minute plus 1 MB) checked
  against the destination's free space before converting.

## 18.7 Stage 2 findings (2026-10-09)

- **`Process.waitUntilExit` hung** on a background thread after the tool
  had exited (seen while streaming). The runner now waits on the
  termination handler, and finishes when both the output has been read
  to its end and the tool has exited.
- **The real song:** "Good Luck, Babe!" normalised (−0.9 dB: its peak
  was −0.1 dBFS) and trimmed (3.3 s of silence at the end, none at the
  start) in 1.4 s; the WAV peaks at −1.9 dBFS (mono from stereo).
- **Not tested end to end:** running out of disk space (the estimate is
  unit-tested; a full disk is for Stage 6's hardening).
