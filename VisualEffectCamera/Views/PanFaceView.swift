//
//  PanFaceView.swift
//  VisualEffectCamera
//
//  Created by du jinzhe on 2022/6/17.
//

import UIKit

class PanFaceView: UIView {
    enum TrackedIndex {
    case none, origin
    case translation(Int)
    }
    
    lazy var panFaceLabel: UILabel? = {
        let label = UILabel()
        label.text = "拖动脸部"
        return label
    }()
    
    weak var viewController: ViewController!
    
    static let panFaceWidth = 0.8
    
    var panFaceTranslation: [CGPoint] = []
    var panFaceOriginFrame = CGRect(x: 0, y: 0, width: 0, height: 0)
    var panFaceTranslationSize: CGSize {
        guard panFaceOriginFrame.size != .zero else {
            return .zero
        }
        return CGSize(width: PanFaceView.panFaceWidth, height: panFaceOriginFrame.height / panFaceOriginFrame.width * PanFaceView.panFaceWidth)
    }
    
    var viewToNormTransform: CGAffineTransform {
        let viewHeight = self.bounds.height
        let viewWidth = self.bounds.width
        let fbHeight = CGFloat(viewController.fbSize.width)
        let fbWidth = CGFloat(viewController.fbSize.height)
        let viewHWRatio = viewHeight / viewWidth
        let fbHWRatio = fbHeight / fbWidth
        
        if viewHWRatio > fbHWRatio {
            let heightRatio = viewHWRatio / fbHWRatio
            return CGAffineTransform(translationX: -1, y: -heightRatio).scaledBy(x: 2/viewWidth, y: CGFloat(2 * heightRatio / viewHeight))
        } else {
            let widthRatio = fbHWRatio / viewHWRatio
            return CGAffineTransform(translationX: -widthRatio, y: -1).scaledBy(x: 2 * widthRatio/viewWidth, y: CGFloat(2 / viewHeight))
        }
    }
    var trackedIndex: TrackedIndex = .none
    
    var trackedTouch: UITouch?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard panFaceOriginFrame != .zero else {
            return
        }
        
        if trackedTouch == nil, let touch = touches.first {
            trackedTouch = touch
            trackedIndex = .none
            
            let touchPoint = touch.location(in: self).applying(viewToNormTransform)
            
            for i in stride(from: panFaceTranslation.count - 1, to: -1, by: -1) {
                let frame = CGRect(origin: panFaceTranslation[i], size: panFaceTranslationSize)
                if(touchPoint.x > frame.minX && touchPoint.x < frame.maxX && touchPoint.y > frame.minY && touchPoint.y < frame.maxY) {
                    trackedIndex = .translation(i)
                    return
                }
            }
            
            if(touchPoint.x > panFaceOriginFrame.minX && touchPoint.x < panFaceOriginFrame.maxX && touchPoint.y > panFaceOriginFrame.minY && touchPoint.y < panFaceOriginFrame.maxY) {
                trackedIndex = .origin
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let tounch = trackedTouch, touches.contains(tounch) {
            let newPoint = tounch.location(in: self).applying(viewToNormTransform)
            let previousPoint = tounch.previousLocation(in: self).applying(viewToNormTransform)
            
            switch trackedIndex {
            case .none:
                return
            case .origin:
                panFaceTranslation.append(CGPoint(x: newPoint.x - panFaceTranslationSize.width / 2, y: newPoint.y - panFaceTranslationSize.height / 2))
                trackedIndex = .translation(panFaceTranslation.count - 1)
                panFaceLabel?.removeFromSuperview()
                panFaceLabel = nil
            case let .translation(i):
                panFaceTranslation[i].x += newPoint.x - previousPoint.x
                panFaceTranslation[i].y += newPoint.y - previousPoint.y
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let tounch = trackedTouch, touches.contains(tounch) {
            trackedTouch = nil
            trackedIndex = .none
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let tounch = trackedTouch, touches.contains(tounch) {
            trackedTouch = nil
            trackedIndex = .none
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    private func setupView() {
        self.backgroundColor = .clear
        self.addSubview(panFaceLabel!)
        panFaceLabel!.translatesAutoresizingMaskIntoConstraints = false
        panFaceLabel!.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        panFaceLabel!.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
    }
}
