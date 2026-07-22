<p align="center">
  <img
    width="760"
    alt="AskoPDF"
    src="https://github.com/user-attachments/assets/45532307-eeae-4e34-a219-c3234836fe13"
  />
</p>

<p align="center">
  <a href="https://github.com/askoq/askopdf/releases/latest">
    <img
      src="https://img.shields.io/github/v/release/askoq/askopdf?style=for-the-badge&color=007AFF&label=DOWNLOAD%20LATEST"
      alt="Download Latest Version"
    />
  </a>
  <a href="https://github.com/askoq/askopdf/blob/main/LICENSE">
    <img
      src="https://img.shields.io/github/license/askoq/askopdf?style=for-the-badge&color=2EA043"
      alt="License"
    />
  </a>
  <img
    src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white"
    alt="Built with Flutter"
  />
</p>

<p align="center">
  <img
    width="900"
    alt="AskoPDF screenshot"
    src="https://github.com/user-attachments/assets/fb8a2292-8a57-4dd8-84fb-d6d9f5088960"
  />
</p>

---

## About

This repository contains the source code based on version 1.0.0, along with later fixes and improvements.

Supported platforms:

* Windows - x64
* Linux - x64, glibc
* macOS - ARM64, macOS 13+

The required Gelide core and PDFium libraries are already included in the repository, so no additional setup is needed for them

---

## Requirements

To build AskoPDF, you will need:

[Git](https://git-scm.com/downloads) and [Flutter](https://docs.flutter.dev/get-started/install) with desktop support enabled
- The required build tools for your system:
  
  * Windows: Visual Studio with the Desktop development with C++ workload
  * Linux: a C++ compiler and GTK development packages
  * macOS: Xcode with the command-line tools installed

You can check whether Flutter is configured correctly by running:

```bash
flutter doctor
```

If something is missing, the command will show what still needs to be installed or configured

---

## Run from source

Clone the repository:

```bash
git clone https://github.com/askoq/askopdf.git
cd askopdf
```

Install the Flutter dependencies:

```bash
flutter pub get
```

Run the application for your platform:

Windows

```bash
flutter run -d windows
```

Linux

```bash
flutter run -d linux
```

macOS

```bash
flutter run -d macos
```

!! Gelide core and PDFium are stored in the `native-libs/` directory. The build configuration automatically selects and copies the correct libraries for each platform

---

## Build a release

Windows

```bash
flutter build windows --release
```

Linux

```bash
flutter build linux --release
```

macOS

```bash
flutter build macos --release
```

The finished application will be placed in the corresponding platform directory inside `build/`.

---

## License

AskoPDF and the Gelide core binaries included in [`native-libs/`](native-libs/) are licensed under the [Apache License 2.0](LICENSE).

*PDFium is distributed under its own license.*