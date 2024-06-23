//
//  ViewController.swift
//  Harbeth3
//
//  Created by Anna Zhikhareva on 11.09.2022.
//

import UIKit
import Harbeth
import Kakapos
import Photos

class ViewController: UIViewController, C7CollectorImageDelegate {
    @IBOutlet weak var videoView: UIImageView!
    var picker: UIImagePickerController!
    var saveUrl: URL! = URL.init(string: "https://file-examples.com/storage/fed5266c9966708dcaeaea6/2017/04/file_example_MP4_480_1_5MG.mp4")
    var pickedInfo: [UIImagePickerController.InfoKey : Any]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        PHPhotoLibrary.requestAuthorization { PHAuthorizationStatus in
            
        }
        self.picker = UIImagePickerController()
        self.picker.mediaTypes = ["public.movie"]
        self.picker.allowsEditing = false
        self.picker.videoQuality = .typeHigh
        self.picker.delegate = self
    }

    @IBAction func buttonClicked(_ sender: UIButton) {
        present(self.picker, animated: true)
    }
    
    @IBAction func saveButtonClicked(_ sender: Any) {
        if (self.saveUrl != nil) {
            self.saveVideo(videoUrl: self.saveUrl)
        }
    }
    
    func preview(_ collector: C7Collector, fliter image: Harbeth.C7Image) {
        self.videoView.image = image
    }
    
    func saveVideo(videoUrl: URL) -> Void {
        let outputURL: URL = {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let outputURL = documents.appendingPathComponent("condy_exporter_video.mp4")
            let path = NSURL(fileURLWithPath: NSHomeDirectory() + "/Documents/new_video.mp4" )
            
            // Check if the file already exists then remove the previous file
            if FileManager.default.fileExists(atPath: outputURL.path) {
                do {
                    try FileManager.default.removeItem(at: outputURL)
                } catch {
                    //completionHandler(nil, error)
                }
            }
            return outputURL
        }()
        
        let exporter = VideoX.init(provider: .init(with: videoUrl, to: outputURL))
        var filter2 = C7LookupTable(name: "Lagoon")
        filter2.intensity = 1.0
        var defaultLookupFilter = C7LookupTable(name: "default")
        let filters: [C7FilterProtocol] = [filter2]
        
        let instruction = FilterInstruction { buffer, time, callback in
            print("rendering... ", time)
            let dest = HarbethIO.init(element: buffer, filters: filters)
            
            return dest.transmitOutput(success: callback)
        }
        
        // Working without custom compositor in VideoX
        let layersCallback = { track in
            let t1 = CGAffineTransform(a: 0, b: 1.5, c: 1.5, d: 0, tx: 1080, ty: 0)
            let t2 = CGAffineTransformScale(t1, 1, -1)
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
            layerInstruction.trackID = track.trackID
            layerInstruction.setTransform(t2, at: CMTime.zero)
            
            return [layerInstruction]
        } as (AVCompositionTrack) -> [AVVideoCompositionLayerInstruction]
        let options = [
            VideoX.Option.VideoCompositionRenderSize: CGSize(width: 1080, height: 1920),
            VideoX.Option.VideoCompositionInstructionLayerInstructionsCallback: layersCallback
        ] as [VideoX.Option : Any]
        let startDate = Date()
        
        print("Export Started!")
        exporter.export(options: options, instructions: [instruction], complete: { res in
            print("Export complete! Res: ", res)
            print("Export time: ", Date().timeIntervalSince(startDate))
            
            if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(outputURL.path))
            {
                UISaveVideoAtPathToSavedPhotosAlbum(outputURL.path, nil, #selector(self.savedComplete), nil);
            }
        }, progress: { progress in
            
        })
    }
    
    @objc func savedComplete() {
        print("Saved!")
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        self.picker.dismiss(animated: true)
        self.pickedInfo = info
//        let videoURL = NSURL.init(string: "https://mp4.vjshi.com/2017-06-03/076f1b8201773231ca2f65e38c34033c.mp4")!
//
//        let asset = AVURLAsset.init(url: videoURL as URL)
//        let playerItem = AVPlayerItem(asset: asset)
//        let player = AVPlayer.init(playerItem: playerItem)
        let videoUrl = info[UIImagePickerController.InfoKey.mediaURL] as? NSURL
        let asset = AVAsset(url: videoUrl! as URL)
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer.init(playerItem: playerItem)
        
        let video = C7CollectorVideo.init(player: player, delegate: self)
        
        self.saveUrl = videoUrl?.filePathURL
        
        var filter2 = C7LookupTable(name: "Lagoon")
        filter2.intensity = 1.0
        var defaultLookupFilter = C7LookupTable(name: "default")
        defaultLookupFilter.intensity = 1.0

        video.filters = [defaultLookupFilter]

        video.play()
        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//            video.pause()
//        }
    }
}

