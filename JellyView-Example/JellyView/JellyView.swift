//
//  JellyView.swift
//  JellyView-Example
//
//  Created by Vladimir Kozlovskyi on 28.04.16.
//  Copyright © 2016 Vladimir Kozlovskyi. All rights reserved.
//

import UIKit

public enum Position {
  case Left, Right, Top, Bottom
}

@objc public protocol JellyViewDelegate : class {
  optional func jellyViewShouldStartDragging(jellyView : JellyView) -> Bool
  optional func jellyViewDidStartDragging(curtainControl : JellyView)
  optional func jellyViewDidEndDragging(curtainControl : JellyView)
  optional func jellyViewActionFired(curtainControl : JellyView)
}

public final class JellyView : UIView {
  
  public weak var delegate : JellyViewDelegate?
  public var infoView : UIView?
//  public var jellyColor : UIColor = UIColor.whiteColor() {
//    didSet {
//      shapeLayer.fillColor = jellyColor.CGColor
//    }
//  }
  public var triggerThreshold : CGFloat = 0.4
  public var innerPointRatio : CGFloat = 0.4
  public var outerPointRatio : CGFloat = 0.25
  public var flexibility : CGFloat = 0.7
  public var viewMass : CGFloat = 1.0
  public var springStiffness : CGFloat = 200.0
  
  private var touchPoint = CGPointZero
  private var shapeLayer = CAShapeLayer()
  private let beizerPath = UIBezierPath()
  private weak var containerView : UIView?
  private let position : Position
  private var displayLink : CADisplayLink!
  private var colorIndex : NSInteger = 0
  private let colorsArray : Array<UIColor>
  private var shouldStartDragging : Bool {
    if let shouldStartDragging = delegate?.jellyViewShouldStartDragging?(self) {
      return shouldStartDragging
    } else {
      return true
    }
  }
  
  init(position: Position, forView view: UIView, colors: Array<UIColor>) {
    self.position = position
    self.colorsArray = colors
    super.init(frame: view.bounds)
    shapeLayer.fillColor = colorsArray[colorIndex].CGColor
    connectGestureRecognizer(toView: view)
    setupDisplayLink()
    self.backgroundColor = UIColor.clearColor()
    self.layer.insertSublayer(shapeLayer, atIndex: 0)
  }
  
  private func setupDisplayLink() {
    displayLink = CADisplayLink(target: self, selector: #selector(JellyView.animationInProgress))
    displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
    displayLink.paused = true
  }
  
  required public init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func hitTest(point: CGPoint, withEvent event: UIEvent?) -> UIView? {
    return self.superview
  }
  
}

extension JellyView {
  
  private func updateColors() {
    guard let superview = self.superview else { return }
    let currentColor = colorsArray[colorIndex]
    superview.backgroundColor = currentColor
    
    colorIndex += 1
    if colorIndex > colorsArray.count - 1 {
      colorIndex = 0
    }
    
    shapeLayer.fillColor = colorsArray[colorIndex].CGColor
  }
  
}

// MARK: - Stretching JellyView

extension JellyView : UIGestureRecognizerDelegate {
  
  func connectGestureRecognizer(toView view : UIView) {
    let gestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(JellyView.handlePanGesture(_:)))
    gestureRecognizer.delegate = self
    view.addGestureRecognizer(gestureRecognizer)
  }
  
  @objc private func handlePanGesture(let pan : UIPanGestureRecognizer) {
    
    if shouldStartDragging {
      touchPoint = pan.touchPoint(forPosition: position, flexibility: flexibility)
      
      if (pan.state == .Began) {
        self.delegate?.jellyViewDidStartDragging?(self)
        modifyShapeLayerForTouch()
      } else if (pan.state == .Changed) {
        modifyShapeLayerForTouch()
      } else if (pan.state == .Ended || pan.state == .Cancelled) {
        
        self.delegate?.jellyViewDidEndDragging?(self)
        
        if shouldInitiateAction() {
          animateToFinalPosition()
        } else {
          animateToInitialPosition()
        }
      }
    }
  }
  
  private func shouldInitiateAction() -> Bool {
    var size : CGFloat
    var currentProggress : CGFloat
    if position == .Left || position == .Right {
      size = self.frame.size.width
      currentProggress = touchPoint.x
    } else {
      size = self.frame.size.height
      currentProggress = touchPoint.y
    }
    
    let maxProggress = size * triggerThreshold
    if currentProggress >= maxProggress {
      return true
    } else {
      return false
    }
  }
  
  private func modifyShapeLayerForTouch() {
    let pathModifiers = PathModifiers.currentPathModifiers(forPosition: position,
                                                           touchPoint: touchPoint,
                                                           jellyFrame: self.frame,
                                                           outerPointRatio: outerPointRatio,
                                                           innerPointRatio: innerPointRatio)
    applyPathModifiers(pathModifiers)
  }
  
  private func modifyShapeLayerForInitialPosition() {
    let pathModifiers = PathModifiers.initialPathModifiers(forPosition: position,
                                                           touchPoint: touchPoint,
                                                           jellyFrame: self.frame,
                                                           outerPointRatio: outerPointRatio,
                                                           innerPointRatio: innerPointRatio)
    applyPathModifiers(pathModifiers)
  }
  
  private func applyPathModifiers(pathModifiers : PathModifiers) {
    beizerPath.jellyPath(pathModifiers)
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    shapeLayer.path = beizerPath.CGPath
    CATransaction.commit()
  }
  
}

// MARK: - Animations

extension JellyView {
  
  func animateToInitialPosition() {
    let pathModifiers = PathModifiers.initialPathModifiers(forPosition: position,
                                                           touchPoint: touchPoint,
                                                           jellyFrame: self.frame,
                                                           outerPointRatio: outerPointRatio,
                                                           innerPointRatio: innerPointRatio)
    CATransaction.begin()
    self.animationToInitialWillStart()
    let springAnimation = CASpringAnimation(keyPath: "path")
    springAnimation.mass = viewMass
    springAnimation.stiffness = springStiffness
    springAnimation.duration = springAnimation.settlingDuration
    springAnimation.fromValue = beizerPath.CGPath
    beizerPath.jellyPath(pathModifiers)
    shapeLayer.path = beizerPath.CGPath
    CATransaction.setCompletionBlock { self.animationToInitialDidFinish() }
    shapeLayer.addAnimation(springAnimation, forKey: "path")
    CATransaction.commit()
  }
  
  func animateToFinalPosition() {
    let pathModifiers = PathModifiers.expandedPathModifiers(forPosition: position,
                                                           touchPoint: touchPoint,
                                                           jellyFrame: self.frame,
                                                           outerPointRatio: outerPointRatio,
                                                           innerPointRatio: innerPointRatio)
    CATransaction.begin()
    self.animationToFinalWillStart()
    let springAnimation = CASpringAnimation(keyPath: "path")
    springAnimation.mass = viewMass
    springAnimation.damping = 1000
    springAnimation.stiffness = springStiffness
    springAnimation.duration = springAnimation.settlingDuration
    springAnimation.fromValue = beizerPath.CGPath
    beizerPath.jellyPath(pathModifiers)
    shapeLayer.path = beizerPath.CGPath
    CATransaction.setCompletionBlock { self.animationToFinalDidFinish() }
    shapeLayer.addAnimation(springAnimation, forKey: "path")
    CATransaction.commit()

  }
  
  private func animationToInitialWillStart() {
    displayLink.paused = false
  }
  
  @objc private func animationToInitialDidFinish() {
    displayLink.paused = true
  }
  
  private func animationToFinalWillStart() {
    displayLink.paused = false
  }
  
  @objc private func animationToFinalDidFinish() {
    displayLink.paused = true
    updateColors()
    modifyShapeLayerForInitialPosition()
  }
  
  @objc private func animationInProgress() {
    
  }
  
}

// MARK: - Coordinates Calculation

extension JellyView {
  
  private func pointFromCubicBeizerCurve(delta t : CGFloat,
                                   startPoint p0 : CGFloat,
                                controlPoint1 p1 : CGFloat,
                                controlPoint2 p2 : CGFloat,
                                     endPoint p3 : CGFloat) -> CGPoint {
    
    let x = coordinateFromCubicBeizerCurve(delta: t,
                                      startPoint: p0,
                                   controlPoint1: p1,
                                   controlPoint2: p2,
                                        endPoint: p3)
    
    let y = coordinateFromCubicBeizerCurve(delta: t,
                                      startPoint: p0,
                                   controlPoint1: p1,
                                   controlPoint2: p2,
                                        endPoint: p3)
    
    return CGPointMake(x, y)
  }
  
  private func coordinateFromCubicBeizerCurve(delta t : CGFloat,
                                        startPoint p0 : CGFloat,
                                     controlPoint1 p1 : CGFloat,
                                     controlPoint2 p2 : CGFloat,
                                          endPoint p3 : CGFloat) -> CGFloat {
    
    // I had to split expression to several parts to stop the compiler's whining
    var x = pow(1 - t, 3) * p0
    x += 3 * pow(1 - t, 2) * t * p1
    x += 3 * (1 - t) * pow(t, 2) * p2
    x += pow(t, 3) * p3
    return x
  }
  
}
