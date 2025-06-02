# Leonardo AI USB Maker - Master Version

![Leonardo AI USB Maker](https://img.shields.io/badge/Version-1.0.0-blue)
![License](https://img.shields.io/badge/License-MIT-green)

A powerful, self-contained bash script for creating portable Ollama AI environments on USB drives with support for Linux, macOS, and Windows.

## ✨ Features

- **Cross-Platform Support**: Create portable AI environments for Linux, macOS, and Windows
- **Multiple AI Models**: Supports various Ollama models out of the box
- **USB Health Monitoring**: Track drive health and optimize performance
- **Self-Replicating**: Automatically copies itself to the USB for easy sharing
- **User-Friendly Interface**: Intuitive menu system with visual feedback
- **Robust Error Handling**: Comprehensive error checking and recovery
- **Secure**: Includes options for secure erasure and verification

## 🚀 Quick Start

1. **Download** the latest version:
   ```bash
   git clone https://github.com/yourusername/leonardo-ai-usb-maker.git
   cd leonardo-ai-usb-maker
   ```

2. **Make the script executable**:
   ```bash
   chmod +x leonardo_master.sh
   ```

3. **Run with root privileges**:
   ```bash
   sudo ./leonardo_master.sh
   ```

4. **Follow the on-screen instructions** to create your portable AI environment

## 📋 Requirements

- Linux-based system (tested on Ubuntu 20.04+)
- Root/sudo privileges
- USB drive (16GB+ recommended)
- Internet connection (for downloading models)
- Basic command-line knowledge

## 🛠️ Installation

### Prerequisites

Ensure you have the following packages installed:

```bash
sudo apt-get update
sudo apt-get install -y pv curl tar unzip parted dosfstools util-linux coreutils
```

### Basic Installation

1. Download the script:
   ```bash
   curl -L -o leonardo_master.sh https://raw.githubusercontent.com/yourusername/leonardo-ai-usb-maker/main/leonardo_master.sh
   chmod +x leonardo_master.sh
   ```

2. Run the script:
   ```bash
   sudo ./leonardo_master.sh
   ```

## 🎮 Usage

### Main Menu Options

1. **Create NEW Leonardo AI USB Drive**
   - Format a new USB drive and install the AI environment
   - Select from available AI models
   - Choose target operating systems

2. **Manage EXISTING Leonardo AI USB Drive**
   - Add/remove AI models
   - Update existing installations
   - Check drive status

3. **Verify & Repair USB Drive**
   - Check installation integrity
   - Repair common issues
   - Validate file permissions

4. **USB Drive Health Report & Optimizer**
   - View drive health metrics
   - Get optimization recommendations
   - Monitor write cycles

5. **Utility Functions**
   - System requirements check
   - Script updates
   - Backup/restore functionality

### Command-Line Options

```
Usage: leonardo_master.sh [options] <command>

Commands:
  create            Create a new Leonardo AI USB drive
  manage            Manage an existing Leonardo AI USB drive
  verify            Verify and repair a Leonardo AI USB drive
  health            Check USB drive health and optimize
  about             Show information about this script

Options:
  -h, --help        Show this help message and exit
  -v, --version     Show version information and exit
  --verbose         Enable verbose output
  --dry-run         Run without making any changes
  --paranoid        Enable paranoid mode (extra security)
  --usb-device=DEV  Specify the USB device to use
  --model=MODEL     Specify the AI model to install
  --os=OSLIST       Comma-separated list of target OS (linux,mac,win)
```

## 🤖 Supported AI Models

The script supports various Ollama models including:

- `llama3:8b` (default)
- `llama3:70b`
- `mistral:7b`
- `mixtral:8x7b`
- `codellama:7b`
- `codellama:34b`
- `phi3:3.8b`
- `gemma:2b`
- `gemma:7b`
- Custom models (specify by name)

## 🔒 Security Considerations

- The script requires root privileges for disk operations
- All downloaded files are verified using checksums
- Sensitive operations require explicit confirmation
- Paranoid mode adds extra verification steps

## 🛠️ Troubleshooting

### Common Issues

1. **Permission Denied**
   - Run the script with `sudo`
   - Ensure your user has the necessary permissions

2. **USB Device Not Detected**
   - Unplug and reconnect the USB drive
   - Check `dmesg` for detection issues
   - Try a different USB port

3. **Download Failures**
   - Check your internet connection
   - Verify disk space is available
   - Try using a different mirror

### Getting Help

For additional help, please:
1. Check the [Wiki](https://github.com/yourusername/leonardo-ai-usb-maker/wiki)
2. Open an [Issue](https://github.com/yourusername/leonardo-ai-usb-maker/issues)
3. Join our [Discord](https://discord.gg/your-invite-link)

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- The Ollama team for their amazing AI platform
- All contributors who helped test and improve this tool
- The open-source community for inspiration and support

---

💡 **Tip**: For the best experience, use a high-quality USB 3.0+ drive with at least 32GB of storage when working with larger AI models.
