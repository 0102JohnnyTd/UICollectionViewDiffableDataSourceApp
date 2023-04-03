//
//  PokemonListPresenter.swift
//  SampleUICollectionViewDiffableDataSource
//
//  Created by Johnny Toda on 2023/01/31.
//

import Foundation
import UIKit

// ViewからPresenterに処理を依頼する際の処理
protocol PokemonListPresenterInput {
    var numberOfPokemons: Int { get }
    func viewDidLoad(collectionView: UICollectionView)
    func didTapRestartURLSessionButton()
    func didTapAlertCancelButton()
//    func didTapTypeOfPokemonCell()
//    func didTapPokemonCell()
}

// ViewからPresenterに処理を依頼する際の処理
protocol PokemonListPresenterOutput: AnyObject {
    func startIndicator()
    func updateView()
    func showAlertMessage(errorMessage: String)
}

// データソースに追加するSection
enum Section: Int, CaseIterable {
    case PokemontypeList, pokemonList

    // Sectionごとの列数を返す
    var columnCount: Int {
        switch self {
        case .PokemontypeList:
            return 1
        case .pokemonList:
            return 2
        }
    }
}

final class PokemonListPresenter: PokemonListPresenterInput {
    // ハードコーディング対策
    static let storyboardName = "PokemonList"
    
    // 通信で取得してパースしたデータを格納する配列
    private var pokemons: [Item] = []
    // ポケモンのタイプをまとめるSet
    private var pokemonTypes = Set<String>()
    // CellのLabel&Snapshotに渡すデータの配列
    // タイプ一覧のSetの要素をItemインスタンスの初期値に指定し、mapで配列にして返す
    private lazy var pokemomnTypeItems = pokemonTypes.map { Item(pokemonType: $0) }

    private weak var view: PokemonListPresenterOutput!
    private var model: APIInput

    init(view: PokemonListPresenterOutput, model: APIInput) {
        self.view = view
        self.model = model
    }

    // データソースを定義
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!

    // データソースを構築
    private func configureDataSource(collectionView: UICollectionView) {
        // pokemonTypeCellの登録
        // 🍏UINibクラス型の引数『cellNib』にPokemonTypeCellクラスで定義したUINibクラス※1を指定
        // ※1: static let nib = UINib(nibName: String(describing: PokemonTypeCell.self), bundle: nil)
        let pokemonTypeCellRegistration = UICollectionView.CellRegistration<PokemonTypeCell, Item>(cellNib: PokemonTypeCell.nib) { cell, indexPath, item in
            cell.layer.cornerRadius = 15
            cell.configure(type: item.pokemonType)
        }

        // pokemonCellの登録
        let pokemonCellRegistration = UICollectionView.CellRegistration<PokemonCell, Item>(cellNib: PokemonCell.nib) { cell, indexpath, item in
            // Cellの構築処理
            cell.configure(imageURL: item.pokemon?.sprites.frontImage, name: item.pokemon?.name)
        }

        // data sourceの構築
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) {
            (collectionView, indexPath, item) -> UICollectionViewCell? in
            guard let section = Section(rawValue: indexPath.section) else { fatalError("Unknown section") }
            switch section {
            case .PokemontypeList:
                return collectionView.dequeueConfiguredReusableCell(using: pokemonTypeCellRegistration,
                                                                    for: indexPath,
                                                                    item: item
                )
            case .pokemonList:
                return collectionView.dequeueConfiguredReusableCell(using: pokemonCellRegistration,
                                                                    for: indexPath,
                                                                    item: item
                )
            }
        }
        applySnapshot()
    }

    // データソースにデータを登録
    private func applySnapshot() {
        // データをViewに反映させる為のDiffableDataSourceSnapshotクラスのインスタンスを生成
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()

        // snapshotにSecrtionを追加
        snapshot.appendSections(Section.allCases)

        // snapshotにItemを追加
        snapshot.appendItems(pokemons, toSection: .pokemonList)
        snapshot.appendItems(pokemonTypes, toSection: .PokemontypeList)

        // データをViewに表示する処理を実行
        dataSource.apply(snapshot)
    }

    var numberOfPokemons: Int { pokemons.count }

    // アプリ起動時にviewから通知
    func viewDidLoad(collectionView: UICollectionView) {
        view.startIndicator()
        model.decodePokemonData(completion: { [weak self] result in
            switch result {
            case .success(let pokemons):
                // 順次要素を追加
                pokemons.forEach {
                    self?.pokemons.append(.pokemon($0))
                }

                // ポケモン図鑑No.通り昇順になるよう並び替え
                self?.pokemons.sort { a, b -> Bool in
                    switch (a, b) {
                    case let (.pokemon(pokemonA), .pokemon(pokemonB)):
                        return pokemonA.id < pokemonB.id
                    // 🍎本来ここは書きたくない。この実装はあくまでPokemonの配列に関する処理なので。これがenumで書くデメリットの一つ
                    default:
                        return true
                    }
                }

                DispatchQueue.main.async {
                    self?.configureDataSource(collectionView: collectionView)
                    self?.view.updateView()
                }
            case .failure(let error as URLError):
                DispatchQueue.main.async {
                    self?.view.showAlertMessage(errorMessage: error.message)
                }
            case .failure:
                fatalError("unexpected Errorr")
            }
        })
    }

    // 再度通信処理を実行
    func didTapRestartURLSessionButton() {
        view.startIndicator()
        model.decodePokemonData(completion: { [weak self] result in
            switch result {
            case .success(let pokemons):
                // 順次要素を追加
                pokemons.forEach {
                    self?.pokemons.append(.pokemon($0))
                }

                // ポケモン図鑑No.通り昇順になるよう並び替え
                self?.pokemons.sort { a, b -> Bool in
                    switch (a, b) {
                    case let (.pokemon(pokemonA), .pokemon(pokemonB)):
                        return pokemonA.id < pokemonB.id
                    // 🍎本来ここは書きたくない。この実装はあくまでPokemonの配列に関する処理なので。これがenumで書くデメリットの一つ
                    default:
                        return true
                    }
                }

                DispatchQueue.main.async {
                    self?.view.updateView()
                }
            case .failure(let error as URLError):
                DispatchQueue.main.async {
                    self?.view.showAlertMessage(errorMessage: error.message)
                }
            case .failure:
                fatalError("unexpected Errorr")
            }
        })
    }

    func didTapAlertCancelButton() {
        view.updateView()
    }

    //    func didTapTypeOfPokemonCell() {
//        <#code#>
//    }
//
//    func didTapPokemonCell() {
//        <#code#>
//    }
}
