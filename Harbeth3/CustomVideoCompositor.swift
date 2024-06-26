//
//  VideoCompositor.swift
//  KakaposExamples
//
//  Created by Condy on 2022/12/20.
//

import Foundation
import AVFoundation
import CoreVideo
import Kakapos
import Accelerate
import UIKit

final class CustomVideoCompositor: NSObject, AVVideoCompositing {
    
    let renderQueue = DispatchQueue(label: "com.condy.exporter.rendering.queue")
    
    var renderContext: AVVideoCompositionRenderContext?
    var shouldCancelAllRequests = false
    #if os(macOS)
    var sourcePixelBufferAttributes: [String : Any]? = [
        String(kCVPixelBufferPixelFormatTypeKey): [kCVPixelFormatType_32BGRA]
    ]
    var requiredPixelBufferAttributesForRenderContext: [String : Any] = [
        String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA
    ]
    #else
    var sourcePixelBufferAttributes: [String : Any]? = [
        String(kCVPixelBufferPixelFormatTypeKey): [kCVPixelFormatType_32BGRA],
        String(kCVPixelBufferOpenGLESCompatibilityKey): true
    ]
    var requiredPixelBufferAttributesForRenderContext: [String : Any] = [
        String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA,
        String(kCVPixelBufferOpenGLESCompatibilityKey): true
    ]
    #endif
    
    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        autoreleasepool {
            self.renderQueue.async {
                if self.shouldCancelAllRequests {
                    request.finishCancelledRequest()
                } else {
                    guard let instruction = request.videoCompositionInstruction as? CustomCompositionInstruction,
                          let trackID = instruction.trackID,
                          let pixelBuffer = request.sourceFrame(byTrackID: trackID),
                          let outBuffer = self.renderContext?.newPixelBuffer() else {
                        request.finish(with: VideoX.Error.newRenderedPixelBufferForRequestFailure)
                        return
                    }
                    print("rendering... ")
                    // Try to ude HarbethIo to push image in outBuff
                    // request.finish(withComposedVideoFrame: outBuffer)
                    
//                    request.finish(withComposedVideoFrame: self.rotateBuffer(imageBuffer: pixelBuffer, outBuffer: outBuffer))
                    let callback = { buffer in
                        request.finish(withComposedVideoFrame: buffer)
                    }
                    
                    instruction.operationPixelBuffer(sourceBuffer: pixelBuffer, destBuffer: outBuffer, block: callback, for: request)
                }
            }
        }
    }
    
    func rotateBuffer(imageBuffer: CVPixelBuffer, outBuffer: CVPixelBuffer?) -> CVPixelBuffer {
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(outBuffer!, .readOnly)
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let bytesPerRowOut = try! vImage_Buffer.preferredAlignmentAndRowBytes(width: height, height: width, bitsPerPixel: UInt32(kCVPixelFormatType_32BGRA.bitWidth))
        let attrs = [
            String(kCVPixelBufferPixelFormatTypeKey): [kCVPixelFormatType_32BGRA],
            String(kCVPixelBufferOpenGLESCompatibilityKey): true
        ] as CFDictionary
        
        let srcBuff = CVPixelBufferGetBaseAddress(imageBuffer)
        var outBuff: CVPixelBuffer? = nil
        
        // { srcBuff, height, width, bytesPerRow}
        var ibuff = vImage_Buffer(data: srcBuff, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: bytesPerRow)
        // { outBuff, width, height, bytesPerRowOut}
//        var ubuff = vImage_Buffer(data: CVPixelBufferGetBaseAddress(outBuffer), height: vImagePixelCount(width), width: vImagePixelCount(height), rowBytes: bytesPerRowOut.rowBytes)
        var ubuff = try! vImage_Buffer(width: height, height: width, bitsPerPixel: UInt32(kCVPixelFormatType_32BGRA.bitWidth))
        let rotationConst = 1   // 0, 1, 2, 3 is equal to 0, 90, 180, 270 degrees rotation
        var backColor = UInt8()
        
        let err = vImageRotate90_ARGB8888(&ibuff, &ubuff, UInt8(rotationConst), &backColor, vImage_Flags(kvImageNoFlags))
        
        if (err != kvImageNoError) {
            print(err)
        }
        
//        let memoryAddress = CVPixelBufferGetBaseAddress(outBuffer!)!.bindMemory(to: CVPixelBuffer?.self, capacity: MemoryLayout<CVPixelBuffer?>.size)
        
        CVPixelBufferCreateWithBytes(kCFAllocatorDefault, height, width, kCVPixelFormatType_32BGRA, ubuff.data, bytesPerRowOut.rowBytes, nil, nil, attrs, &outBuff)
        
        CVPixelBufferGetBaseAddress(outBuffer!)?.copyMemory(from: CVPixelBufferGetBaseAddress(outBuff!)!, byteCount: MemoryLayout<CVPixelBuffer?>.size)
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
        CVPixelBufferUnlockBaseAddress(outBuffer!, .readOnly)
        
        // Copy data in memory from rotated image (outBuff) to new pixel buffer from Compositor (outBuffer)
//        memcpy(CVPixelBufferGetBaseAddress(outBuffer), CVPixelBufferGetBaseAddress(outBuff!), bytesPerRowOut.rowBytes * Int(ubuff.height))
        
        return outBuffer!
    }
    
    /// Working good with simulators
    func rotateCVBuffer(imageBuffer: CVPixelBuffer) -> CVPixelBuffer {
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let bytesPerRowOut = try! vImage_Buffer.preferredAlignmentAndRowBytes(width: height, height: width, bitsPerPixel: UInt32(kCVPixelFormatType_32BGRA.bitWidth))
        let attrs = [
            String(kCVPixelBufferPixelFormatTypeKey): [kCVPixelFormatType_32BGRA],
            String(kCVPixelBufferOpenGLESCompatibilityKey): true
        ] as CFDictionary
        
        let srcBuff = CVPixelBufferGetBaseAddress(imageBuffer)
        var outBuff: CVPixelBuffer? = nil
        
        // { srcBuff, height, width, bytesPerRow}
        var ibuff = vImage_Buffer(data: srcBuff, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: bytesPerRow)
        // { outBuff, width, height, bytesPerRowOut}
//        var ubuff = vImage_Buffer(data: CVPixelBufferGetBaseAddress(outBuffer), height: vImagePixelCount(width), width: vImagePixelCount(height), rowBytes: bytesPerRowOut.rowBytes)
        var ubuff = try! vImage_Buffer(width: height, height: width, bitsPerPixel: UInt32(kCVPixelFormatType_32BGRA.bitWidth))
        let rotationConst = 1   // 0, 1, 2, 3 is equal to 0, 90, 180, 270 degrees rotation
        var backColor = UInt8()
        
        let err = vImageRotate90_ARGB8888(&ibuff, &ubuff, UInt8(rotationConst), &backColor, vImage_Flags(kvImageNoFlags))
        
        if (err != kvImageNoError) {
            print(err)
        }
        
        CVPixelBufferCreateWithBytes(kCFAllocatorDefault, height, width, kCVPixelFormatType_32BGRA, ubuff.data, bytesPerRowOut.rowBytes, nil, nil, attrs, &outBuff)
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
        
        return outBuff!
    }
    
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        self.renderQueue.sync {
            self.renderContext = newRenderContext
        }
    }
    
    func cancelAllPendingVideoCompositionRequests() {
        self.renderQueue.sync {
            shouldCancelAllRequests = true
        }
        self.renderQueue.async {
            self.shouldCancelAllRequests = false
        }
    }
}
