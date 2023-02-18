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

class ViewController: UIViewController {
    @IBOutlet weak var videoView: UIImageView!
    var picker: UIImagePickerController!
    var saveUrl: URL!
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
        
        let exporter = Exporter.init(videoURL: videoUrl as URL, delegate: self)
        var filter2 = C7LookupTable(name: "Lagoon")
        filter2.intensity = 1.0
        var defaultLookupFilter = C7LookupTable(name: "default")
        let filters: [C7FilterProtocol] = []
        
        exporter.export(outputURL: outputURL) {
            let dest = BoxxIO(element: $0, filters: filters)
            
            return try? dest.output()
        }
    }
}

extension ViewController: ExporterDelegate {
    func export(_ exporter: Kakapos.Exporter, success videoURL: URL) {
        NSLog("%@", "Saved to Docs!")
//        var isAccessing = videoURL.startAccessingSecurityScopedResource()
        var path = videoURL.path
        // /var/mobile/Containers/Data/Application/1DE0661A-C716-4461-A1E1-032B50190EA8/Documents/NewMovie.mov
        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(path))
        {
            UISaveVideoAtPathToSavedPhotosAlbum(path, self, #selector(video(videoPath:error:contextInfo:)), nil);
        }
        
//        videoURL.stopAccessingSecurityScopedResource()
    }
    
    func export(_ exporter: Kakapos.Exporter, failed error: Kakapos.Exporter.Error) {
        NSLog("%@: %@", "Error", error.localizedDescription)
    }
    
    @objc func video(videoPath: NSString, error: NSError, contextInfo: () -> Void) {
        NSLog("%@: %@", "Error while saving in library: ", error.localizedDescription)
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
        
        let video = C7CollectorVideo.init(player: player) { [unowned self] in
            let image = UIImage(cgImage: $0.cgImage!, scale: 1, orientation: .right)
            
            self.videoView.image = image
        }
        
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

