//
//  ViewController.swift
//  RSScrollViewTest
//
//  Created by Ruslan Samsonov on 8/27/15.
//  Copyright (c) 2015 Ruslan Samsonov. All rights reserved.
//

import UIKit
import RSScrollView

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let scrollView = RSScrollView()
        scrollView.frame = view.bounds;
        scrollView.autoresizingMask = UIViewAutoresizing.FlexibleWidth | UIViewAutoresizing.FlexibleHeight
        view.addSubview(scrollView)
        
        scrollView.contentSize = CGSizeMake(1000, 1000)
        for i in 0...10 {
            let subview = UIView()
            let ii = CGFloat(i * 60)
            subview.frame = CGRectMake(ii, ii, 200, 200)
            let iii = CGFloat(i * 60 % 256) / CGFloat(256)
            subview.backgroundColor = UIColor(red: iii, green: iii, blue: iii, alpha: 1)
            scrollView.addSubview(subview)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

