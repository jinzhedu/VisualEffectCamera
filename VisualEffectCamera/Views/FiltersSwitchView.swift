//
//  FiltersSwitchView.swift
//  VisualEffectCamera
//
//  Created by du jinzhe on 2022/6/11.
//

import UIKit

struct FilterItem {
    let type: FilterType
    let imageName: String
}

protocol FiltersSwitchDelegate: AnyObject {
    func switchTo(filter: FilterType)
}

class FiltersSwitchView: UIView {
    static let itemMargin = 30.0
    static let viewHeight = 120.0
    static let lineWidth = 4.0
    
    var firstItemPosConstraint: NSLayoutConstraint?
    public var filterItems = [FilterItem]() {
        didSet {
            let viewCnt = filterItemViews.count
            let itemCnt = filterItems.count
            
            if(itemCnt == 0) {
                firstItemPosConstraint = nil
            }
            
            if(viewCnt > 0 && itemCnt > 0) {
                if(viewCnt > itemCnt) {
                    let contraints = filterItemViews[itemCnt - 1].constraintsAffectingLayout(for: .horizontal)
                    for item in contraints {
                        if(item.firstItem === filterItemViews[itemCnt] || item.secondItem === filterItemViews[itemCnt]) {
                            item.isActive = false
                        }
                    }
                } else if(viewCnt < itemCnt) {
                    let contraints = filterItemViews[viewCnt - 1].constraintsAffectingLayout(for: .horizontal)
                    for item in contraints {
                        if(item.firstItem === containerView || item.secondItem === containerView) {
                            item.isActive = false
                        }
                    }
                }
            }
            
            if(viewCnt > itemCnt) {
                for view in filterItemViews[itemCnt...] {
                    view.removeFromSuperview()
                }
                filterItemViews.removeLast(viewCnt - itemCnt)
                
            }
            
            for i in 0..<filterItemViews.count {
                if(oldValue[i].type != filterItems[i].type) {
                    filterItemViews[i].image = UIImage(named: filterItems[i].imageName)
                }
            }
            
            for i in filterItemViews.count..<itemCnt {
                let view = UIImageView(image: UIImage(named: filterItems[i].imageName))
                view.translatesAutoresizingMaskIntoConstraints = false
                view.layer.cornerRadius = (FiltersSwitchView.viewHeight - FiltersSwitchView.itemMargin * 2) / 2
                view.layer.masksToBounds = true
                filterItemViews.append(view)
                containerView.addSubview(view)
                view.topAnchor.constraint(equalTo: containerView.topAnchor, constant: FiltersSwitchView.itemMargin).isActive = true
                view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -FiltersSwitchView.itemMargin).isActive = true
                view.widthAnchor.constraint(equalTo: view.heightAnchor).isActive = true
                if(i == 0) {
                    view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: FiltersSwitchView.itemMargin).isActive = true
                    firstItemPosConstraint = view.centerXAnchor.constraint(equalTo: self.centerXAnchor)
                    firstItemPosConstraint?.isActive = true
                    viewPositionChanged = false
                    selectIndex = 0
                } else {
                    view.leadingAnchor.constraint(equalTo: filterItemViews[i-1].trailingAnchor, constant: FiltersSwitchView.itemMargin).isActive = true
                }
            }
            
            if(itemCnt > 0 && itemCnt != viewCnt) {
                containerView.trailingAnchor.constraint(equalTo: filterItemViews[itemCnt - 1].trailingAnchor, constant: FiltersSwitchView.itemMargin).isActive = true
            }
        }
    }
    
    private var filterItemViews = [UIImageView]()
    
    weak var actionDelegate: FiltersSwitchDelegate?
    
    lazy var containerView: UIView = {
        let view = UIView()
        self.addSubview(view)
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        view.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        view.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        return view
    }()
    
    lazy var selectedCircleLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.frame = .zero
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor.white.cgColor
        layer.lineWidth = FiltersSwitchView.lineWidth
        layer.strokeEnd = 1
        return layer
    }()
    
    private var animator: UIViewPropertyAnimator?
    
    private var viewPositionChanged = false
    
    private var selectIndex = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    private func setupView() {
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panView(_:)))
        self.addGestureRecognizer(panGestureRecognizer)
        self.backgroundColor = .clear
        self.layer.addSublayer(selectedCircleLayer)
        selectedCircleLayer.zPosition = .greatestFiniteMagnitude - .leastNonzeroMagnitude
    }
    
    @objc func panView(_ gestureRecognizer : UIPanGestureRecognizer) {
        guard filterItemViews.count >= 2 else {return}
        guard gestureRecognizer.view != nil else {return}
        
        if gestureRecognizer.state == .began, let anim = animator, anim.state == .active {
            anim.stopAnimation(true)
        }
        
        let view = gestureRecognizer.view!
        let translation = gestureRecognizer.translation(in: view)
        let centerX = view.bounds.width / 2
        let firstItemCenter = self.convert(filterItemViews.first!.center, from: containerView).x
        let lastItemCenter = self.convert(filterItemViews.last!.center, from: containerView).x
        
        if(!viewPositionChanged && firstItemCenter != centerX) {
            //Layout haven't been executed, so return. Not sure whether this case may happen.
            gestureRecognizer.setTranslation(.zero, in: view)
            return
        }
        
        if(firstItemCenter + translation.x > centerX || lastItemCenter + translation.x < centerX) {
            gestureRecognizer.setTranslation(.zero, in: view)
            return
        }
        
        containerView.center.x += translation.x
        gestureRecognizer.setTranslation(.zero, in: view)
        viewPositionChanged = true
        
        let offsetPerItem = filterItemViews[1].center.x - filterItemViews[0].center.x
        let firstItemCenterNow = self.convert(filterItemViews.first!.center, from: containerView).x
        let q = ((firstItemCenterNow - centerX) / offsetPerItem).rounded(.toNearestOrAwayFromZero)
        let firstItemCenterNew = q * offsetPerItem + centerX
        let newSelectIndex = Int(-q)
        if(newSelectIndex != selectIndex && abs(firstItemCenterNew - firstItemCenterNow) < 2) {
            selectIndex = newSelectIndex
            actionDelegate?.switchTo(filter: filterItems[selectIndex].type)
        }
        
        if gestureRecognizer.state == .cancelled || gestureRecognizer.state == .ended{
            animator = UIViewPropertyAnimator(duration: 0.25, curve: .easeOut, animations: { [self] in
                containerView.center.x += firstItemCenterNew - firstItemCenterNow
            })
            animator!.isInterruptible = true
            animator!.addCompletion({ [self] _ in
                if(newSelectIndex != selectIndex) {
                    selectIndex = newSelectIndex
                    actionDelegate?.switchTo(filter: filterItems[selectIndex].type)
                }
            })
            animator!.startAnimation()
        }
    }
    
    override func layoutSubviews() {
        if(viewPositionChanged && filterItemViews.count > 0) {
            let centerX = self.bounds.width / 2
            let firstItemCenter = self.convert(filterItemViews.first!.center, from: containerView).x
            firstItemPosConstraint?.constant = firstItemCenter - centerX
        }
        super.layoutSubviews()
        
        layoutSelectedCircleLayer()
    }
    
    func layoutSelectedCircleLayer() {
        let center = CGPoint(x: self.bounds.width / 2, y: self.bounds.height / 2)
        let radius = (FiltersSwitchView.viewHeight - FiltersSwitchView.itemMargin * 2) / 2 + FiltersSwitchView.lineWidth * 2
        let newFrame = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        if(newFrame != selectedCircleLayer.frame) {
            selectedCircleLayer.frame = newFrame
            let pathRadius = radius - FiltersSwitchView.lineWidth / 2
            let path = UIBezierPath(arcCenter: CGPoint(x: radius, y: radius), radius: pathRadius, startAngle: -0.5 * .pi, endAngle: 1.5 * .pi, clockwise: true)
            selectedCircleLayer.path = path.cgPath
        }
    }
}
