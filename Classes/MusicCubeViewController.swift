//
//  MusicCubeViewController.swift
//  MusicCube
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/4/29.
//
//
/*
     File: MusicCubeViewController.h
     File: MusicCubeViewController.m
 Abstract: The GLKViewContoller subclass is responsible for OpenGL drawing, updating and displaying the representation of the OpenAL environment and handling user interaction.
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
import GLKit


/*
 In our sound stage, the cube represents an omnidirectional sound source, and the teapot represents a sound listener.
 The four modes in the application shows how the sound volume and balance will change based on the position of the omnidirectional sound source
 and the position and rotation of the listener:
 1. Constant sound
 2. Sound variates corresponding to the listener's position changes relative to the source
 3. Sound variates corresponding to the listener's rotation changes relative to the source
 4. Sound variates corresponding to the listener's position and rotation changes relative to the source
 */

import QuartzCore
import OpenGLES.EAGLDrawable
import OpenGLES.ES2.glext


private let kInnerCircleRadius: GLfloat = 1.0
private let kOuterCircleRadius: GLfloat = 1.1
private let kCircleSegments: GLint = 36

private let kTeapotScale: GLfloat = 1.8
private let kCubeScale: GLfloat = 0.12
private let kButtonScale: GLfloat = 0.1

private let kButtonLeftSpace = 1.2

private func DegreesToRadians(x: GLfloat) -> GLfloat { return (x) * M_PI.f / 180.0 }

func BUFFER_OFFSET(offset: Int) -> UnsafePointer<Void> {
    return UnsafePointer((nil as UnsafePointer<CChar>).advancedBy(offset))
}


struct BaseEffect {
    var effect: GLKBaseEffect? = nil
    var vertexArray: GLuint = 0
    var vertexBuffer: GLuint = 0
    var normalBuffer: GLuint = 0
    
}

// A class extension to declare private methods
@objc(MusicCubeViewController)
class MusicCubeViewController: GLKViewController, UIGestureRecognizerDelegate {
    
    // OpenAL playback is wired up in IB
    @IBOutlet var playback: MusicCubePlayback!
    
    private var innerCircle = BaseEffect()
    private var outerCircle = BaseEffect()
    private var teapot = BaseEffect()
    private var cube: [BaseEffect] = Array(count: 6, repeatedValue: BaseEffect())
    
    private var context: EAGLContext!
    
    private var mode: GLuint = 0
    // teapot
    private var rot: GLfloat = 0.0
    // cube
    private var cubePos: [GLfloat] = [0.0, 0.0, 0.0]
    private var cubeRot: GLfloat = 0.0
    
    private var cubeTexture: GLuint = 0
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        context = EAGLContext(API: .OpenGLES2)
        
        if context == nil || !EAGLContext.setCurrentContext(context) {
            NSLog("Failed to create ES context")
        }
        
        let view = self.view as! GLKView
        view.context = context
        view.drawableDepthFormat = GLKViewDrawableDepthFormat.Format16
        
        mode = 1
        
        glEnable(GL_DEPTH_TEST.ui)
        
        // create base effects for our objects
        self.makeCircle(&innerCircle, withNumOfSegments: kCircleSegments, radius: kInnerCircleRadius)
        self.makeCircle(&outerCircle, withNumOfSegments: kCircleSegments, radius: kOuterCircleRadius)
        self.makeTeapot()
        self.makeCube()
        
        self.setupPlayback()
        
        self.createGestureRecognizers()
    }
    
    private func setupPlayback() {
        // initialize playback
        // the sound source (cube) starts at the center
        (playback.sourcePos[0], playback.sourcePos[1], playback.sourcePos[2]) = (0, 0, 0)
        // the linster (teapot) starts on the left side (in landscape)
        playback.listenerPos[0] = 0
        playback.listenerPos[1] = (kInnerCircleRadius + kOuterCircleRadius) / 2.0
        playback.listenerPos[2] = 0
        // and points to the source (cube)
        playback.listenerRotation = 0
        
        playback.startSound()
    }
    
    //MARK: Create Objects
    
    private func makeCircle(inout circle: BaseEffect, withNumOfSegments segments: GLint, radius: GLfloat) {
        var vertices: [GLfloat] = Array(count: segments.l * 3, repeatedValue: 0)
        var count = 0
        for i in 0.0.f.stride(to: 360.0, by: 360.0/segments.f) {
            vertices[count++] = 0  //x
            vertices[count++] = (cos(DegreesToRadians(GLfloat(i)))*radius);	//y
            vertices[count++] = (sin(DegreesToRadians(GLfloat(i)))*radius);	//z
        }
        
        let effect = GLKBaseEffect()
        effect.useConstantColor = true
        effect.constantColor = GLKVector4Make(0.2, 0.7, 0.2, 1.0)
        
        var vertexArray: GLuint = 0, vertexBuffer: GLuint = 0
        
        glGenVertexArraysOES(1, &vertexArray)
        glBindVertexArrayOES(vertexArray)
        
        glGenBuffers(1, &vertexBuffer)
        glBindBuffer(GL_ARRAY_BUFFER.ui, vertexBuffer)
        glBufferData(GL_ARRAY_BUFFER.ui, segments.l * 3 * sizeof(GLfloat), vertices, GL_STATIC_DRAW.ui)
        
        glEnableVertexAttribArray(GLKVertexAttrib.Position.rawValue.ui)
        glVertexAttribPointer(GLKVertexAttrib.Position.rawValue.ui, 3, GL_FLOAT.ui, false, 0, BUFFER_OFFSET(0))
        
        glBindVertexArrayOES(0)
        
        circle.effect = effect
        circle.vertexArray = vertexArray
        circle.vertexBuffer = vertexBuffer
        circle.normalBuffer = 0
        
    }
    
    private func makeTeapot() {
        let effect = GLKBaseEffect()
        // material
        effect.material.ambientColor = GLKVector4Make(0.4, 0.8, 0.4, 1.0)
        effect.material.diffuseColor = GLKVector4Make(1.0, 1.0, 1.0, 1.0)
        effect.material.specularColor = GLKVector4Make(1.0, 1.0, 1.0, 1.0)
        effect.material.shininess = 100.0
        // light0
        effect.light0.enabled = true
        effect.light0.ambientColor = GLKVector4Make(0.2, 0.2, 0.2, 1.0)
        effect.light0.diffuseColor = GLKVector4Make(0.2, 0.7, 0.2, 1.0)
        effect.light0.position = GLKVector4Make(0.0, 0.0, 1.0, 0.0)
        
        var vertexArray: GLuint = 0, vertexBuffer: GLuint = 0, normalBuffer: GLuint = 0
        
        glGenVertexArraysOES(1, &vertexArray)
        glBindVertexArrayOES(vertexArray)
        
        // position
        glGenBuffers(1, &vertexBuffer)
        glBindBuffer(GL_ARRAY_BUFFER.ui, vertexBuffer)
        glBufferData(GL_ARRAY_BUFFER.ui, teapot_vertices.count * sizeof(GLfloat), teapot_vertices, GL_STATIC_DRAW.ui)
        
        glEnableVertexAttribArray(GLKVertexAttrib.Position.rawValue.ui)
        glVertexAttribPointer(GLKVertexAttrib.Position.rawValue.ui, 3, GL_FLOAT.ui, false, 0, BUFFER_OFFSET(0))
        
        // normal
        glGenBuffers(1, &normalBuffer)
        glBindBuffer(GL_ARRAY_BUFFER.ui, normalBuffer)
        glBufferData(GL_ARRAY_BUFFER.ui, teapot_normals.count * sizeof(GLfloat), teapot_normals, GL_STATIC_DRAW.ui)
        
        glEnableVertexAttribArray(GLKVertexAttrib.Normal.rawValue.ui)
        glVertexAttribPointer(GLKVertexAttrib.Normal.rawValue.ui, 3, GL_FLOAT.ui, false, 0, BUFFER_OFFSET(0))
        
        glBindVertexArrayOES(0)
        
        teapot.effect = effect
        teapot.vertexArray = vertexArray
        teapot.vertexBuffer = vertexBuffer
        teapot.normalBuffer = normalBuffer
        
    }
    
    private func makeCube() {
        // simple cube data
        // our sound source is omnidirectional, adjust the vertices
        // so that speakers in the textures point to all different directions
        let cubeVertices: [[GLshort]] = [
            //position3 texcoord2
            [ 1,-1, 1, 1, 0,   -1,-1, 1, 1, 1,   1, 1, 1, 0, 0,  -1, 1, 1, 0, 1 ],
            [ 1, 1, 1, 1, 0,    1,-1, 1, 1, 1,   1, 1,-1, 0, 0,   1,-1,-1, 0, 1 ],
            [-1, 1,-1, 1, 0,   -1,-1,-1, 1, 1,  -1, 1, 1, 0, 0,  -1,-1, 1, 0, 1 ],
            [ 1, 1, 1, 1, 0,   -1, 1, 1, 1, 1,   1, 1,-1, 0, 0,  -1, 1,-1, 0, 1 ],
            [ 1,-1,-1, 1, 0,   -1,-1,-1, 1, 1,   1, 1,-1, 0, 0,  -1, 1,-1, 0, 1 ],
            [ 1,-1, 1, 1, 0,   -1,-1, 1, 1, 1,   1,-1,-1, 0, 0,  -1,-1,-1, 0, 1 ],
        ]
        
        let cubeColors: [[Float]] = [
            [1, 0, 0, 1], [0, 1, 0, 1], [0, 0, 1, 1], [1, 1, 0, 1], [0, 1, 1, 1], [1, 0, 1, 1],
        ]
        
        for f in 0..<6 {
            let effect = GLKBaseEffect()
            // texture
            effect.texture2d0.enabled = true
            // texture name is set later
            // tint color
            effect.useConstantColor = true
            effect.constantColor = GLKVector4Make(cubeColors[f][0], cubeColors[f][1], cubeColors[f][2], cubeColors[f][3])
            
            var vertexArray: GLuint = 0, vertexBuffer: GLuint = 0
            
            glGenVertexArraysOES(1, &vertexArray)
            glBindVertexArrayOES(vertexArray)
            
            glGenBuffers(1, &vertexBuffer)
            glBindBuffer(GL_ARRAY_BUFFER.ui, vertexBuffer)
            glBufferData(GL_ARRAY_BUFFER.ui, cubeVertices[f].count * sizeof(GLfloat), cubeVertices[f], GL_STATIC_DRAW.ui)
            
            // position
            glEnableVertexAttribArray(GLKVertexAttrib.Position.rawValue.ui)
            glVertexAttribPointer(GLKVertexAttrib.Position.rawValue.ui, 3, GL_SHORT.ui, false, 10, BUFFER_OFFSET(0))
            // texture cooridnates
            glEnableVertexAttribArray(GLKVertexAttrib.TexCoord0.rawValue.ui)
            glVertexAttribPointer(GLKVertexAttrib.TexCoord0.rawValue.ui, 2, GL_SHORT.ui, false, 10, BUFFER_OFFSET(6))
            
            glBindVertexArrayOES(0)
            
            cube[f].effect = effect
            cube[f].vertexArray = vertexArray
            cube[f].vertexBuffer = vertexBuffer
            cube[f].normalBuffer = 0
            
        }
        
        let image = UIImage(named: "speaker.png")!
        let textureloader = GLKTextureLoader(sharegroup: context.sharegroup)
        textureloader.textureWithCGImage(image.CGImage!, options: nil, queue: nil) {textureInfo, error in
            
            if error != nil {
                NSLog("Error loading texture %@",error!)
            } else {
                for f in 0..<6 {
                    self.cube[f].effect!.texture2d0.name = textureInfo!.name
                }
                
                self.cubeTexture = textureInfo!.name
            }
        }
    }
    
    //MARK: Draw
    
    private func drawTeapotAndUpdatePlayback() {
        
        rot -= 1.0
        let radius: GLfloat = (kOuterCircleRadius + kInnerCircleRadius) / 2.0
        let teapotPos: [GLfloat] = [0.0, cos(DegreesToRadians(rot))*radius, sin(DegreesToRadians(rot))*radius]
        
        // move clockwise along the circle
        var modelView = GLKMatrix4MakeTranslation(teapotPos[0], teapotPos[1], teapotPos[2])
        modelView = GLKMatrix4Scale(modelView, kTeapotScale, kTeapotScale, kTeapotScale)
        
        // add rotation
        var rotYInRadians: GLfloat
        if mode == 2 || mode == 4 {
            // in mode 2 and 4, the teapot (listener) always faces to one direction
            rotYInRadians = 0.0
        } else {
            // in mode 1 and 3, the teapot (listener) always faces to the cube (sound source)
            rotYInRadians = atan2(teapotPos[2]-cubePos[2], teapotPos[1]-cubePos[1])
        }
        
        modelView = GLKMatrix4Rotate(modelView, -M_PI_2.f, 0, 0, 1) //we want to display in landscape mode
        modelView = GLKMatrix4Rotate(modelView, rotYInRadians, 0, 1, 0)
        
        teapot.effect!.transform.modelviewMatrix = modelView
        
        // draw the teapot
        glBindVertexArrayOES(teapot.vertexArray)
        teapot.effect!.prepareToDraw()
        
        for teapot_indices in new_teapot_indicies {
            let arr: [GLshort] = teapot_indices
            glDrawElements(GL_TRIANGLE_STRIP.ui, teapot_indices.count.i, GL_UNSIGNED_SHORT.ui, arr)
        }
        
        
        // update playback
        playback.listenerPos = teapotPos //listener's position
        playback.listenerRotation = rotYInRadians - M_PI.f //listener's rotation in Radians
    }
    
    private func drawCube() {
        cubeRot += 3
        
        var modelView = GLKMatrix4MakeTranslation(cubePos[0], cubePos[1], cubePos[2])
        modelView = GLKMatrix4Scale(modelView, kCubeScale, kCubeScale, kCubeScale)
        
        if mode <= 2 {
            // origin of the teapot is at its bottom, but
            // origin of the cube is at its center, so move up a unit to put the cube on surface
            // we'll pass the bottom of the cube (cubePos) to the playback
            modelView = GLKMatrix4Translate(modelView, 1.0, 0.0, 0.0)
        } else {
            // in mode 3 and 4, simply move up the cube a bit more to avoid colliding with the teapot
            modelView = GLKMatrix4Translate(modelView, 4.5, 0.0, 0.0)
        }
        
        // rotate around to simulate the omnidirectional effect
        modelView = GLKMatrix4Rotate(modelView, DegreesToRadians(cubeRot), 1, 0, 0)
        modelView = GLKMatrix4Rotate(modelView, DegreesToRadians(cubeRot), 0, 1, 1)
        
        for f in 0..<6 {
            cube[f].effect!.transform.modelviewMatrix = modelView
            
            glBindVertexArrayOES(cube[f].vertexArray)
            cube[f].effect!.prepareToDraw()
            glDrawArrays(GL_TRIANGLE_STRIP.ui, 0, 4)
        }
    }
    
    //MARK: - GLKView and GLKViewController delegate methods
    
    override func glkView(view: GLKView, drawInRect rect: CGRect) {
        glClearColor(0.0, 0.0, 0.0, 1.0)
        glClearDepthf(1.0)
        glClear(GL_COLOR_BUFFER_BIT.ui | GL_DEPTH_BUFFER_BIT.ui)
        
        let aspectRatio = GLfloat(view.drawableWidth) / GLfloat(view.drawableHeight)
        var projectionMatrix = GLKMatrix4MakeOrtho(-1.0, 1.0, -1.0/aspectRatio, 1.0/aspectRatio, -10.0, 10.0)
        // rotate the camara for a better view
        projectionMatrix = GLKMatrix4Rotate(projectionMatrix, DegreesToRadians(-30.0), 0.0, 1.0, 0.0)
        
        // set the projection matrix
        innerCircle.effect!.transform.projectionMatrix = projectionMatrix
        outerCircle.effect!.transform.projectionMatrix = projectionMatrix
        teapot.effect!.transform.projectionMatrix = projectionMatrix
        for f in 0..<6 {
            cube[f].effect!.transform.projectionMatrix = projectionMatrix
        }
        
        glBindVertexArrayOES(innerCircle.vertexArray)
        innerCircle.effect!.prepareToDraw()
        glDrawArrays(GL_LINE_LOOP.ui, 0, kCircleSegments)
        
        glBindVertexArrayOES(outerCircle.vertexArray)
        outerCircle.effect!.prepareToDraw()
        glDrawArrays(GL_LINE_LOOP.ui, 0, kCircleSegments)
        
        self.drawTeapotAndUpdatePlayback()
        
        self.drawCube()
    }
    
    private func deleteBaseEffect(var e: BaseEffect) {
        if e.vertexBuffer != 0 {
            glDeleteBuffers(1, &e.vertexBuffer)
        }
        if e.normalBuffer != 0 {
            glDeleteBuffers(1, &e.normalBuffer)
        }
        if e.vertexArray != 0 {
            glDeleteVertexArraysOES(1, &e.vertexArray)
        }
        e.effect = nil
    }
    
    deinit {
        
        playback.stopSound()
        
        self.deleteBaseEffect(innerCircle)
        self.deleteBaseEffect(outerCircle)
        self.deleteBaseEffect(teapot)
        
        glDeleteTextures(1, &cubeTexture)
        
        if EAGLContext.currentContext() == context {
            EAGLContext.setCurrentContext(nil)
        }
        
    }
    
    //MARK: - Gesture Recognizers
    
    private func createGestureRecognizers() {
        // Create a single tap recognizer and add it to the view
        let recognizer = UITapGestureRecognizer(target: self, action: "handleSingleTapFrom:")
        recognizer.delegate = self
        self.view.addGestureRecognizer(recognizer)
    }
    
    @IBAction func handleSingleTapFrom(_: UIGestureRecognizer) {
        mode++
        if mode > 4 { mode = 1 }
        
        // update the position of the cube (sound source)
        // in mode 1 and 2, the teapot (sound source) is at the center of the sound stage
        // in mode 3 and 4, the teapot (sound source) is on the left side
        if mode <= 2 {
            (cubePos[0], cubePos[1], cubePos[2]) = (0, 0, 0)
        } else {
            cubePos[0] = 0
            cubePos[1] = (kInnerCircleRadius + kOuterCircleRadius) / 2.0
            cubePos[2] = 0
        }
        
        // update playback
        playback.sourcePos = cubePos //sound source's position
    }
    
}