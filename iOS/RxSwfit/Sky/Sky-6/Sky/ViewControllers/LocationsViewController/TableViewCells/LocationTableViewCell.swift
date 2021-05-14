//
//  LocationTableViewCell.swift
//  Sky
//
//  Created by Mars on 13/02/2018.
//  Copyright © 2018 Mars. All rights reserved.
//

import UIKit

class LocationTableViewCell: UITableViewCell {
    
    static let reuseIdentifier = "LocationCell"
    @IBOutlet weak var label: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    func configure(with viewModel: LocationRepresentable) {
        label.text = viewModel.labelText
    }
}
