//
//  CustomFilterInstruction.swift
//  Harbeth3
//
//  Created by Anna Zhikhareva on 25.06.2024.
//

import Foundation
import Kakapos
import AVFoundation
import CoreVideo
import Harbeth

class CustomFilterInstruction: CustomCompositionInstruction {
    func operationPixelBuffer(_ buffer: CVPixelBuffer, block: @escaping Kakapos.BufferBlock, for request: AVAsynchronousVideoCompositionRequest) {
        
    }
    
    /// Get the current pixel buffer in real time and give it to the outside world for processing.
    /// - buffer: Current pixel buffer.
    /// - time: Current frame, Start with the minimum time of `ExportSessionTimeRange`.
    /// - block: Asynchronous processing pixel buffer.
    public typealias CustomBufferCallback = (_ sourceBuffer: CVPixelBuffer, _ destBuffer: CVPixelBuffer, _ time: Int64, _ block: @escaping BufferBlock) -> Void
    
    private let callback: CustomBufferCallback
    
    public convenience init(filtering: @escaping (CVPixelBuffer, CVPixelBuffer, @escaping BufferBlock) -> Void) {
        let callback = { (sourceBuffer, destBuffer, _: Int64, block) -> Void in
            filtering(sourceBuffer, destBuffer, block)
        }
        self.init(callback: callback)
    }
    
    public init(callback: @escaping CustomBufferCallback) {
        self.callback = callback
        super.init()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func operationPixelBuffer(sourceBuffer: CVPixelBuffer, destBuffer: CVPixelBuffer, block: @escaping BufferBlock, for request: AVAsynchronousVideoCompositionRequest) {
        let compositionTime = request.compositionTime
        let time = compositionTime.value/Int64(compositionTime.timescale) - Int64(minTime)
        self.callback(sourceBuffer, destBuffer, time, block)
    }
}

extension HarbethIO {
    public func filtering(destPixelBuffer: CVPixelBuffer, complete: @escaping (Result<CVPixelBuffer, HarbethError>) -> Void) {
        do {
            let texture = try TextureLoader(with: element as! CVPixelBuffer).texture
            filtering(texture: texture, complete: { res in
                let ress = res.map {
                    destPixelBuffer.c7.copyToPixelBuffer(with: $0)
                    return destPixelBuffer
                }
                complete(ress)
            })
        } catch {
            complete(.failure(HarbethError.toHarbethError(error)))
        }
    }
}
