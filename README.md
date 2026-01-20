# Minecraft Ultimate Launcher

A native macOS application for streamlined Minecraft mod management and modpack creation.

## 🎯 Project Goal

Minecraft Ultimate Launcher aims to simplify the modding experience for macOS users by providing an intuitive, native interface for managing mods, creating modpacks, and launching modded Minecraft instances.

## ✨ Planned Features

### Core Functionality
- **Intelligent Mod Management**: Browse, search, and install mods from CurseForge with one click
- **Automatic Dependency Resolution**: Automatically detect and install required dependencies (e.g., GeckoLib, Fabric API)
- **Conflict Detection**: Identify incompatible mods and version mismatches before launch
- **Multi-Modpack Support**: Create and manage multiple independent modpacks with different configurations

### Forge/NeoForge Integration
- **Automatic Installation**: Detect and install appropriate Forge/NeoForge versions automatically
- **Version Management**: Support multiple Minecraft and loader versions simultaneously
- **Seamless Launch**: Generate launcher profiles and integrate with official Minecraft launcher

### Advanced Features
- **Modpack Export/Import**: Share modpacks with friends via portable files
- **Snapshot System**: Save modpack states before making changes, with easy rollback
- **Server Creation**: Generate modded or vanilla servers with one click
- **Performance Optimization**: Suggested Java arguments and RAM allocation based on modpack

## 🛠 Technology Stack

- **Language**: Swift 5+
- **UI Framework**: SwiftUI
- **Platform**: macOS 12+
- **Data Storage**: SQLite for modpack metadata
- **APIs**: CurseForge API, Modrinth API (planned)
- **Java Management**: Bundled Azul Zulu JDK 17

## 🏗 Project Status

**Status**: In Development - API Access Pending

Currently awaiting CurseForge API approval. Initial development will use Modrinth API for proof-of-concept implementation, with CurseForge integration to follow upon approval.

### Development Phases

- [ ] **Phase 1a**: Basic launcher GUI and modpack creation
- [ ] **Phase 1b**: Mod repository integration (Modrinth/CurseForge)
- [ ] **Phase 1c**: Dependency resolution and conflict detection
- [ ] **Phase 1d**: Forge/NeoForge automation
- [ ] **Phase 2**: Server creation and management
- [ ] **Phase 3**: Advanced features (import/export, cloud backup)

## 🎮 Target Audience

- macOS Minecraft players seeking simplified mod management
- Users frustrated with existing cross-platform launchers not optimized for Mac
- Modpack creators who want streamlined modpack development and sharing
- Casual players who want to try mods without manual file manipulation

## 🤝 Mod Author Respect

This launcher is committed to respecting mod authors' rights and CurseForge's infrastructure:
- All mod downloads link directly to official CDN endpoints
- Respects mod authors' distribution preferences
- Tracks download metrics through official APIs
- Prominently displays mod author information and support links
- No file redistribution or hosting

## 📋 Requirements

- macOS 12.0 or later
- Minecraft: Java Edition (official launcher)
- Microsoft account for authentication
- 4GB+ RAM recommended for modded gameplay
- 10GB+ free storage space

## 🚀 Installation

*Coming soon - launcher is currently in development*

## 📝 License

*To be determined*

## 👤 Author

River - [@riverdev](https://github.com/riverdev)

## 🙏 Acknowledgments

- CurseForge for mod hosting and API access
- Modrinth for open API and mod distribution
- The Minecraft modding community

---

**Note**: This is a personal project currently in active development. Features and specifications are subject to change.
