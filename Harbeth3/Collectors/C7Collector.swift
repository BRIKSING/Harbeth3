//
//  C7Collector.swift
//  Harbeth
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import CoreVideo
import Harbeth

@objc public protocol C7CollectorImageDelegate: NSObjectProtocol {
    
    /// The filter image is returned in the child thread.
    ///
    /// - Parameters:
    ///   - collector: collector
    ///   - image: fliter image
    func preview(_ collector: C7Collector, fliter image: C7Image)
    
    /// Capture other relevant information. The child thread returns the result.
    /// - Parameters:
    ///   - collector: Collector
    ///   - pixelBuffer: A CVPixelBuffer object containing the video frame data and additional information about the frame, such as its format and presentation time.
    @objc optional func captureOutput(_ collector: C7Collector, pixelBuffer: CVPixelBuffer)
    
    /// Capture CVPixelBuffer converted to MTLTexture.
    /// - Parameters:
    ///   - collector: Collector
    ///   - texture: CVPixelBuffer => MTLTexture
    @objc optional func captureOutput(_ collector: C7Collector, texture: MTLTexture)
}

public class C7Collector: NSObject, Cacheable {
    
    public var filters: [C7FilterProtocol] = []
    public var videoAffineTransform: CGAffineTransform? = nil
    public var videoSettings: [String : Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    /// Whether to enable automatic direction correction of pictures? The default is true.
    public var autoCorrectDirection: Bool = true
    
    weak var delegate: C7CollectorImageDelegate?
    var preferredOrientation: UIImage.Orientation = .up
    
    public required init(delegate: C7CollectorImageDelegate) {
        self.delegate = delegate
        super.init()
        setupInit()
    }
    
    deinit {
        delegate = nil
        deferTextureCache()
        print("C7Collector is deinit.")
    }
    
    open func setupInit() {
        let _ = self.textureCache
    }
}

// MARK: Preparing shot
extension C7Collector {
    public func preparePreferredOrientation(transform: CGAffineTransform?) {
        guard let t = transform else {
            return
        }
        
        var preferredOrientation: UIImage.Orientation = .up
        
        switch (t.a, t.b, t.c, t.d) {
            
        case (1, 0, 0, 1):
            preferredOrientation = .up
            
            // Init video rotated left, rotate it right
            // For Iphone video
        case (0, 1, -1, 0):
            preferredOrientation = .right
            
            // Init video rotated right, rotate it left
            // For GoPro
        case (0, -1, 1, 0):
            preferredOrientation = .left
            
        case (_, _, _, _):
            preferredOrientation = .up
        }
        
        self.preferredOrientation = preferredOrientation
    }
    
    func getWidthForCompressingByDevice() -> Int {
//        if (isIphone6s7() || isIphoneSE() || isIphoneSE2()) {
//            return 1000;
//        }
        
        return 1000;
    }
    
    func getPreferredOrientation() -> UIImage.Orientation {
        return self.preferredOrientation
    }
}

extension C7Collector {
    
    func pixelBuffer2Image(_ pixelBuffer: CVPixelBuffer?) -> C7Image? {
        guard let pixelBuffer = pixelBuffer else {
            return nil
        }
        delegate?.captureOutput?(self, pixelBuffer: pixelBuffer)
        let texture = pixelBuffer.c7.toMTLTexture(textureCache: textureCache)
        let dest = HarbethIO(element: texture, filters: filters)
        guard let texture = try? dest.output() else {
            return nil
        }
        delegate?.captureOutput?(self, texture: texture)
        return texture.c7.toImage()
    }
    
    func processing(with pixelBuffer: CVPixelBuffer?) {
        guard let pixelBuffer = pixelBuffer else {
            return
        }
        
        delegate?.captureOutput?(self, pixelBuffer: pixelBuffer)
        let texture = pixelBuffer.c7.toCGImage()
//        let compressedTexture = createCompressedImage(currentImage: UIImage(cgImage: texture!), widthToCompress: NSNumber(value: getWidthForCompressingByDevice()), ration: NSNumber(value: 2), needLog: false)
//        guard let texture = pixelBuffer.c7.toMTLTexture(textureCache: textureCache) else {
//            return
//        }
//
        let dest = HarbethIO(element: texture, filters: filters)
//        dest.transmitOutputRealTimeCommit = true
//        let desTexture = try? dest.output()
//
//        self.delegate?.captureOutput?(self, texture: desTexture!)
//        guard var image = desTexture!.c7.toImage() else {
//            return
//        }
//        if self.autoCorrectDirection {
//            image = image.c7.fixOrientation()
//        }
//
//        DispatchQueue.main.async {
//            self.delegate?.preview(self, fliter: image)
//        }
        // FIXME: NOT WORKING WITH MULTIPLE FILTERS
        dest.transmitOutput(success: { [weak self] desTexture in
            guard let `self` = self else {
                return
            }
//            self.delegate?.captureOutput?(self, texture: desTexture)
            guard var image = desTexture?.c7.toImage() else {
                return
            }
            if self.autoCorrectDirection {
//                image = image.c7.fixOrientation()
                
                image = UIImage(cgImage: image.cgImage!, scale: 1, orientation: self.preferredOrientation)
            }
            DispatchQueue.main.async {
                self.delegate?.preview(self, fliter: image)
            }
        }, failed: { [weak self] error in
            print(error)
        })
    }
}
