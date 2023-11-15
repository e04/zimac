//
//  AppDelegate.swift
//  zimac
//
//  Created by a on 2023/11/15.
//

import AVFoundation
import AVFAudio
import Cocoa
import ScreenCaptureKit
import Speech
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, SCStreamDelegate, SCStreamOutput {
    var stream: SCStream!
    var availableContent: SCShareableContent?
    var filter: SCContentFilter?
    let recognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "ja_JP"))!
    var recognitionReq: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    var screen: SCDisplay?
    let resultData = ResultData()
        
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        updateAvailableContent()
        
        let contentView = ContentView(resultData: resultData)

        window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.level = .modalPanel
        window.center()
        window.isOpaque = false
        window.backgroundColor = NSColor.black
        window.backgroundColor = NSColor.init(calibratedHue: 0, saturation: 0, brightness: 0, alpha: 0.5)
        window.titlebarAppearsTransparent = true
        window.setFrameAutosaveName("resultTextWindow")
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
    }
    var window: NSWindow!

    func updateAvailableContent() {
        SFSpeechRecognizer.requestAuthorization { authStatus in }
        
        SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { content, error in
            self.availableContent = content
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        if stream != nil {
            stopRecording()
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    @objc func prepRecord() {
        recognize()
        screen = availableContent!.displays.first
        filter = SCContentFilter(display: screen ?? availableContent!.displays.first!, excludingApplications: [], exceptingWindows: [])
        Task { await record(filter: filter!) }
        self.resultData.text = ""
    }

    func record(filter: SCContentFilter) async {
        let conf = SCStreamConfiguration()
        conf.width = 2
        conf.height = 2

        conf.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale.max)
        conf.capturesAudio = true

        stream = SCStream(filter: filter, configuration: conf, delegate: self)
        do {
            try! stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global())
            try! stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global())
            
            try await stream.startCapture()
        } catch {
            print(error)
            return
        }
    }

    @objc func stopRecording() {
        stopRecognize()

        if stream != nil {
            stream.stopCapture()
        }
        stream = nil
    }
    
    func recognize() {
        if let recognitionTask = self.recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        recognitionReq = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionReq = recognitionReq else {
            return
        }
        recognitionReq.shouldReportPartialResults = true
        
        recognitionTask = recognizer.recognitionTask(with: recognitionReq, resultHandler: { (result, error) in
            if let result = result {
                self.resultData.text = result.bestTranscription.formattedString
            } else if let error = error {
                print(error)
            }
        })
    }
    
    func stopRecognize() {
        recognitionReq?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionReq = nil
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }

        switch outputType {
            case .screen:
                break
            case .audio:
                guard let samples = createPCMBuffer(for: sampleBuffer) else { return }
                recognitionReq!.append(samples)
            @unknown default:
                break
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async {
            self.stream = nil
            self.stopRecording()
        }
    }
}

// https://github.com/Mnpn/Azayaka/blob/main/Azayaka/Processing.swift#L14
func createPCMBuffer(for sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
    try? sampleBuffer.withAudioBufferList { audioBufferList, _ -> AVAudioPCMBuffer? in
        guard let absd = sampleBuffer.formatDescription?.audioStreamBasicDescription else { return nil }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: absd.mSampleRate, channels: absd.mChannelsPerFrame) else { return nil }
        return AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: audioBufferList.unsafePointer)
    }
}
