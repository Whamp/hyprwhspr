# Spec: Document Parakeet V3 (ONNX-ASR) Backend in README & CLAUDE.md

## 1. Understanding the current Parakeet implementation

From the codebase:

- **Backend selection**
  - `ConfigManager` (`lib/src/config_manager.py`):
    - `stt_backend`: `'whisper'` or `'parakeet'` (default currently `'whisper'`).
    - Parakeet-specific keys:
      - `parakeet_model` (default: `"nemo-parakeet-tdt-0.6b-v3"`).
      - `parakeet_model_path` (optional override path).
      - `parakeet_use_quantized` (bool; when `true`, uses `-int8` quantized variant).
  - `STTBackendFactory` (`lib/src/stt_backend_factory.py`):
    - Reads `stt_backend` and returns either `WhisperManager` or `ParakeetManager`.
    - Logs which backend is used.
  - `hyprwhsprApp` (`lib/main.py`):
    - Calls `STTBackendFactory.create(self.config)` and stores the result in `self.whisper_manager` (name, but now any STT backend).
    - Uses `get_backend_info()` for logging, then `transcribe_audio()` for STT.

- **Parakeet backend** (`lib/src/parakeet_manager.py`):
  - Implements `STTBackend` interface.
  - Uses **onnx-asr** (and implicitly ONNX Runtime) to load the Parakeet TDT v3 model.
  - Default model name: `"nemo-parakeet-tdt-0.6b-v3"`; when `parakeet_use_quantized` is `true`, appends `"-int8"`.
  - If `parakeet_model_path` is set, passes that path to `onnx_asr.load_model()` instead of a named model.
  - On first load, `onnx_asr` will download the model if needed (logs note ~3.2 GB download).
  - For transcription:
    - Ensures non-empty audio and minimum duration (~0.1s).
    - Saves to temp WAV via `audio_utils.save_audio_to_wav()` in `~/.local/share/hyprwhspr/temp/`.
    - Calls `self._onnx_model.recognize(<temp_wav_path>)` and returns stripped text.
  - `get_available_models()` looks in `~/.local/share/hyprwhspr/models/parakeet` for a complete model set (`encoder-model.onnx`, `decoder_joint-model.onnx`, `vocab.txt`) and, if present, exposes `"nemo-parakeet-tdt-0.6b-v3"` as available.
  - `set_threads()` currently stores a `threads` value in config and logs a note that model reload is needed to apply it (ONNX Runtime may or may not honor dynamic changes).

- **Whisper backend** (`lib/src/whisper_manager.py`):
  - Still present and unmodified functionally: uses `pywhispercpp` with CPU/GPU auto-detection for CUDA/ROCm/Vulkan, and Whisper-CPP models under `~/.local/share/pywhispercpp/models/`.

- **Dependencies** (`requirements.txt`):
  - Adds Parakeet-related deps:
    - `onnxruntime>=1.15.0`.
    - `onnx-asr>=0.7.0`.

- **Test helper** (`scripts/test-parakeet.py`):
  - Minimal example using `onnx_asr.load_model("nemo-parakeet-tdt-0.6b-v3")` and recognizing a local WAV.

**Conclusion:** The code cleanly supports two backends via `stt_backend`, with Parakeet V3 implemented using `onnx-asr` for CPU-only, high-accuracy STT.

---

## 2. Documentation goals

Update user-facing and contributor docs to:

1. Clearly advertise **Parakeet V3 (ONNX-ASR) as a CPU-only backend** that reaches Whisper V3 Large–level accuracy without requiring a GPU.
2. Explain **how to enable and configure** the Parakeet backend (`stt_backend`, `parakeet_model`, `parakeet_model_path`, `parakeet_use_quantized`).
3. Clarify the relationship between **Parakeet vs Whisper backends**, including when a user might choose each.
4. Reflect new dependencies (`onnxruntime`, `onnx-asr`) and their role.
5. Update `CLAUDE.md` so that tooling/agents understand the new architecture and configuration surface.

I’ll keep scope constrained to **`README.md` and `CLAUDE.md`**, as requested, and only touch other files if you later ask for that.

---

## 3. Planned changes to `README.md`

### 3.1. Top-level description & feature bullets

**Current:**
- Emphasizes Whisper, pywhispercpp, and GPU acceleration as core features.
- Tagline includes `cpu or gpu`.

**Planned updates:**

1. **Project tagline / feature summary** (near the top):
   - Add a bullet for the **new Parakeet backend**:
     - Example: `**Parakeet V3 (CPU-only)** – Whisper-large-level accuracy on plain CPU via ONNX-ASR`.
   - Slightly reword the existing "Whisper-powered" line to clarify that Whisper is now one of the available backends:
     - e.g., `**Whisper / Parakeet backends** – Choose between pywhispercpp (GPU-capable) or Parakeet TDT v3 (CPU-only).`
   - Keep the `all local` emphasis and mention that **GPU is optional** (useful only if users choose the Whisper GPU path).

2. **Prerequisites section:**
   - Make clear that **no GPU is required** for the main experience, thanks to Parakeet:
     - e.g., `GPU (NVIDIA/AMD) optional – only needed if you choose the Whisper GPU backend; Parakeet V3 runs entirely on CPU.`

### 3.2. New section: “Speech backends: Parakeet vs Whisper”

Add a dedicated section (just after the existing "Usage" or "Configuration" section):

- **Heading:** `## Speech backends: Parakeet (CPU) vs Whisper (GPU-capable)`.
- **Content:**
  - Explain the two backends:
    - **Parakeet V3 (recommended for most users):**
      - Uses `onnx-asr` and ONNX Runtime.
      - CPU-only, but roughly Whisper V3 Large–class accuracy.
      - First use triggers a ~3.2 GB model download.
    - **Whisper (pywhispercpp):**
      - Supports CUDA/ROCm/Vulkan acceleration where available.
      - Uses classic Whisper CPP models (`tiny`, `base`, `small`, `medium`, `large`).
  - Explain **how to choose backend** via config:

    ```jsonc
    {
      "stt_backend": "parakeet",  // "parakeet" (CPU-only, Parakeet V3) or "whisper" (pywhispercpp)
      "parakeet_model": "nemo-parakeet-tdt-0.6b-v3" // default Parakeet model
    }
    ```

  - Clarify behavior if `stt_backend` is missing (defaults to `whisper` as per current code) and recommend explicitly setting to `"parakeet"` if users want CPU-only Parakeet.

### 3.3. Configuration section updates

Extend the existing **Configuration** part to include Parakeet-related keys and make `stt_backend` visible.

1. **Minimal config example:**
   - Expand from only `primary_shortcut` and `model` to also show the backend choice:

     ```jsonc
     {
       "primary_shortcut": "SUPER+ALT+D",
       "stt_backend": "parakeet",  // or "whisper"
       "model": "base",            // Whisper model if using whisper backend
       "parakeet_model": "nemo-parakeet-tdt-0.6b-v3" // Parakeet model name or alias
     }
     ```

   - Add a one-line explanation that `model` is used by the Whisper backend, whereas `parakeet_model` is used by the Parakeet backend.

2. **New subsection: “Parakeet configuration”**

   Include a short JSON example highlighting the relevant keys:

   ```jsonc
   {
     "stt_backend": "parakeet",
     "parakeet_model": "nemo-parakeet-tdt-0.6b-v3",   // or custom alias/path supported by onnx-asr
     "parakeet_model_path": null,                      // set to a local directory to bypass auto-download
     "parakeet_use_quantized": false                   // true -> use "-int8" quantized model
   }
   ```

   And document:
   - **`parakeet_model`** – symbolic model name; with default, `onnx-asr` will auto-download from Hugging Face on first use.
   - **`parakeet_model_path`** – optional path if users manually download the ONNX model bundle.
   - **`parakeet_use_quantized`** – when true, appends `"-int8"` to the model name to use a smaller/faster quantized model, trading off some accuracy.

3. **CPU performance options section:**
   - Briefly mention that `threads` affects **Whisper** and is planned/stored for Parakeet as well, but actual threading for Parakeet is governed by ONNX Runtime.
   - Example sentence: `For Parakeet, threading is handled by ONNX Runtime; the "threads" setting is persisted for future tuning but may not change performance on all systems yet.`

### 3.4. New section: “Parakeet V3 model download & storage”

Add a section close to the existing **Whisper Models** section, either before it or as a sibling section.

- **Heading:** `## Parakeet V3 (ONNX-ASR, CPU-only)`.
- **Content:**
  - Explain default behavior:
    - `onnx-asr.load_model("nemo-parakeet-tdt-0.6b-v3")` downloads ~3.2 GB of model data on first use and caches it (location is handled by onnx-asr).
  - Provide a link for manual download (matching the ParakeetManager error message):
    - `https://huggingface.co/istupakov/parakeet-tdt-0.6b-v3-onnx`.
  - Describe the expected files if users manually provision models in `~/.local/share/hyprwhspr/models/parakeet`:
    - `encoder-model.onnx`
    - `decoder_joint-model.onnx`
    - `vocab.txt`
  - Mention that `scripts/test-parakeet.py` can be used as a quick sanity check (optional line, no new steps).

### 3.5. Existing “Whisper Models” section: clarify its scope

Keep the existing Whisper model documentation largely intact, but:

- Add a short lead-in sentence noting that this section is **only for the Whisper backend**:
  - e.g., `This section applies when "stt_backend" is set to "whisper".`
- Optionally, add a sentence at the end pointing users back to the Parakeet section if they want a CPU-only, high-accuracy option.

### 3.6. Troubleshooting section updates

Add a minor troubleshooting item related to Parakeet:

- Under `Common issues`, add an item like **“Parakeet model not found or onnx-asr errors”** with short guidance:
  - Check that `onnx-asr` is installed (installer handles this, but for dev: `pip install onnx-asr onnxruntime`).
  - If manually managing models, ensure the ONNX files exist in the expected directory.
  - Include the Hugging Face link again.

All changes in `README.md` will be additive or clarifying; I won’t remove Whisper docs or change existing Whisper behavior descriptions.

---

## 4. Planned changes to `CLAUDE.md`

`CLAUDE.md` guides tool-based agents; it should reflect the dual-backend architecture and new dependencies.

### 4.1. Project overview

- Extend the overview paragraph to mention:
  - The new **Parakeet V3 (ONNX-ASR) CPU backend**, emphasizing that it reaches Whisper V3 Large–level accuracy without requiring a GPU.
  - That hyprwhspr now supports **two STT backends**: Parakeet (CPU-only) and Whisper (pywhispercpp, GPU-capable).

### 4.2. Key features list

Update the feature bullets to include:

- A new bullet for **Parakeet backend** such as:
  - `CPU-only Parakeet TDT v3 backend via onnx-asr (ONNX Runtime)`.
- Slightly rephrase the existing Whisper/GPU bullet to clarify it is backend-specific:
  - e.g., `Whisper backend with optional CUDA/ROCm/Vulkan acceleration via pywhispercpp`.

### 4.3. Dependencies section

Update the dependencies list to include Parakeet-specific Python dependencies:

- Add:
  - `onnxruntime` – ONNX Runtime for Parakeet backend.
  - `onnx-asr` – High-level ASR interface used to load and run Parakeet TDT v3.
- Clarify which dependencies are tied to which backend (Whisper vs Parakeet), so tools know what is safe to change when working on one or the other.

### 4.4. Architecture & directory structure

Update the architecture section to reflect the new files and concepts:

1. **Directory structure block:**
   - Add entries under `lib/src/` for:
     - `parakeet_manager.py` – ONNX-ASR Parakeet backend implementation.
     - `stt_backend.py` – abstract base class for STT backends.
     - `stt_backend_factory.py` – selects backend based on config (`stt_backend`).
     - `audio_utils.py` – shared audio file utilities (used by Parakeet).

2. **Core Application Flow subsection:**
   - Update initialization step:
     - Replace `WhisperManager` bullet with something like `STT backend (WhisperManager or ParakeetManager via STTBackendFactory)`.
   - Update runtime flow description:
     - When audio is processed, mention that `_process_audio()` runs the configured backend, and `get_backend_info()` indicates which one is active.
   - Clarify system integration:
     - GPU acceleration mentions belong under the **Whisper backend**, while the Parakeet backend is explicitly **CPU-only** via ONNX Runtime.

### 4.5. Configuration system description

Extend the config section to describe the new keys:

- Add `stt_backend` description:
  - `"stt_backend"` – selects STT engine: `"whisper"` or `"parakeet"`.
- Add a short bullet list for Parakeet-specific keys:
  - `"parakeet_model"` – Parakeet TDT v3 model name.
  - `"parakeet_model_path"` – optional model directory override.
  - `"parakeet_use_quantized"` – uses `-int8` quantized variant when true.
- Mention that `threads` applies to Whisper and is stored for Parakeet, with actual threading handled by ONNX Runtime.

### 4.6. Development notes

Add developer-focused notes so tools (and contributors) understand how to work with the Parakeet backend:

- Note that the STT layer is now **pluggable**:
  - All backends must implement `STTBackend`.
  - New backends should be wired through `STTBackendFactory` and use `ConfigManager` for settings.
- Briefly mention `scripts/test-parakeet.py` as a simple sanity-check script for the Parakeet backend.

All changes here are purely documentation, with no behavioral changes.

---

## 5. Assumptions & questions

Before implementing, I’ll follow these assumptions unless you want them adjusted:

1. **Positioning:**
   - We’ll present **Parakeet V3 as the recommended backend for most users** (CPU-only, high accuracy) while keeping Whisper as an advanced/alternative backend.
   - We will **not** claim that Parakeet is the default at runtime, since the code currently defaults `stt_backend` to `"whisper"`; instead, we’ll recommend explicitly setting `"parakeet"` in config.
2. **Scope:**
   - Only `README.md` and `CLAUDE.md` will be edited.
   - Installer scripts and other files (e.g., `install-omarchy.sh`) will stay as-is unless you later ask for changes.
3. **Model details:**
   - We’ll reuse the messaging from `ParakeetManager` about the model size (~3.2 GB) and the Hugging Face URL.
   - We won’t over-specify ONNX-ASR internals (like exact cache directory), to keep docs aligned with the library.

---

## 6. Next steps

If you confirm this spec (or suggest tweaks to wording/positioning), I will:

1. Apply the described edits to `README.md` and `CLAUDE.md` to introduce and document the Parakeet V3 backend.
2. Keep Whisper-related docs intact but clearly scoped to the Whisper backend.
3. Run a quick search afterward to ensure there are no remaining confusing references that imply Whisper is the only backend.

Let me know if you’d like Parakeet explicitly documented as the **default** backend (and/or want the code’s `stt_backend` default changed to `"parakeet"`) so I can align the wording accordingly in the docs when implementing.