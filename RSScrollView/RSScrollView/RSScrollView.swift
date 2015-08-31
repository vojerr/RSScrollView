//
//  RSScrollView.swift
//  RSScrollView
//
//  Created by Ruslan Samsonov on 8/27/15.
//  Copyright (c) 2015 Ruslan Samsonov. All rights reserved.
//

import Foundation
import UIKit

public class RSScrollView : UIView {
    private struct RSScrollViewScrolling {
        static let None: UInt8 = 0
        static let Horizontal: UInt8 = 1 << 0
        static let Vertical: UInt8 = 1 << 1
    }
    
    private static let OscillationLimit: CGFloat = 2.0
    private static let RubberResistance: CGFloat = 0.3
    
    private var _contentSize: CGSize = CGSizeZero
    public var contentSize: CGSize {
        set {
            var scrollState = RSScrollViewScrolling.None
            if newValue.width > bounds.size.width {
                scrollState |= RSScrollViewScrolling.Horizontal
            }
            if newValue.height > bounds.size.height {
                scrollState |= RSScrollViewScrolling.Vertical
            }
            state = scrollState
            _contentSize = newValue
        }
        get {
            return _contentSize
        }
    }

    private var state: UInt8 = RSScrollViewScrolling.None
    private var origin = CGPointZero
    private var animator : UIDynamicAnimator?
//    UISnapBehavior is bad for one-dimension scrolling
    private var attachBehaviour : UIAttachmentBehavior?
    private var originItem : RSScrollOriginItem
    
    // MARK: Initialization
    required override public init(frame: CGRect) {
        originItem = RSScrollOriginItem()
        super.init(frame: frame)
        initializeView()
    }
    
    required public init(coder aDecoder: NSCoder) {
        originItem = RSScrollOriginItem()
        super.init(coder: aDecoder)
        initializeView()
    }

    func initializeView() {
        let panRecognizer = UIPanGestureRecognizer(target: self, action: "onTap:")
        panRecognizer.addTarget(self, action: "onTap:")
        addGestureRecognizer(panRecognizer)
        animator = UIDynamicAnimator(referenceView: self)
    }
    
    // MARK: State
    func updateByState(inout point: CGPoint) {
        if state & RSScrollViewScrolling.Horizontal == 0 {
            point.x = 0
        }
        if state & RSScrollViewScrolling.Vertical == 0 {
            point.y = 0
        }
    }
    
    // MARK: UIPanGestureRecognizer actions
    func onTap(panRecognizer : UIPanGestureRecognizer) {
        let updateBoundsAction = { [unowned self] (origin: CGPoint) -> Void in
            self.bounds = CGRectMake(origin.x, origin.y, self.bounds.size.width, self.bounds.size.height)
        }
        switch panRecognizer.state {
        case .Began:
            origin = bounds.origin
            animator?.removeAllBehaviors()
            attachBehaviour = nil
        case .Changed:
            let translation = panRecognizer.translationInView(self)
            let potentialOrigin = CGPointMake(origin.x - translation.x, origin.y - translation.y)
            var recalculatedOrigin = rubberOrigin(potentialOrigin)
            updateByState(&recalculatedOrigin)
            updateBoundsAction(recalculatedOrigin)
        case .Ended:
            var velocity = panRecognizer.velocityInView(self)
            velocity.x = -velocity.x
            velocity.y = -velocity.y
            updateByState(&velocity)
            originItem.center = bounds.origin
            
            let velocityBehaviour = UIDynamicItemBehavior(items: [originItem])
            velocityBehaviour.addLinearVelocity(velocity, forItem: originItem)
            velocityBehaviour.resistance = 1.5
            velocityBehaviour.action = { [unowned self] () -> Void in
                let (needSnap, anchor) = self.calculateSpring()
                if (needSnap && self.attachBehaviour == nil) {
                    self.attachBehaviour = UIAttachmentBehavior(item: self.originItem, attachedToAnchor: anchor)
                    self.attachBehaviour!.length = 0.0
                    self.attachBehaviour!.frequency = 2.0
                    self.attachBehaviour!.damping = 1.0
                    
                    let pushBehaviour = UIDynamicItemBehavior(items: [self.originItem])
                    let pushVelocity = CGPointMake(self.originItem.center.x -  anchor.x, self.originItem.center.y - anchor.y)
                    pushBehaviour.addLinearVelocity(pushVelocity, forItem: self.originItem)
                    pushBehaviour.action = { [unowned self, unowned pushBehaviour] () -> Void in
                        updateBoundsAction(self.originItem.center)
                        if (self.needToStopOscillation(origin: self.originItem.center, anchor: anchor)) {
                            self.animator?.removeBehavior(self.attachBehaviour)
                            self.animator?.removeBehavior(pushBehaviour)
                            updateBoundsAction(anchor)
                        }
                    }
                    
                    self.animator?.removeBehavior(velocityBehaviour)
                    self.animator?.addBehavior(pushBehaviour)
                    self.animator?.addBehavior(self.attachBehaviour)
                } else {
                    updateBoundsAction(self.originItem.center)
                }
            }
            animator?.addBehavior(velocityBehaviour)
        default:
            break
        }
    }
    
    // MARK: Oscillation params
    func needToStopOscillation(origin current: CGPoint, anchor: CGPoint) -> Bool {
        return sqrt(pow((current.x - anchor.x), 2.0) + pow((current.y - anchor.y), 2.0)) < RSScrollView.OscillationLimit;
    }
    
    // MARK: Rubber Calculations
    func constraintXValue(value: CGFloat) -> CGFloat {
        return constrainValue(value, dimension: contentSize.width, bound: bounds.size.width)
    }
    
    func constraintYValue(value: CGFloat) -> CGFloat {
        return constrainValue(value, dimension: contentSize.height, bound: bounds.size.height)
    }
    
    func constrainValue(value: CGFloat, dimension: CGFloat, bound: CGFloat) -> CGFloat {
        return max(0.0, min(dimension - bound, value))
    }
    
    func rubberOrigin(potentialOrigin : CGPoint) -> CGPoint {
        return CGPointMake(rubberValue(potentialOrigin.x, dimension: contentSize.width, bound : bounds.size.width), rubberValue(potentialOrigin.y, dimension: contentSize.height, bound : bounds.size.height))
    }
    
    func rubberValue(value : CGFloat, dimension : CGFloat, bound : CGFloat) -> CGFloat {
        let constrainedValue = constrainValue(value, dimension: dimension, bound: bound)
        let offset = value - constrainedValue
        return constrainedValue + offset * RSScrollView.RubberResistance
    }
    
    // Mark: Spring Calculations
    func calculateSpring() -> (Bool, CGPoint) {
        let hboundX = max((contentSize.width - bounds.size.width) / 2, 0.0);
        let hboundY = max((contentSize.height - bounds.size.height) / 2, 0.0);
        let offsetX = originItem.center.x - hboundX
        let offsetY = originItem.center.y - hboundY
        
        if (abs(offsetX) <= hboundX && abs(offsetY) <= hboundY) {
            return (false, CGPointZero)
        }
        let x: CGFloat = (abs(offsetX) > hboundX ? (offsetX > 0 ? hboundX : -hboundX) : offsetX) + hboundX
        let y: CGFloat = (abs(offsetY) > hboundY ? (offsetY > 0 ? hboundY : -hboundY) : offsetY) + hboundY
        return (true, CGPointMake(x, y))
    }
    
    // Mark: Dynamic Origin Item
    private class RSScrollOriginItem : NSObject, UIDynamicItem {
        @objc var center = CGPointZero
        @objc var bounds = CGRectMake(0, 0, 1, 1)
        @objc var transform = CGAffineTransformIdentity
    }
}