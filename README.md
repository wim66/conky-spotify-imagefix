# Conky Spotify with Image Fix

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

Spotify Conky with image fix for opaque images.

Conky Spotify ImageFix is an enhanced version of the [original Conky-Spotify](https://github.com/Madh93/conky-spotify) by Madh93. It adds a solution for rendering Spotify album art addressing Conky's compatibility issues with transparent Conky window and images using `transparent-image.lua`, .

## Features
- Displays Spotify album art in Conky.
- Fix for showing album art in a transparent Conky window.
- Compatible with Spotify (with DBus support).

## Requirements
To use this configuration, you need the following tools:
- **Conky**: A lightweight system monitor.
- **ImageMagick**: For album art conversion to a suitable format.
- **Spotify**: With DBus support enabled.

## Why PNG Conversion?
This setup converts Spotify album art from JPG to PNG format using ImageMagick in the `cover.sh` script. The reasons for this conversion are:
- **Reliability**: Conky’s Cairo backend has native support for PNG, ensuring consistent rendering without black backgrounds or artifacts in transparent Conky windows.
- **Compatibility**: The `transparent-image.lua` script is designed to work with PNG images, avoiding the need for complex modifications to support JPG directly.
- **Quality**: PNG uses lossless compression, preserving the visual quality of album art without compression artifacts.
- **Simplicity**: Converting to PNG with ImageMagick is a robust, well-tested solution that integrates seamlessly with the existing Conky-Spotify setup.

## About Conky
Conky is a powerful and flexible system monitor for Linux/BSD systems. It can be customized to display various system statistics, such as CPU usage, memory, network information, and more. With proper configurations like this one, Conky can also display external data, such as Spotify information and album art.

## Installation
1. Clone this repository:
   ```bash
   git clone https://github.com/wim66/conky-spotify-imagefix.git
    ```
   copy conky-spotify to ~/.conky

    Ensure all requirements are installed:
        For Conky: Refer to your distribution's documentation.
        For ImageMagick: Install it via your package manager, e.g.:
        bash

        sudo apt install imagemagick

        Ensure Spotify with DBus support is installed.
    Customize the Conky configuration to your system if needed.

## Useful Links
- [Original Conky-Spotify by Madh93](https://github.com/Madh93/conky-spotify)
- [Conky](https://github.com/brndnmtthws/conky)

License

This project is licensed under the terms of the LICENSE file included in this repository. Please review it for details.
Acknowledgments

Thanks to Madh93 for the original work and inspiration for this configuration.

Enjoy this setup! For questions or issues, feel free to open an issue in this repository.

![Sample conky-spotify](preview.png)