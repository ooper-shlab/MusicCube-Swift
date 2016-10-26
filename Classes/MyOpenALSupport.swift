//
//  MyOpenALSupport.swift
//  MusicCube
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/4/28.
//
//
/*
     File: MyOpenALSupport.h
 Abstract: Provides helper functions for various common OpenAL-related tasks (opening files for data read, creating devices and context objects, etc.)
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

import OpenAL
import AudioToolbox

func TestAudioFormatNativeEndian(_ f: AudioStreamBasicDescription) -> Bool {
    return ((f.mFormatID == kAudioFormatLinearPCM)
        && ((f.mFormatFlags & kAudioFormatFlagIsBigEndian) == kAudioFormatFlagsNativeEndian)
    )
}
//### alBufferDataStaticProc() removed.

func MyGetOpenALAudioData(_ inFileURL: URL, _ outDataSize: inout ALsizei, _ outDataFormat: inout ALenum, _ outSampleRate: inout ALsizei) -> UnsafeMutableRawPointer? {
    var err = noErr
    var fileDataSize: UInt64 = 0
    var theFileFormat: AudioStreamBasicDescription = AudioStreamBasicDescription()
    var thePropertySize = UInt32(MemoryLayout.stride(ofValue: theFileFormat))
    var afid: AudioFileID? = nil
    var theData: UnsafeMutableRawPointer? = nil

    Exit: do {
	// Open a file with ExtAudioFileOpen()
        err = AudioFileOpenURL(inFileURL as CFURL, .readPermission, 0, &afid)
        guard err == 0, let afid = afid  else {
            print("MyGetOpenALAudioData: AudioFileOpenURL FAILED, Error = \(err)"); break Exit
        }

	// Get the audio data format
        err = AudioFileGetProperty(afid, kAudioFilePropertyDataFormat, &thePropertySize, &theFileFormat)
        if err != 0 {print("MyGetOpenALAudioData: AudioFileGetProperty(kAudioFileProperty_DataFormat) FAILED, Error = \(err)"); break Exit}

        if theFileFormat.mChannelsPerFrame > 2 {
            print("MyGetOpenALAudioData - Unsupported Format, channel count is greater than stereo")
            break Exit
        }

        if ((theFileFormat.mFormatID != kAudioFormatLinearPCM) || (!TestAudioFormatNativeEndian(theFileFormat))) {
            print("MyGetOpenALAudioData - Unsupported Format, must be little-endian PCM")
            break Exit
        }

        if ((theFileFormat.mBitsPerChannel != 8) && (theFileFormat.mBitsPerChannel != 16)) {
            print("MyGetOpenALAudioData - Unsupported Format, must be 8 or 16 bit PCM")
            break Exit
        }


        thePropertySize = MemoryLayout.size(ofValue: fileDataSize).ui
        err = AudioFileGetProperty(afid, kAudioFilePropertyAudioDataByteCount, &thePropertySize, &fileDataSize)
        if err != 0 {print("MyGetOpenALAudioData: AudioFileGetProperty(kAudioFilePropertyAudioDataByteCount) FAILED, Error = \(err)"); break Exit}

	// Read all the data into memory
        var dataSize = UInt32(fileDataSize)
        theData = UnsafeMutableRawPointer.allocate(bytes: Int(dataSize), alignedTo: MemoryLayout<UInt8>.alignment)
        err = AudioFileReadBytes(afid, false, 0, &dataSize, theData!)
        if err == noErr {
            outDataSize = ALsizei(dataSize)
            outDataFormat = theFileFormat.mChannelsPerFrame > 1 ? AL_FORMAT_STEREO16 : AL_FORMAT_MONO16
            outSampleRate = ALsizei(theFileFormat.mSampleRate)
        } else {
			// failure
            theData?.deallocate(bytes: Int(dataSize), alignedTo: MemoryLayout<UInt8>.alignment)
            theData = nil // make sure to return NULL
            print("MyGetOpenALAudioData: ExtAudioFileRead FAILED, Error = \(err)")
            break Exit
        }

    }
	// Dispose the ExtAudioFileRef, it is no longer needed
    if let afid = afid {AudioFileClose(afid)}
    return theData
}

//void TeardownOpenAL()
//{
//    ALCcontext	*context = NULL;
//    ALCdevice	*device = NULL;
//	ALuint		returnedName;
//
//	// Delete the Sources
//    alDeleteSources(1, &returnedName);
//	// Delete the Buffers
//    alDeleteBuffers(1, &returnedName);
//
//	//Get active context
//    context = alcGetCurrentContext();
//    //Get device for active context
//    device = alcGetContextsDevice(context);
//    //Release context
//    alcDestroyContext(context);
//    //Close device
//    alcCloseDevice(device);
//}

