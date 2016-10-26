//
//  MusicCubePlayback.swift
//  MusicCube
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/4/28.
//
//
/*
     File: MusicCubePlayback.h
     File: MusicCubePlayback.m
 Abstract: Defines the audio playback object for the application. The object responds to the OpenAL environment.
  Version: 1.3

 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.

 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.

 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.

 Copyright (C) 2014 Apple Inc. All Rights Reserved.

 */

import UIKit
import OpenAL

typealias ALCcontext = OpaquePointer
typealias ALCdevice = OpaquePointer
import AVFoundation

@objc(MusicCubePlayback)
class MusicCubePlayback: NSObject {
    var _source: ALuint = 0
    var _buffer: ALuint = 0
    var _data: UnsafeMutableRawPointer? = nil
    var _sourceVolume: ALfloat = 0
    
    var playing: Bool = false // Whether the sound is playing or stopped
    var wasInterrupted: Bool = false // Whether playback was interrupted by the system
    var sourcePos: [Float] = [0.0, 0.0, 0.0] { // The coordinates of the sound source
        didSet { didSetSourcePos(oldValue) }
    }
    var listenerPos: [Float] = [0.0, 0.0, 0.0] { // The coordinates of the listener
        didSet { didSetListenerPos(oldValue) }
    }
    var listenerRotation: Float = 0.0 {
        didSet { didSetListenerRotation(oldValue) }
    }
    
    //MARK: Object Init / Maintenance
    
    
    func handleInterruption(_ notification: Notification) {
        let interruptionType = notification.userInfo![AVAudioSessionInterruptionTypeKey]! as! UInt
        
        if interruptionType == AVAudioSessionInterruptionType.began.rawValue {
            // do nothing
            self.teardownOpenAL()
            if playing {
                wasInterrupted = true
                playing = false
            }
        } else if interruptionType == AVAudioSessionInterruptionType.ended.rawValue {
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch let error as NSError { NSLog("Error setting audio session active! %@", error) }
            
            self.initOpenAL()
            if wasInterrupted {
                self.startSound()
                wasInterrupted = false
            }
        }
    }
    
    override init() {
        super.init()
        // initial position of the sound source and
        // initial position and rotation of the listener
        // will be set by the view
        
        // setup our audio session
        let sessionInstance = AVAudioSession.sharedInstance()
        
        // add interruption handler
        NotificationCenter.default.addObserver(self,
            selector: #selector(MusicCubePlayback.handleInterruption(_:)),
            name: NSNotification.Name.AVAudioSessionInterruption,
            object: sessionInstance)
        
        do {
            try sessionInstance.setCategory(AVAudioSessionCategoryAmbient)
        } catch let error as NSError {
            NSLog("Error setting audio session category! %@", error)
        }
        do {
            try sessionInstance.setActive(true)
        } catch let error as NSError {
            NSLog("Error setting audio session active! %@", error)
        }
        
        wasInterrupted = false
        
        // Initialize our OpenAL environment
        self.initOpenAL()
        
    }
    
    deinit {
        
        self.teardownOpenAL()
    }
    
    //MARK: OpenAL
    
    fileprivate func initBuffer() {
        var error = AL_NO_ERROR
        var format: ALenum = 0
        var size: ALsizei = 0
        var freq: ALsizei = 0
        
        let bundle = Bundle.main
        
        // get some audio data from a wave file
        let fileURL = URL(fileURLWithPath: bundle.path(forResource: "sound", ofType: "wav")!)
            
            _data = MyGetOpenALAudioData(fileURL, &size, &format, &freq)
            
            error = alGetError()
            if error != AL_NO_ERROR {
                print("error loading sound: \(String(error, radix: 16))")
                exit(1)
            }
            
            // use the static buffer data API
            alBufferData(_buffer, format, _data, size, freq)
            _data?.deallocate(bytes: Int(size), alignedTo: MemoryLayout<UInt8>.alignment)
            
            error = alGetError()
            if error != AL_NO_ERROR {
                print("error attaching audio to buffer: \(String(error, radix: 16))")
            }
//        } else {
//            print("Could not find file!")
//            _data = nil
//        }
    }
    
    fileprivate func initSource() {
        var error: ALenum = AL_NO_ERROR
        alGetError() // Clear the error
        
        // Turn Looping ON
        alSourcei(_source, AL_LOOPING, AL_TRUE)
        
        // Set Source Position
        alSourcefv(_source, AL_POSITION, &sourcePos)
        
        // Set Source Reference Distance
        alSourcef(_source, AL_REFERENCE_DISTANCE, 0.15)
        
        // attach OpenAL Buffer to OpenAL Source
        alSourcei(_source, AL_BUFFER, _buffer.i)
        
        error = alGetError()
        if error != AL_NO_ERROR {
            print("Error attaching buffer to source: \(String(error, radix: 16))")
            exit(1)
        }
    }
    
    
    func initOpenAL() {
        var error: ALenum = 0
        var newContext: ALCcontext? = nil
        var newDevice: ALCdevice? = nil
        
        // Create a new OpenAL Device
        // Pass NULL to specify the system’s default output device
        newDevice = alcOpenDevice(nil)
        if newDevice != nil {
            // Create a new OpenAL Context
            // The new context will render to the OpenAL Device just created
            newContext = alcCreateContext(newDevice, nil)
            if newContext != nil {
                // Make the new context the Current OpenAL Context
                alcMakeContextCurrent(newContext)
                
                // Create some OpenAL Buffer Objects
                alGenBuffers(1, &_buffer)
                error = alGetError()
                if error != AL_NO_ERROR {
                    print("Error Generating Buffers: \(String(error, radix: 16))")
                    exit(1)
                }
                
                // Create some OpenAL Source Objects
                alGenSources(1, &_source)
                error = alGetError()
                if error != AL_NO_ERROR {
                    print("generating sources! \(String(error, radix: 16))")
                    exit(1)
                }
                
            }
        }
        // clear any errors
        alGetError()
        
        self.initBuffer()
        self.initSource()
    }
    
    func teardownOpenAL() {
        var context: ALCcontext? = nil
        var device: ALCdevice? = nil
        
        // Delete the Sources
        alDeleteSources(1, &_source)
        // Delete the Buffers
        alDeleteBuffers(1, &_buffer)
        
        //Get active context (there can only be one)
        context = alcGetCurrentContext()
        //Get device for active context
        device = alcGetContextsDevice(context)
        //Release context
        alcDestroyContext(context)
        //Close device
        alcCloseDevice(device)
    }
    
    //MARK: Play / Pause
    
    func startSound() {
        
        print("Start!")
        // Begin playing our source file
        alSourcePlay(_source)
        let error = alGetError()
        if error != AL_NO_ERROR {
            print("error starting source: \(String(error, radix: 16))")
        } else {
            // Mark our state as playing
            self.playing = true
        }
    }
    
    func stopSound() {
        
        print("Stop!!")
        // Stop playing our source file
        alSourceStop(_source)
        let error = alGetError()
        if error != AL_NO_ERROR {
            print("error stopping source: \(String(error, radix: 16))")
        } else {
            // Mark our state as not playing
            self.playing = false
        }
    }
    
    //MARK: Setters / Getters
    
    fileprivate func didSetSourcePos(_ SOURCEPOS: [Float]) {
        
        // Move our audio source coordinates
        alSourcefv(_source, AL_POSITION, sourcePos)
    }
    
    
    
    fileprivate func didSetListenerPos(_ LISTENERPOS: [Float]) {
        
        // Move our listener coordinates
        alListenerfv(AL_POSITION, listenerPos)
    }
    
    
    
    fileprivate func didSetListenerRotation(_ radians: Float) {
        let ori: [Float] = [0.0, cos(radians), sin(radians), 1.0, 0.0, 0.0]
        // Set our listener orientation (rotation)
        alListenerfv(AL_ORIENTATION, ori)
    }
    
}
