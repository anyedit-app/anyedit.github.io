# anyedit 🎬

> AI-Powered Video Editing for macOS

**anyedit** is a revolutionary video editing application that uses artificial intelligence to automatically create stunning videos synchronized to music. Simply drag in your video and audio files, and let AI do the magic!

![anyedit demo](/demo.mp4)

## ✨ Features

### 🤖 AI-Powered Editing

- **Smart Beat Detection**: Advanced audio analysis that detects beats, drops, and musical phrases
- **Intelligent Scene Selection**: AI analyzes video content to select the most engaging moments
- **Automatic Synchronization**: Perfect timing between video cuts and audio beats
- **Narrative Structure**: Creates coherent video flow based on mood and energy

### 🎵 Advanced Audio Analysis

- **Multi-layered Beat Detection**: Core beats, secondary beats, drops, and subtle rhythms
- **Mood Recognition**: Automatically detects energetic, emotional, or tense audio moods
- **Pattern Recognition**: Identifies repeating musical patterns for better transitions

### 🎬 Professional Video Processing

- **Scene Classification**: Wide shots, close-ups, action sequences, and calm moments
- **Motion Analysis**: Detects camera movement and subject motion
- **Visual Consistency**: Maintains smooth color and brightness transitions
- **Smart Transitions**: Cut, crossfade, zoom, and flash effects applied intelligently

## 📦 Installation

### Option 1: DMG Installer (Recommended)

1. __Download__: Get the latest `anyedit_v1.0.0.dmg` from releases
2. **Mount**: Double-click the DMG file to mount it
3. **Install**: Right-click the anyedit.app file and click "Open"
4. **Launch**: Open anyedit from Applications or Spotlight (⌘+Space, type "anyedit")

### Option 2: Build from Source

```bash
# Clone the repository
git clone https://github.com/your-username/anyedit.git
cd anyedit

# Build and create DMG
chmod +x build_dmg.sh
./build_dmg.sh

# Or run directly during development
swift run
```

## 🚀 Quick Start

### 1. Import Your Files

- **Video**: Drag any video file (MP4, MOV, AVI) into the left panel
- **Audio**: Drag your music file (MP3, WAV, M4A) into the left panel

### 2. Let AI Analyze

anyedit will automatically:

- 🎵 Analyze your audio for beats and mood
- 🎬 Scan your video for interesting scenes
- 🤖 Generate an optimized sequence

### 3. Create Your Video

- Click the **"Create AI Video"** button
- Watch the real-time progress as AI processes your content
- Export your final video when complete

### Example Workflow

```ini
1. Drag "my_video.mp4" → AI detects 628 scenes
2. Drag "my_song.mp3" → AI finds 6971 beats
3. Click "Create AI Video" → AI generates 38 perfect segments
4. Export → Get your 20-second masterpiece!
```

## 📋 System Requirements

- **Operating System**: macOS 13.0 (Ventura) or later
- **Processor**: Apple Silicon (M1/M2) or Intel processor
- **Memory**: 4GB RAM minimum, 8GB recommended
- **Storage**: 2GB free disk space
- **Graphics**: Metal-compatible GPU (built into all modern Macs)

## 🎯 Supported Formats

### Video Input

- **MP4** (H.264, H.265/HEVC)
- **MOV** (QuickTime)
- **AVI** (various codecs)
- **MKV** (Matroska)

### Audio Input

- **MP3** (all bitrates)
- **WAV** (uncompressed)
- **M4A** (AAC)
- **FLAC** (lossless)

### Video Output

- **MP4** (H.264, optimized for sharing)
- High quality (1080p/4K maintained)
- Web-optimized for social media

## 🔧 Advanced Configuration

### Beat Detection Sensitivity

anyedit automatically adjusts beat detection based on:

- **Genre Recognition**: Different algorithms for electronic, rock, classical
- **Dynamic Range**: Adapts to quiet/loud music
- **Pattern Learning**: Improves accuracy as it processes more audio

### Video Analysis Depth

- **Scene Types**: 7 different scene classifications
- **Motion Tracking**: Frame-by-frame movement analysis
- **Emotional Scoring**: AI-powered engagement prediction
- **Visual Consistency**: Color and brightness continuity

### Export Settings

- **Quality**: High, Medium, or Custom
- **Resolution**: Maintains source resolution up to 4K
- **Bitrate**: Optimized for quality vs. file size
- **Compatibility**: Ensures playback on all devices

## 🛠️ Development

### Building from Source

```bash
# Prerequisites
xcode-select --install  # Install Xcode Command Line Tools

# Clone and build
git clone https://github.com/your-username/anyedit.git
cd anyedit
swift build --configuration release

# Create distributable DMG
./build_dmg.sh
```

### Project Structure

```ini
anyedit/
├── CoolVideoEditorApp/           # Main application code
│   ├── CoolVideoEditorApp.swift  # App entry point & UI
│   ├── ViewModels/               # SwiftUI view models
│   ├── Services/                 # Core processing services
│   └── Resources/                # Assets and configurations
├── Package.swift                 # Swift Package Manager config
├── build_dmg.sh                 # DMG creation script
└── README.md                    # This file
```

### Core Components

- **`AMVEditViewModel`**: Main application logic and state management
- **`VideoEditingService`**: AI-powered video analysis and processing
- **`AudioProcessingService`**: Beat detection and audio analysis
- **`AnyEditContentView`**: Modern SwiftUI interface

### Key Technologies

- **SwiftUI**: Modern reactive UI framework
- **AVFoundation**: Video/audio processing and analysis
- **Core ML**: Machine learning for scene classification
- **Vision Framework**: Computer vision for video analysis
- **Core Audio**: Advanced audio processing

## 🐛 Troubleshooting

### Common Issues

**App won't open**:

- Right-click anyedit.app → Open to bypass Gatekeeper
- Check System Settings → Privacy & Security for blocked apps

**Video processing fails**:

- Ensure video file isn't corrupted (try in QuickTime)
- Check available disk space (need 2GB+ free)
- Try with a shorter video first

**Poor beat detection**:

- Ensure audio quality is good (not heavily compressed)
- Try with music that has clear rhythm
- Electronic/dance music works best

**Slow performance**:

- Close other video editing apps
- Ensure you have 8GB+ RAM available
- Try with shorter video clips first

### Performance Tips

- **Use SSD storage** for faster video processing
- **Close background apps** that use video/audio
- **Use original quality files** for best results
- **Keep videos under 5 minutes** for optimal speed

## 📈 Roadmap

### v1.1 (Coming Soon)

- [ ] Custom transition effects
- [ ] Manual beat correction tools
- [ ] Batch processing multiple videos
- [ ] Export templates

### v1.2 (Future)

- [ ] Real-time collaboration features
- [ ] Cloud processing for faster AI
- [ ] Custom AI model training
- [ ] Plugin architecture

### v2.0 (Vision)

- [ ] Multi-track audio support
- [ ] Advanced color grading
- [ ] Motion graphics integration
- [ ] Professional export options

## 🤝 Contributing

We welcome contributions! Here's how to get started:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Development Guidelines

- Write clear, documented code
- Add tests for new features
- Follow Swift style guidelines
- Update README for user-facing changes

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Apple** for the incredible AVFoundation and Core ML frameworks
- **Swift Community** for the amazing ecosystem
- **Beta Testers** who provided invaluable feedback

---

**Made with ❤️ and AI in San Francisco**

_anyedit - Where creativity meets artificial intelligence_
