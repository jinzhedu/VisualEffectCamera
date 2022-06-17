//
//  ViewController+PanFaceFilter.swift
//  VisualEffectCamera
//
//  Created by du jinzhe on 2022/6/15.
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

extension ViewController {
    
    func clearPanFaceFilter() {
        panFaceFilter?.removeAllTargets()
        panFaceFilter = nil
        panFaceView?.removeFromSuperview()
        panFaceView = nil
        blendFilter?.removeAllTargets()
        blendFilter = nil
    }
    
    func setupPanFaceFilter() {
        blendFilter = SourceOverBlend()
        camera --> blendFilter!
        panFaceFilter = PanFaceFilter()
        camera --> panFaceFilter! --> blendFilter! --> renderView
        panFaceView = PanFaceView()
        panFaceView?.viewController = self
        self.view.insertSubview(panFaceView!, aboveSubview: renderView)
        panFaceView?.translatesAutoresizingMaskIntoConstraints = false
        panFaceView?.topAnchor.constraint(equalTo: self.renderView.topAnchor).isActive = true
        panFaceView?.bottomAnchor.constraint(equalTo: self.renderView.bottomAnchor).isActive = true
        panFaceView?.leadingAnchor.constraint(equalTo: self.renderView.leadingAnchor).isActive = true
        panFaceView?.trailingAnchor.constraint(equalTo: self.renderView.trailingAnchor).isActive = true
        self.view.insertSubview(panFaceView!, aboveSubview: renderView)
    }
    
    func resetPanFaceFilter() {
        panFaceFilter?.imageVertices = []
        panFaceFilter?.texCords = []
    }
    
    func configPanFaceFilter(_ face: Face) {
        let originFaceFrame = face.frame.applying(transformToVertexCor())
        panFaceView?.panFaceOriginFrame = originFaceFrame
        
        if let faceContour = face.contour(ofType: .face) {
            panFaceFilter?.imageVertices = []
            panFaceFilter?.texCords = []
            
            var cords = getFaceScaleCords(faceContour, originFaceFrame: originFaceFrame)
            guard !cords.vertices.isEmpty else {
                return
            }
            
            var translationArray: [CGPoint] = []
            if let view = panFaceView {
                translationArray = view.panFaceTranslation
            }
            
            translationArray.enumerated().forEach{i, translate in
                var cordVer = cords.vertices
                cordVer.enumerated().forEach{index, value in
                    if(index % 2 == 0) {
                        cordVer[index] += Float(translate.x)
                    } else {
                        cordVer[index] += Float(translate.y)
                    }
                }

                if(i > 0) {
                    panFaceFilter?.imageVertices?.append(cordVer[0])
                    panFaceFilter?.imageVertices?.append(cordVer[1])
                    panFaceFilter?.texCords?.append(cords.texCord[0])
                    panFaceFilter?.texCords?.append(cords.texCord[1])
                }
                
                panFaceFilter?.imageVertices? += cordVer
                panFaceFilter?.texCords? += cords.texCord
                
                if(i < translationArray.count - 1) {
                    panFaceFilter?.imageVertices?.append(cordVer[cordVer.count - 2])
                    panFaceFilter?.imageVertices?.append(cordVer[cordVer.count - 1])
                    panFaceFilter?.texCords?.append(cords.texCord[cords.texCord.count - 2])
                    panFaceFilter?.texCords?.append(cords.texCord[cords.texCord.count - 1])
                }
            }
        } else {
            panFaceFilter?.imageVertices = []
            panFaceFilter?.texCords = []
        }
    }
    
    func getFaceScaleCords(_ eyeContour: FaceContour, originFaceFrame: CGRect) -> (vertices: [Float], texCord: [Float]) {
        var vertices: [Float] = []
        var texCord: [Float] = []

        let ratio = PanFaceView.panFaceWidth / originFaceFrame.width
        let vertexTransform = CGAffineTransform(translationX: -1 , y: -1).scaledBy(x: CGFloat(2/fbSize.height), y: CGFloat(2/fbSize.width)).concatenating(CGAffineTransform(translationX: -originFaceFrame.origin.x , y: -originFaceFrame.origin.y)).concatenating(CGAffineTransform(scaleX: ratio, y: ratio))
        let textureTransform = transformToTexCor()
        
        var i = 0
        var j = eyeContour.points.count - 1
        while i <= j {
          var point = CGPoint(x: eyeContour.points[i].x, y: eyeContour.points[i].y)
          var verPoint = point.applying(vertexTransform)
          var texPoint = point.applying(textureTransform)
          vertices.append(Float(verPoint.x))
          vertices.append(Float(verPoint.y))
          texCord.append(Float(texPoint.x))
          texCord.append(Float(texPoint.y))
          if i == j {
              break
          }
          point = CGPoint(x: eyeContour.points[j].x, y: eyeContour.points[j].y)
          verPoint = point.applying(vertexTransform)
          texPoint = point.applying(textureTransform)
          vertices.append(Float(verPoint.x))
          vertices.append(Float(verPoint.y))
          texCord.append(Float(texPoint.x))
          texCord.append(Float(texPoint.y))
          i+=1
          j-=1
        }
        
        return (vertices, texCord)
    }
}
