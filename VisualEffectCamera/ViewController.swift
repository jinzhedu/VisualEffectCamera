//
//  ViewController.swift
//  VisualEffectCamera
//
//  Created by du jinzhe on 2022/4/2.
//

import GPUImage
#if canImport(OpenGL)
import OpenGL.GL3
#endif

#if canImport(OpenGLES)
import OpenGLES
#endif

#if canImport(COpenGLES)
import COpenGLES.gles2
#endif

#if canImport(COpenGL)
import COpenGL
#endif
import UIKit
import CoreImage
import GPUImage
import AVFoundation
import MLImage
import MLKit

class ViewController: UIViewController {
    @IBOutlet weak var renderView: RenderView!
    @IBOutlet weak var filterSwitchView: FiltersSwitchView!
    
    let fbSize = Size(width: 640, height: 480)
    
    var panFaceView: PanFaceView?
    
    lazy var lineGenerator: LineGenerator = {
        let gen = LineGenerator(size: self.fbSize)
        gen.lineWidth = 5
        return gen
    }()
    
    var orangePicture: PictureInput?
    var leftEyeMattingFilter: OriangFaceFilter?
    var rightEyeMattingFilter: OriangFaceFilter?
    var lipMattingFilter: OriangFaceFilter?
    var blendFilter: SourceOverBlend?
    var blendFilter2: SourceOverBlend?
    var blendFilter3: SourceOverBlend?
    var blendFilter4: SourceOverBlend?
    var bulgeFilter: FaceSquareBulge?
    var panFaceFilter: PanFaceFilter?
    
    var selectFilterType = FilterType.none {
        didSet{
            guard selectFilterType != oldValue else {
                return
            }
            
            camera.removeAllTargets()
            leftEyeMattingFilter?.removeAllTargets()
            leftEyeMattingFilter = nil
            rightEyeMattingFilter?.removeAllTargets()
            rightEyeMattingFilter = nil
            lipMattingFilter?.removeAllTargets()
            lipMattingFilter = nil
            blendFilter?.removeAllTargets()
            blendFilter = nil
            blendFilter2?.removeAllTargets()
            blendFilter2 = nil
            blendFilter3?.removeAllTargets()
            blendFilter3 = nil
            blendFilter4?.removeAllTargets()
            blendFilter4 = nil
            lineGenerator.removeAllTargets()
            bulgeFilter?.removeAllTargets()
            bulgeFilter = nil
            
            clearPanFaceFilter()
            
            switch selectFilterType {
            case .orangeFace:
                leftEyeMattingFilter = OriangFaceFilter()
                rightEyeMattingFilter = OriangFaceFilter()
                lipMattingFilter = OriangFaceFilter()
                blendFilter = SourceOverBlend()
                blendFilter2 = SourceOverBlend()
                blendFilter3 = SourceOverBlend()
                blendFilter4 = SourceOverBlend()
                orangePicture = PictureInput(imageName:"istockphoto-185284489-612x612.jpeg")
                orangePicture!.addTarget(blendFilter4!)
                orangePicture!.processImage()
                camera --> leftEyeMattingFilter! --> blendFilter!
                camera --> lipMattingFilter! --> blendFilter2!
                lineGenerator --> blendFilter3!
                camera --> rightEyeMattingFilter! --> blendFilter! --> blendFilter2! --> blendFilter3! --> blendFilter4! --> renderView
            case .squareFace:
                bulgeFilter = FaceSquareBulge()
                camera --> bulgeFilter! --> renderView
            case .panFace:
                setupPanFaceFilter()
            default:
                camera --> renderView
            }
        }
    }
    
    var camera:Camera!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            camera = try Camera(sessionPreset:.vga640x480, location:.frontFacing, captureAsYUV:false)
            camera.runBenchmark = true
            camera.delegate = self
            camera --> renderView
            camera.startCapture()
        } catch {
            fatalError("Could not initialize rendering pipeline: \(error)")
        }
        
        filterSwitchView.filterItems = [FilterItem(type: .none, imageName: "white.png"), FilterItem(type: .orangeFace, imageName: "istockphoto-185284489-612x612.jpeg"), FilterItem(type: .squareFace, imageName: "squareFace.jpeg"), FilterItem(type: .panFace, imageName: "panFace.png")]
        filterSwitchView.actionDelegate = self
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    @IBAction func capture(_ sender: AnyObject) {
        print("Capture")
        do {
            let documentsDir = try FileManager.default.url(for:.documentDirectory, in:.userDomainMask, appropriateFor:nil, create:true)
            //saturationFilter.saveNextFrameToURL(URL(string:"TestImage.png", relativeTo:documentsDir)!, format:.png)
        } catch {
            print("Couldn't save image: \(error)")
        }
    }
}

extension ViewController: CameraDelegate {
    func didCaptureBuffer(_ sampleBuffer: CMSampleBuffer) {
        if(selectFilterType == .none) {
            return
        }
        
        var faces = detectFace(sampleBuffer)
        
        guard !faces.isEmpty else {
            print("On-Device face detector returned no results.")
            
            bulgeFilter?.square = []
            bulgeFilter?.count = 0
            bulgeFilter?.points = []
            
            lineGenerator.renderLines([])
            leftEyeMattingFilter?.imageVertices = []
            leftEyeMattingFilter?.texCords = []
            rightEyeMattingFilter?.imageVertices = []
            rightEyeMattingFilter?.texCords = []
            lipMattingFilter?.imageVertices = []
            lipMattingFilter?.texCords = []
            
            resetPanFaceFilter()
            
            return
        }
        
        switch selectFilterType {
        case .orangeFace:
            configOrangeFaceFilter(faces[0])
        case .squareFace:
            configSquareBulgeFilter(faces[0])
        case .panFace:
            configPanFaceFilter(faces[0])
        default:
            break
        }
    }
    
    func detectFace(_ sampleBuffer: CMSampleBuffer) -> [Face] {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return []
        }
        let visionImage = VisionImage(buffer: sampleBuffer)
        let orientation = UIUtilities.imageOrientation(
            fromDevicePosition: camera.location == .frontFacing ? .front : .back
        )
        visionImage.orientation = .up
        let imageWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
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
          return []
        }
        return faces
    }
    
    func transformToVertexCor() -> CGAffineTransform {
        return CGAffineTransform(translationX: -1, y: -1).scaledBy(x: CGFloat(2/fbSize.height), y: CGFloat(2/fbSize.width))
    }
    
    func transformToTexCor() -> CGAffineTransform {
        return CGAffineTransform(scaleX: CGFloat(1/fbSize.height), y: CGFloat(1/fbSize.width))
    }

    func faceLines(_ bounds: CGRect) -> [Line] {
        let glRect = bounds.applying(transformToVertexCor())

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
    
    func configSquareBulgeFilter(_ face: Face) {
        let glRect = face.frame.applying(transformToTexCor())
        let x = GLfloat(glRect.origin.x)
        let y = GLfloat(glRect.origin.y)
        let width = GLfloat(glRect.size.width)
        let height = GLfloat(glRect.size.height)
        bulgeFilter?.square = [x, y,x + width, y, x, y + height,x + width, y + height]
        
        var points = [GLfloat]()
        if let faceContour = face.contour(ofType: .face) {
            bulgeFilter?.count = faceContour.points.count
            for face in faceContour.points {
                var point = CGPoint(x: face.x, y: face.y)
                point = point.applying(transformToTexCor())
                points.append(GLfloat(point.x))
                points.append(GLfloat(point.y))
            }
            bulgeFilter?.points = points;
        }
    }
    
    func getElementCords(_ eyeContour: FaceContour, translate: CGPoint = CGPoint(x: 0, y: 0)) -> (vertices: [Float], texCord: [Float]) {
        var vertices: [Float] = []
        var texCord: [Float] = []
        
        let vertexTransform = transformToVertexCor()
        
        var i = 0
        var j = eyeContour.points.count - 1
        while i <= j {
          var point = CGPoint(x: eyeContour.points[i].x, y: eyeContour.points[i].y)
          point = point.applying(vertexTransform)
          vertices.append(Float(point.x))
          vertices.append(Float(point.y))
          texCord.append(Float(point.x/2.0 + 0.5))
          texCord.append(Float(point.y/2.0 + 0.5))
          if i == j {
              break
          }
          point = CGPoint(x: eyeContour.points[j].x, y: eyeContour.points[j].y)
          point = point.applying(vertexTransform)
          vertices.append(Float(point.x))
          vertices.append(Float(point.y))
          texCord.append(Float(point.x/2.0 + 0.5))
          texCord.append(Float(point.y/2.0 + 0.5))
          i+=1
          j-=1
        }
        
        return (vertices, texCord)
    }
    
    func getLipCords(_ face: Face) -> (vertices: [Float], texCord: [Float]) {
        var vertices: [Float] = [];
        var texCord: [Float] = [];
        
        let vertexTransform = transformToVertexCor()
        
        if let upper = face.contour(ofType: .upperLipTop), let lower = face.contour(ofType: .lowerLipBottom) {
          var i = 0
          var j = lower.points.count - 1
            while i < upper.points.count && j > -1 {
                var point = CGPoint(x: upper.points[i].x, y: upper.points[i].y)
                point = point.applying(vertexTransform)
                vertices.append(Float(point.x))
                vertices.append(Float(point.y))
                texCord.append(Float(point.x/2.0 + 0.5))
                texCord.append(Float(point.y/2.0 + 0.5))
                
                point = CGPoint(x: lower.points[j].x, y: lower.points[j].y)
                point = point.applying(vertexTransform)
                vertices.append(Float(point.x))
                vertices.append(Float(point.y))
                texCord.append(Float(point.x/2.0 + 0.5))
                texCord.append(Float(point.y/2.0 + 0.5))
                i+=1
                j-=1
            }
        }
        
        return (vertices, texCord)
    }
    
    func configOrangeFaceFilter(_ face: Face) {
        lineGenerator.renderLines(faceLines(face.frame))
        
        if let leftEyeContour = face.contour(ofType: .leftEye) {
            let cords = getElementCords(leftEyeContour)
            leftEyeMattingFilter?.imageVertices = cords.vertices
            leftEyeMattingFilter?.texCords = cords.texCord
        } else {
            leftEyeMattingFilter?.imageVertices = []
            leftEyeMattingFilter?.texCords = []
        }
        
        if let rightEyeContour = face.contour(ofType: .rightEye) {
            let cords = getElementCords(rightEyeContour)
            rightEyeMattingFilter?.imageVertices = cords.vertices
            rightEyeMattingFilter?.texCords = cords.texCord
        } else {
            rightEyeMattingFilter?.imageVertices = []
            rightEyeMattingFilter?.texCords = []
        }
        
        let cords = getLipCords(face)
        lipMattingFilter?.imageVertices = cords.vertices
        lipMattingFilter?.texCords = cords.texCord
    }
}

extension ViewController: FiltersSwitchDelegate {
    func switchTo(filter: FilterType) {
        selectFilterType = filter
    }
}


