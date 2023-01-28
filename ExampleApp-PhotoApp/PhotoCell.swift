//
//  PhotoCell.swift
//  ExampleApp-PhotoApp
//
//  Created by Yuriy Gudimov on 28.01.2023.
//

import Foundation
import UIKit

class PhotoCell: UICollectionViewCell {
    var imageView = UIImageView()
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if imageView.superview == nil {
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            contentView.addSubview(imageView)
        }
        
        imageView.frame = bounds
    }
}
