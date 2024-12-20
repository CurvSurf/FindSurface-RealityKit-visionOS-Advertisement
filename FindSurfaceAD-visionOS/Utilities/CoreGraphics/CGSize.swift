//
//  CGSize.swift
//  FindSurfaceAD-visionOS
//
//  Created by CurvSurf-SGKim on 11/8/24.
//

import CoreGraphics

extension CGSize {
    var aspectRatio: CGFloat {
        width / height
    }
    
    func fit(in frame: CGSize) -> CGRect {
        return fitImageInFrame(frameWidth: frame.width, frameHeight: frame.height, imageAspectRatio: aspectRatio)
    }
}

func fitImageInFrame(frameWidth: CGFloat, frameHeight: CGFloat, imageAspectRatio: CGFloat) -> CGRect {
    let frameAspectRatio = frameWidth / frameHeight
    
    var imageSize: CGSize
    if imageAspectRatio > frameAspectRatio {
        let imageWidth = frameWidth
        let imageHeight = imageWidth / imageAspectRatio
        imageSize = CGSize(width: imageWidth, height: imageHeight)
    } else {
        let imageHeight = frameHeight
        let imageWidth = imageHeight * imageAspectRatio
        imageSize = CGSize(width: imageWidth, height: imageHeight)
    }
    
    let x = (frameWidth - imageSize.width) / 2
    let y = (frameHeight - imageSize.height) / 2
    return CGRect(origin: CGPoint(x: x, y: y), size: imageSize)
}
