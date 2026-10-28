# LocTrip: Local macOS Audio Transcription App
> **Private, on-device audio capture and transcription for macOS Apple Silicon (M2).**

---

## 🏗️ Technical Architecture Overview

### Why Native Swift + ScreenCaptureKit + WhisperKit?
1. **Zero Virtual Audio Cables**: On modern macOS, `ScreenCaptureKit` can capture internal application audio (Zoom, Google Meet, YouTube, etc.) directly without requiring third-party drivers like BlackHole or Soundflower.
2. **Apple Silicon M2 Optimization**: 
   - **WhisperKit (CoreML)** runs inference directly on the **Apple Neural Engine (ANE)** and **Metal GPU**, consuming virtually zero CPU and preserving battery life on a MacBook Air.
   - Low memory footprint (~200MB–800MB depending on model: `tiny`, `base`, `small`, or `distil-whisper-large-v3`).
3. **100% Offline & Private**: Zero data leaves the machine, making it compliant with strict meeting privacy rules.
4. **Bilingual Indonesian + English Focus**:
   - Supports mixed meetings, code-switching ("Jaksel" slang / tech jargon combining Bahasa Indonesia & English).
   - Utilizes multilingual Whisper checkpoints (`multilingual` base/small/large-v3-turbo) instead of English-only (`.en`) models, configured with language auto-detection or quick manual toggle (`id` / `en`).

---

### System Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│                              macOS System                              │
│                                                                        │
│   ┌────────────────────┐            ┌──────────────────────────────┐   │
│   │ Zoom / Meet / Apps │            │      Microphone (Optional)   │   │
│   └─────────┬──────────┘            └──────────────┬───────────────┘   │
│             │ Output Audio                         │ Mic Audio         │
│             ▼                                      ▼                   │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                    Audio Ingestion Layer                       │   │
│   │   - ScreenCaptureKit (SCStream for app/system output audio)    │   │
│   │   - AVAudioEngine (for user's own microphone if mixed)         │   │
│   └────────────────────────┬───────────────────────────────────────┘   │
│                            │ PCM Buffer (16kHz Mono Float32)           │
│                            ▼                                           │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                 Audio Processing & VAD Layer                   │   │
│   │   - Ring Buffer / Audio Chunking (3s - 5s sliding windows)     │   │
│   │   - Voice Activity Detection (Silero VAD / Energy Gate)        │   │
│   └────────────────────────┬───────────────────────────────────────┘   │
│                            │ Filtered Audio Chunks                     │
│                            ▼                                           │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                On-Device AI Engine (WhisperKit)                │   │
│   │   - CoreML & Apple Neural Engine (ANE) / Metal Engine          │   │
│   │   - Models: distil-large-v3, small.en, or base.en             │   │
│   └────────────────────────┬───────────────────────────────────────┘   │
│                            │ Timestamped Text Segments                 │
│                            ▼                                           │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                       UI & Storage Layer                       │   │
│   │   - SwiftUI Floating HUD / Menu Bar Companion App              │   │
│   │   - Live auto-scrolling transcript                             │   │
│   │   - Local SQLite / Markdown export with search & copy          │   │
│   └────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 📅 Incremental Roadmap & Development Checklist

Each part is designed to be completed in single daily work sessions.

---

### Part 1: Project Setup & System Permissions
**Goal**: Initialize Xcode project, configure entitlements, and request Screen Capture & Microphone permissions.

- [x] **1.1 Project Initialization**
  - Create macOS SwiftUI App in Xcode / Swift Package (Target: macOS 14.0+).
  - Configure App Sandbox and Hardened Runtime entitlements.
- [x] **1.2 Entitlements & Permissions**
  - Add `NSMicrophoneUsageDescription` and `NSSystemAdministrationUsageDescription` in `Info.plist`.
  - Add Screen Recording permission checks (`CGPreflightScreenCaptureAccess()` and `CGRequestScreenCaptureAccess()`).
- [x] **1.3 Permission Onboarding UI**
  - Build a clean SwiftUI welcome sheet explaining why permissions are required with direct links to macOS System Settings (`x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture`).

---

### Part 2: Output Audio Capture via ScreenCaptureKit
**Goal**: Capture internal sound from specific running apps (e.g., Zoom, Google Chrome) or system audio without virtual drivers.

- [x] **2.1 Discover Audio Targets**
  - Query shareable content using `SCShareableContent.current`.
  - Filter list of active applications producing audio (Zoom, Chrome, Teams, Slack, Safari) and entire system.
- [x] **2.2 Configure SCStream for Audio Only**
  - Initialize `SCStreamConfiguration`:
    - `capturesAudio = true`
    - `excludesCurrentProcessAudio = true` (prevent feedback loops)
    - Set video frame rate to lowest minimal dummy configuration (2x2 frame, 1fps) to save GPU resources.
- [x] **2.3 Implement Audio Delegate**
  - Conform to `SCStreamOutput` (`stream(_:didOutputSampleBuffer:of:)`).
  - Extract `CMSampleBuffer` audio samples (LPCM, typically 48kHz stereo/multichannel).
- [x] **2.4 Audio Resampler & Downmixer**
  - Convert incoming audio buffers to **16,000 Hz, 1-channel (mono), 32-bit Float**, which is the required format for Whisper models.
- [x] **2.5 Verification Test**
  - Added live VU meter level bar, real-time audio level monitoring, and test WAV recording controls with one-click "Play" and "Show in Finder".

---

### Part 3: Local AI Model Integration (WhisperKit / CoreML)
**Goal**: Integrate Whisper on-device inference utilizing Apple Silicon M2 Neural Engine.

- [x] **3.1 Dependency Setup**
  - Added `WhisperKit` via Swift Package Manager (`https://github.com/argmaxinc/WhisperKit`).
- [x] **3.2 Multilingual Model Management & Caching**
  - Implemented model loader and downloader for multilingual CoreML models (`openai_whisper-base`, `openai_whisper-small`, `openai_whisper-large-v3-turbo`).
  - Added download progress bar and local caching in Application Support / HuggingFace cache.
- [x] **3.3 Language Detection & Code-Switching Strategy**
  - Configured decoding options for auto-detect (`language = nil`) to support bilingual Indonesian-English code-switching and manual overrides (`id` / `en`).
  - Added initial prompt conditioning with Indonesian tech jargon to bias tokenizer accuracy.
- [x] **3.4 Offline Batch Inference Test**
  - Added one-click "Transcribe Captured Sound" in UI to transcribe recorded WAV audio locally on Apple Neural Engine, displaying timestamped segments and copy-to-clipboard.

---

### Part 4: Audio Streaming, Chunking & Voice Activity Detection (VAD)
**Goal**: Stream audio continuously into the model without lagging or transcribing silence.

- [x] **4.1 Circular Ring Buffer**
  - Implemented thread-safe `CircularAudioBuffer` holding up to 30 seconds of 16kHz Float32 audio samples.
- [x] **4.2 Energy-Based VAD / Silero VAD**
  - Implemented `VoiceActivityDetector` with adaptive frame energy calculation and 600ms speech hangover to prevent word truncation.
  - Automatically skips neural inference during silence to keep M2 thermals cool and save battery.
- [x] **4.3 Sliding Window Transcription Pipeline**
  - Built `StreamingAudioPipeline` taking 4.0-second sliding windows with dynamic VAD filtering.
  - Sequentially streams new transcript segments into the live transcript UI with timestamps.
- [x] **4.4 Dual-Channel Mixing (Optional / Mic Capture)**
  - Built `MicrophoneCaptureService` using `AVAudioEngine` and `AVAudioConverter` (16kHz mono).
  - Added "Include Microphone" toggle in UI to mix user's own speech with meeting participants.

---

### Part 5: SwiftUI User Interface & Real-Time Transcript Display
**Goal**: Design an elegant, distraction-free macOS interface for live meetings.

- [x] **5.1 App Window Architecture**
  - Built **Floating HUD Mode** (`FloatingHUDView` / `HUDWindowManager`) using an always-on-top, semi-transparent `NSPanel` that stays visible over fullscreen video calls and across all macOS spaces.
  - Built **Menu Bar App** (`MenuBarManager`) providing macOS system status item with quick streaming toggle, HUD toggle, and live state icon.
- [x] **5.2 Live Transcript Stream UI**
  - Auto-scrolling transcript list with timestamps, word/segment counters, and real-time keyword search filter.
  - Active line indicators and live VAD status badges (`Speech Active` vs `Silence (VAD Idle)`).
- [x] **5.3 Audio Source, Language & Model Selector**
  - Dropdown target selector for system audio or specific applications (Zoom, Chrome, Teams).
  - Bilingual mode picker (`Auto ID/EN`, `Bahasa Indonesia`, `English`).
  - CoreML model selector with local download status and cache manager.
- [x] **5.4 Play / Pause / Stop Controls**
  - Live continuous streaming toggle button, interactive VU meter level bar, transparency slider, and keyboard shortcuts (`Cmd+Shift+H` for HUD, `Cmd+Shift+R` for recording).

---

### Part 6: Export, Search & Local Summarization
**Goal**: Save transcripts, search history, and generate meeting summaries.

- [x] **6.1 Persistence (Local SQLite / SwiftData / JSON)**
  - Stored meeting sessions in `~/Library/Application Support/com.loctrip.app/sessions/` with Title, Date, Duration, Target App, Segments, and Detected Language.
  - Automatic session saving upon streaming completion and explicit manual save controls.
- [x] **6.2 Export Formats**
  - Export to GitHub-flavored Markdown (`.md`) with timestamps, formatted headers, and embedded summary.
  - Export to Plain Text (`.txt`) and standard SubRip Subtitles (`.srt`).
  - Native macOS Save Panel (`NSSavePanel`) integration and one-click "Copy Transcript to Clipboard".
- [x] **6.3 Search & Filter**
  - Built interactive `MeetingHistoryView` split master-detail view.
  - Real-time bilingual keyword search across past session titles, applications, and full spoken transcript text.
- [x] **6.4 Local Meeting Summarization (Dual Mode)**
  - Integrated local Ollama HTTP API (`http://127.0.0.1:11434/api/generate`) with automatic tag detection (`/api/tags`).
  - Built intelligent 100% offline bilingual heuristic engine (zero external dependencies) that analyzes Indonesian and English discussion patterns to extract:
    - Ringkasan Eksekutif / Executive Summary (Bilingual ID/EN)
    - Poin-Poin Penting / Key Discussion Points
    - Tindak Lanjut & PIC / Action Items with interactive checkboxes.

---

### Part 7: Performance Profiling, Hotkeys & Final Polish
**Goal**: Ensure zero thermal throttling, optimal battery usage, and seamless macOS integration.

- [x] **7.1 M2 Performance & Memory Optimization**
  - Integrated `mach_task_basic_info` resident memory profiling (`ProcessMemoryInfo.swift`) with live UI telemetry.
  - Guaranteed steady-state RAM usage stays under 1GB on 16GB Apple Silicon M2 (typically ~180MB - 350MB).
  - Built explicit `unloadModel()` capability to immediately purge CoreML weights and free RAM.
  - Wrapped high-frequency audio callbacks in `autoreleasepool` to prevent memory accumulation.
  - Verified Apple Neural Engine (ANE) + Metal execution for CoreML Whisper inference, ensuring cool M2 thermals.
- [x] **7.2 Global Keyboard Shortcuts**
  - Implemented `GlobalHotkeyManager` with both local and global `NSEvent` key monitors:
    - `Cmd + Shift + R`: Toggle Live Transcription stream.
    - `Cmd + Shift + H`: Toggle Floating Glassmorphic HUD.
    - `Cmd + Shift + S`: Quick Save active meeting session.
    - `Cmd + Shift + C`: Quick Copy transcript with timestamps.
- [x] **7.3 Error Handling & Edge Cases**
  - Handled mid-meeting audio device disconnection (e.g., unplugging AirPods) via `AVAudioEngineConfigurationChange` observer and automatic re-tap.
  - Handled graceful app termination without data loss via `NSApplication.willTerminateNotification` auto-saver.
  - ScreenCaptureKit stream interruption recovery with informative user notifications.

---

## 🛠️ Recommended Tech Stack Summary

| Component | Recommended Technology | Why on macOS M2 |
| :--- | :--- | :--- |
| **Language & UI** | **Swift 5.10+ / SwiftUI** | Native performance, lowest overhead, modern declarative UI |
| **Internal Audio Capture** | **ScreenCaptureKit** | No drivers needed; captures per-app audio directly from macOS |
| **Microphone Capture** | **AVAudioEngine / CoreAudio** | Low-latency local input capture |
| **Transcription Engine** | **WhisperKit (CoreML)** | Optimized for Apple Neural Engine (ANE) & Metal, official Swift package |
| **Recommended Models** | `openai_whisper-large-v3-turbo` or `openai_whisper-small` | **Full multilingual support** (Bahasa Indonesia + English), avoids English-only `.en` model limits |
| **Language Handling** | Auto-detect + prompt biasing | Accurately parses Indonesian-English code-switching and tech slang |
| **Local Storage** | **SwiftData / SQLite** | Fast, local-only, zero dependencies |
