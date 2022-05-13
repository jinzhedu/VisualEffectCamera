//
//  ViewController.swift
//  VisualEffectCamera
//
//  Created by du jinzhe on 2022/4/2.
//

import UIKit
import CoreImage
import GPUImage
import AVFoundation
import MLImage
import MLKit

class ViewController: UIViewController {
    @IBOutlet weak var renderView: RenderView!
    
    let fbSize = Size(width: 640, height: 480)
    let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyLow])
    var shouldDetectFaces = true
    lazy var lineGenerator: LineGenerator = {
        let gen = LineGenerator(size: self.fbSize)
        gen.lineWidth = 5
        return gen
    }()
    //let saturationFilter = SaturationAdjustment()
    let saturationFilter = OriangFaceFilter()
    let saturationFilter2 = OriangFaceFilter()
    let saturationFilter3 = OriangFaceFilter()
    let blendFilter = SourceOverBlend()
    let blendFilter2 = SourceOverBlend()
    let blendFilter3 = SourceOverBlend()
    let blendFilter4 = SourceOverBlend()
    var camera:Camera!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            camera = try Camera(sessionPreset:.vga640x480, location:.frontFacing, captureAsYUV:false)
            camera.runBenchmark = true
            camera.delegate = self
            let blendImage = PictureInput(imageName:"istockphoto-185284489-612x612.jpeg")
            blendImage.addTarget(blendFilter3)
            blendImage.processImage()
            camera --> saturationFilter --> blendFilter --> blendFilter4 --> blendFilter2 --> blendFilter3 --> renderView
            camera --> saturationFilter2 --> blendFilter
            camera --> saturationFilter3 --> blendFilter4
            lineGenerator --> blendFilter2
            //shouldDetectFaces = faceDetectSwitch.isOn
            camera.startCapture()
        } catch {
            fatalError("Could not initialize rendering pipeline: \(error)")
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    @IBAction func didSwitch(_ sender: UISwitch) {
        shouldDetectFaces = sender.isOn
    }

    @IBAction func capture(_ sender: AnyObject) {
        print("Capture")
        do {
            let documentsDir = try FileManager.default.url(for:.documentDirectory, in:.userDomainMask, appropriateFor:nil, create:true)
            saturationFilter.saveNextFrameToURL(URL(string:"TestImage.png", relativeTo:documentsDir)!, format:.png)
        } catch {
            print("Couldn't save image: \(error)")
        }
    }
}

extension ViewController: CameraDelegate {
    func didCaptureBuffer(_ sampleBuffer: CMSampleBuffer) {
//        guard shouldDetectFaces else {
//            lineGenerator.renderLines([]) // clear
//            return
//        }
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let visionImage = VisionImage(buffer: sampleBuffer)
            let orientation = UIUtilities.imageOrientation(
                fromDevicePosition: camera.location == .frontFacing ? .front : .back
            )
            visionImage.orientation = .up
            let imageWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
            let imageHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
//            let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, CMAttachmentMode(kCMAttachmentMode_ShouldPropagate))!
//            let img = CIImage(cvPixelBuffer: pixelBuffer, options: attachments as? [String: AnyObject])
            
            let options = FaceDetectorOptions()
            options.landmarkMode = .none
            options.contourMode = .all
            options.classificationMode = .none
            options.performanceMode = .fast
            let faceDetector = FaceDetector.faceDetector(options: options)
            var faces: [Face]
            do {
              faces = try faceDetector.results(in: visionImage)
            } catch let error {
              print("Failed to detect faces with error: \(error.localizedDescription).")
              lineGenerator.renderLines([])
              return
            }
            guard !faces.isEmpty else {
              print("On-Device face detector returned no results.")
              lineGenerator.renderLines([])
              return
            }
            var lines = [Line]()
            for face in faces {
                lines = lines + faceLines(face.frame)
                var vertices: [Float] = [];
                var texCord: [Float] = [];
                let flip = CGAffineTransform(translationX: -1, y: -1).scaledBy(x: CGFloat(2/fbSize.height), y: CGFloat(2/fbSize.width))
                if let leftEyeContour = face.contour(ofType: .leftEye) {
                  var i = 0
                  var j = leftEyeContour.points.count - 1
                    while i <= j {
                        var point = CGPoint(x: leftEyeContour.points[i].x, y: leftEyeContour.points[i].y)
                        point = point.applying(flip)
                        vertices.append(Float(point.x))
                        vertices.append(Float(point.y))
                        texCord.append(Float(point.x/2.0 + 0.5))
                        texCord.append(Float(point.y/2.0 + 0.5))
                        if i == j {
                            break
                        }
                        point = CGPoint(x: leftEyeContour.points[j].x, y: leftEyeContour.points[j].y)
                        point = point.applying(flip)
                        vertices.append(Float(point.x))
                        vertices.append(Float(point.y))
                        texCord.append(Float(point.x/2.0 + 0.5))
                        texCord.append(Float(point.y/2.0 + 0.5))
                        i+=1
                        j-=1
                    }
                }
                saturationFilter.imageVertices = vertices;
                saturationFilter.texCords = texCord;
                
                vertices = [];
                texCord = [];
                if let rightEyeContour = face.contour(ofType: .rightEye) {
                  var i = 0
                  var j = rightEyeContour.points.count - 1
                    while i <= j {
                        var point = CGPoint(x: rightEyeContour.points[i].x, y: rightEyeContour.points[i].y)
                        point = point.applying(flip)
                        vertices.append(Float(point.x))
                        vertices.append(Float(point.y))
                        texCord.append(Float(point.x/2.0 + 0.5))
                        texCord.append(Float(point.y/2.0 + 0.5))
                        if i == j {
                            break
                        }
                        point = CGPoint(x: rightEyeContour.points[j].x, y: rightEyeContour.points[j].y)
                        point = point.applying(flip)
                        vertices.append(Float(point.x))
                        vertices.append(Float(point.y))
                        texCord.append(Float(point.x/2.0 + 0.5))
                        texCord.append(Float(point.y/2.0 + 0.5))
                        i+=1
                        j-=1
                    }
                }
                saturationFilter2.imageVertices = vertices;
                saturationFilter2.texCords = texCord;
                
                vertices = [];
                texCord = [];
                if let upper = face.contour(ofType: .upperLipTop), let lower = face.contour(ofType: .lowerLipBottom) {
                  var i = 0
                  var j = lower.points.count - 1
                    while i < upper.points.count && j > -1 {
                        var point = CGPoint(x: upper.points[i].x, y: upper.points[i].y)
                        point = point.applying(flip)
                        vertices.append(Float(point.x))
                        vertices.append(Float(point.y))
                        texCord.append(Float(point.x/2.0 + 0.5))
                        texCord.append(Float(point.y/2.0 + 0.5))
                        
                        point = CGPoint(x: lower.points[j].x, y: lower.points[j].y)
                        point = point.applying(flip)
                        vertices.append(Float(point.x))
                        vertices.append(Float(point.y))
                        texCord.append(Float(point.x/2.0 + 0.5))
                        texCord.append(Float(point.y/2.0 + 0.5))
                        i+=1
                        j-=1
                    }
                }
                saturationFilter3.imageVertices = vertices;
                saturationFilter3.texCords = texCord;
            }
            
//            var lines = [Line]()
//            for feature in (faceDetector?.features(in: img, options: [CIDetectorImageOrientation: 6]))! {
//                if feature is CIFaceFeature {
//                    lines = lines + faceLines(feature.bounds)
//                }
//            }
            lineGenerator.renderLines(lines)
        }
    }

    func faceLines(_ bounds: CGRect) -> [Line] {
        // convert from CoreImage to GL coords
//        let flip = CGAffineTransform(scaleX: 1, y: -1)
//        let rotate = flip.rotated(by: CGFloat(-.pi / 2.0))
//        let translate = rotate.translatedBy(x: -1, y: -1)
//        let xform = translate.scaledBy(x: CGFloat(2/fbSize.width), y: CGFloat(2/fbSize.height))
        
        let flip = CGAffineTransform(scaleX: 1, y: 1)
//        let rotate = flip.rotated(by: CGFloat(-.pi / 2.0))
        let translate = flip.translatedBy(x: -1, y: -1)
        let xform = translate.scaledBy(x: CGFloat(2/fbSize.width), y: CGFloat(2/fbSize.height))
        let glRect = bounds.applying(translate.scaledBy(x: CGFloat(2/fbSize.height), y: CGFloat(2/fbSize.width)).translatedBy(x: -1, y: -1))

        let x = Float(glRect.origin.x)
        let y = Float(glRect.origin.y)
        let width = Float(glRect.size.width)
        let height = Float(glRect.size.height)

        let tl = Position(x, y)
        let tr = Position(x + width, y)
        let bl = Position(x, y + height)
        let br = Position(x + width, y + height)

        return [.segment(p1:tl, p2:tr),   // top
                .segment(p1:tr, p2:br),   // right
                .segment(p1:br, p2:bl),   // bottom
                .segment(p1:bl, p2:tl)]   // left
    }
}

