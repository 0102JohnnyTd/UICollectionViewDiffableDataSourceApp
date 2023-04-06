//
//  TypeOfPokemonCell.swift
//  SampleUICollectionViewDiffableDataSource
//
//  Created by Johnny Toda on 2023/02/01.
//

import UIKit

final class PokemonTypeCell: UICollectionViewCell {
    @IBOutlet private weak var typeLabel: UILabel!

    static let nib = UINib(nibName: String(describing: PokemonTypeCell.self), bundle: nil)
    static let identifier = String(describing: PokemonTypeCell.self)

    func configure(type: String?) {
        typeLabel.text = type
    }
}
