# LocTrip 🎙️🤖

> **Private, On-Device Audio Capture & Bilingual Transcription for macOS (Apple Silicon M2).**

LocTrip is a native macOS application that captures internal system/application output sound (such as **Zoom**, **Google Meet**, or **YouTube**) and transcribes it directly to text using local AI resources.

---

## ✨ Key Highlights

- 🔒 **100% On-Device & Private**: Zero audio or text data leaves your Mac.
- ⚡ **Zero Virtual Audio Drivers**: Uses native macOS **`ScreenCaptureKit`** to capture output sound per-app or system-wide without installing third-party virtual audio cables (no BlackHole or Soundflower required).
- 🧠 **Apple Silicon M2 Optimized**: Powered by **WhisperKit (CoreML)** running inference directly on the **Apple Neural Engine (ANE)** and Metal GPU for minimal CPU usage and low battery drain.
- 🇮🇩 🇬🇧 **Bilingual Indonesian + English Focus**: Built with multilingual Whisper models (`base`, `small`, `large-v3-turbo`) and tokenizer priming to accurately transcribe technical conversations and code-switching ("bahasa campur / Jaksel").
- 🎚️ **Live VU Meter & Waveform**: Real-time audio power monitoring with automatic downmixing to **16,000 Hz mono Float32** format.
- 🪟 **Floating Glassmorphic HUD & Menu Bar**: Always-on-top overlay panel (`NSPanel`) and macOS menu bar status icon for unobtrusive monitoring during full-screen calls.
- 🗂️ **Local Meeting Persistence & Search**: Auto-saves past meeting sessions with date, duration, target app, word count, and full transcripts. Features instant bilingual keyword search across past calls.
- 📋 **Flexible Multi-Format Export**: Export meeting transcripts to GitHub-flavored Markdown (`.md`), Plain Text (`.txt`), or SubRip Subtitles (`.srt`) using the native macOS Save Dialog (`NSSavePanel`) or one-click clipboard copy.
- 🤖 **Bilingual Meeting Summarization**: Generate structured summaries locally:
  - **Ringkasan Eksekutif / Executive Summary**
  - **Poin-Poin Penting / Key Discussion Points**
  - **Tindak Lanjut & PIC / Action Items & Tasks**
  - Works with **Local Ollama LLMs** (`llama3`, `mistral`, etc.) or a fast **100% Offline Built-in Heuristic Engine** with zero dependencies!

---

## 🏗️ Architecture Overview

```
┌────────────────────────────────────────────────────────┐
│                      macOS System                      │
│                                                        │
│  [Zoom / Google Meet / Apps]    [Microphone (Optional)]│
│              │ Output Audio                │ Mic Audio │
│              ▼                             ▼           │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Audio Ingestion Layer                            │  │
│  │ - ScreenCaptureKit (System/App output audio)     │  │
│  │ - AVAudioEngine (Local microphone input)         │  │
│  └──────────────────────────┬───────────────────────┘  │
│                             │ 16kHz Mono Float32       │
│                             ▼                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Audio Resampler & Downmixer                      │  │
│  │ - Accelerate vDSP RMS Audio Level Metering       │  │
│  │ - WAV Test Capture Writer                        │  │
│  └──────────────────────────┬───────────────────────┘  │
│                             ▼                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │ On-Device AI Engine (WhisperKit CoreML)          │  │
│  │ - Apple Neural Engine (ANE) + Metal Acceleration │  │
│  │ - Multilingual models: base, small, large-turbo  │  │
│  └──────────────────────────┬───────────────────────┘  │
│                             ▼                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Native SwiftUI Interface                         │  │
│  │ - Target app selector & live VU meter            │  │
│  │ - Timestamped transcript output & copy controls  │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### Prerequisites
- macOS 14.0 (Sonoma) or newer (macOS 15 / Sequoia / Apple Silicon).
- Apple Silicon Mac (M1 / M2 / M3 / M4) with 16GB RAM recommended.
- Xcode or Command Line Tools with Swift installed.

### Build and Launch

1. **Clone the repository:**
   ```bash
   git clone <repo-url>
   cd loctrip
   ```

2. **Build and package the `.app` bundle:**
   ```bash
   ./scripts/build_app.sh
   ```

3. **Open the app:**
   ```bash
   open "build/LocTrip.app"
   ```

---

## 📖 How to Use

1. **Permissions Setup**:
   - On first launch, follow the onboarding screen to grant **Screen Recording** (required by ScreenCaptureKit to capture internal app audio) and **Microphone** access.
2. **Choose Audio Target**:
   - Select **Entire System Audio** or a specific active app (e.g., Zoom, Google Chrome, Microsoft Teams).
3. **Load AI Model**:
   - Select your preferred model from the dropdown:
     - `Whisper Base (Multilingual)` (~140MB): Fast and lightweight.
     - `Whisper Small` (~460MB): Recommended balance for Bahasa Indonesia.
     - `Whisper Large-v3-Turbo` (~800MB): Highest accuracy for technical meetings.
   - Click **Load Model** to download and cache the CoreML weights locally.
4. **Capture & Transcribe**:
   - Click **Record Output Audio Test** while someone is speaking in your meeting or video.
   - Watch the live VU level bar respond in real-time.
   - Click **Stop Capture Test**.
   - Click **Transcribe Captured Sound** to run local on-device transcription!
   - Copy the transcript with timestamps using the **Copy** button.

---

## 📁 Project Structure

```
loctrip/
├── Package.swift                    # Swift Package Manager manifest with WhisperKit
├── Resources/
│   ├── Info.plist                   # App metadata & permission descriptions
│   └── LocTrip.entitlements         # Audio input & network entitlements
├── Sources/LocTrip/
│   ├── App/                         # SwiftUI @main entry point
│   ├── Permissions/                 # ScreenCaptureKit & Microphone permission manager
│   ├── Audio/                       # ScreenCaptureKit, resampler, circular buffer, VAD, pipeline
│   ├── AI/                          # WhisperKit CoreML, model downloader, transcript segments
│   ├── Storage/                     # MeetingSession, JSON storage, ExportService, LocalSummarization
│   ├── System/                      # Resident RAM profiling, global hotkeys, lifecycle handlers
│   ├── Models/                      # App state and shared ViewModels
│   └── Views/                       # DashboardView, FloatingHUDView, MenuBarManager, MeetingHistoryView
├── scripts/
│   └── build_app.sh                 # Packaging & ad-hoc code-signing script
├── part.md                          # Incremental daily roadmap & checklist
└── README.md                        # Documentation
```

---

## ⌨️ Global Keyboard Shortcuts

LocTrip provides convenient global keyboard shortcuts that function across macOS, even when other full-screen apps (Zoom, Teams, Meet) are frontmost:

| Shortcut | Action | Description |
| :--- | :--- | :--- |
| `Cmd + Shift + R` | **Toggle Transcription** | Starts or stops the live streaming pipeline |
| `Cmd + Shift + H` | **Toggle Floating HUD** | Shows or hides the always-on-top glassmorphic HUD |
| `Cmd + Shift + S` | **Quick-Save Meeting** | Instantly saves current transcript session to local history |
| `Cmd + Shift + C` | **Copy Transcript** | Copies full transcript with timestamps to clipboard |

---

## 🗺️ Development Roadmap

Development progress is tracked incrementally in [part.md](part.md):

- [x] **Part 1**: Project Setup, Permissions & Onboarding UI
- [x] **Part 2**: Output Audio Capture via ScreenCaptureKit (App discovery, 16kHz resampling, WAV testing)
- [x] **Part 3**: Local AI Model Integration (WhisperKit CoreML, multilingual Indonesian/English, batch transcription)
- [x] **Part 4**: Audio Streaming, Chunking & Voice Activity Detection (VAD) (Circular ring buffer, dual-channel mic mixing, live streaming)
- [x] **Part 5**: Real-Time Streaming UI & Floating HUD (Always-on-top glassmorphic HUD, Menu Bar controls, live search)
- [x] **Part 6**: Export, Search & Local LLM Meeting Summaries (Markdown/TXT/SRT export, history browser, bilingual summarizer)
- [x] **Part 7**: Profiling, Hotkeys & Final Polish (M2 RAM telemetry, global hotkeys, AirPods disconnect handling, graceful quit)

---

## 📄 License

MIT License. Designed and built for private on-device local transcription on macOS.
