# Miles – A Flutter app for Brilliant Labs Frame

Welcome to the Miles app repository! Built using Flutter, for the Brilliant Labs Frame device.

![1](https://github.com/user-attachments/assets/8e7d27ee-b2ba-42d6-b9a9-5b4ae4f57438)
![2](https://github.com/user-attachments/assets/2d60f14d-d574-414c-a506-ec8d631b6fe7)


## Features
1. 3d Model with connection status and battery
2. Notes functionality
3. Live transcription on notes using Deepgram
4. Tune the base Miles prompt to suit your needs
5. Built in App Store with apps for Weather, Notes, Web searching, Perplexity, Pushover notifications and more
6. Apps integrate directly with Miles AI
7. Heads Up Display (Dashboard). Calibrate your Looking Forward and Looking Up positions and customise when the Heads Up Display is shown.
8. Interrupt (cancel listening) that allows you to cancel current interaction

## Work in progress
1. Live navigation
2. Wake word detection (Option to select between tap to speak and wake word)
3. Voice activity detection (to revert back to idle state if no voice activity detected - right now attempts to pass through STT even if no words are spoken)
4. Live subtitles (hearing impared funcitonality)
5. Live translation

## This is a BETA app and may have some bugs. Please feel welcome to fork and create a pull request for any new functionality / bug fixes.

## Getting started

1. Ensure you have XCode and/or Android studio correctly set up for app development

2. Install [Flutter](https://docs.flutter.dev/get-started/install) for VSCode

3. Clone this repository

    ```sh
    git clone https://github.com:ambrosecoulter/brilliantlabsframe-miles.git
    cd brilliantlabsframe-miles-main
    ```

4. Get the required packages

    ```sh
    flutter pub get
    ```
5. Open Xcode and update the app identifier and signing
   
7. Connect your phone and run the app in release mode

    ```sh
    flutter run --release
    ```

8. App requires both OpenAI and Deepgram API keys on setup
