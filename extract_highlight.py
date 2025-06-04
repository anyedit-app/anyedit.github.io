#!/usr/bin/python3
import sys
import json
import numpy as np
import librosa
import os
import warnings

# Suppress all warnings
warnings.filterwarnings('ignore')

# Redirect debug output to a log file
debug_log = open(os.path.join(os.path.dirname(__file__), 'highlight_debug.log'), 'w')

def log_debug(msg):
    debug_log.write(f"[DEBUG] {msg}\n")
    debug_log.flush()

def to_json_serializable(obj):
    if isinstance(obj, np.ndarray):
        return obj.tolist()
    if isinstance(obj, np.generic):
        return obj.item()
    return obj

if len(sys.argv) < 2:
    print(json.dumps({"error": "No audio file provided"}))
    sys.exit(1)

audio_path = sys.argv[1]

try:
    log_debug(f"Processing audio file: {audio_path}")
    
    # Load the audio file
    y, sr = librosa.load(audio_path)
    
    # Get audio properties
    duration = float(librosa.get_duration(y=y, sr=sr))
    log_debug(f"Audio duration: {duration:.2f}s")
    
    # Extract rhythm features
    tempo, beats = librosa.beat.beat_track(y=y, sr=sr)
    beat_times = librosa.frames_to_time(beats, sr=sr)
    # Properly handle tempo array
    tempo = float(tempo.item() if isinstance(tempo, np.ndarray) else tempo)
    log_debug(f"Detected tempo: {tempo:.1f} BPM")
    log_debug(f"Found {len(beats)} beats")
    
    # Compute onset strength
    onset_env = librosa.onset.onset_strength(y=y, sr=sr)
    
    # Find the section with highest onset density
    window_size = int(5 * sr / 512)  # 5-second window
    onset_sum = np.convolve(onset_env, np.ones(window_size), 'valid')
    peak_idx = int(np.argmax(onset_sum))  # Convert to Python int
    
    # Convert frame index to time
    start_time = float(librosa.frames_to_time(peak_idx, sr=sr))  # Convert to Python float
    
    # Analyze energy around the peak
    peak_energy = float(onset_sum[peak_idx])  # Convert to Python float
    mean_energy = float(np.mean(onset_sum))   # Convert to Python float
    energy_ratio = peak_energy / mean_energy
    log_debug(f"Peak energy ratio: {energy_ratio:.2f}x average")
    
    # Ensure we don't start too close to the end
    if start_time > duration - 20:
        log_debug(f"Adjusting start time from {start_time:.2f}s to avoid end of audio")
        start_time = max(0, duration - 20)
    
    highlight_duration = min(20.0, duration - start_time)
    log_debug(f"Selected highlight: {start_time:.2f}s to {start_time + highlight_duration:.2f}s")
    
    result = {
        "start": start_time,
        "duration": highlight_duration,
        "confidence": energy_ratio,
        "energy_ratio": energy_ratio
    }
    print(json.dumps(result))
    debug_log.close()
except Exception as e:
    import traceback
    error_msg = f"{str(e)}\n{traceback.format_exc()}"
    print(json.dumps({"error": error_msg}))
    debug_log.close()
    sys.exit(1) 