//
//  CustomInstructionProtocol.swift
//  Harbeth3
//
//  Created by Anna Zhikhareva on 25.06.2024.
//

import Foundation
import Kakapos
import AVFoundation

public protocol CustomInstructionProtocol: InstructionProtocol {
    func operationPixelBuffer(sourceBuffer: CVPixelBuffer, destBuffer: CVPixelBuffer, block: @escaping BufferBlock, for request: AVAsynchronousVideoCompositionRequest)
}

public typealias CustomCompositionInstruction = Instruction & CustomInstructionProtocol
