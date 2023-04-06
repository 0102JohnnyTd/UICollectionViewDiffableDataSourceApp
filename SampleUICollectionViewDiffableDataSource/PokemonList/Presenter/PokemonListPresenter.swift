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
//    var numberOfPokemons: Int { get }
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
    case pokemonTypeList, pokemonList

    // Sectionごとの列数を返す
    var columnCount: Int {
        switch self {
        case .pokemonTypeList:
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
    // PokemonTypeListのSetの要素をItemインスタンスの初期値に指定し、mapで配列にして返す
    private lazy var pokemonTypeItems = pokemonTypes.map { Item(pokemonType: $0) }
    // PokemonTypeListの最初に置き、タップすると全タイプのポケモンを表示させる
    private let allTypes = "all"

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
            case .pokemonTypeList:
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
        applyInitialSnapshots()
    }

    // 画面起動時にDataSourceにデータを登録
    private func applyInitialSnapshots() {
        // データをViewに反映させる為のDiffableDataSourceSnapshotクラスのインスタンスを生成
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        // snapshotにSecrtionを追加
        snapshot.appendSections(Section.allCases)
        dataSource.apply(snapshot)

        // pokemonTypeListのItemをSnapshotに追加 (orthogonal scroller)
        // 全タイプ対象のItemを追加
        pokemonTypeItems.insert(Item(pokemonType: allTypes), at: 0)
        var pokemonTypeSnapshot = NSDiffableDataSourceSectionSnapshot<Item>()
        pokemonTypeSnapshot.append(pokemonTypeItems)
        dataSource.apply(pokemonTypeSnapshot, to: .pokemonTypeList, animatingDifferences: true)

        // pokemonListのItemをSnapshotに追加
        var pokemonListSnapshot = NSDiffableDataSourceSectionSnapshot<Item>()
        pokemonListSnapshot.append(pokemons)
        dataSource.apply(pokemonListSnapshot, to: .pokemonList, animatingDifferences: true)
    }

    // アプリ起動時にviewから通知
    func viewDidLoad(collectionView: UICollectionView) {
        view.startIndicator()
        model.decodePokemonData(completion: { [weak self] result in
            switch result {
            case .success(let pokemonsData):
                // 順次要素を追加
                pokemonsData.forEach {
                    self?.pokemons.append(Item(pokemon: $0))
                }

                // ポケモン図鑑No.の昇順になるよう並び替え
                self?.pokemons.sort {
                    guard let pokedexNumber = $0.pokemon else { fatalError("unexpectedError") }
                    guard let anotherPokedexNumber = $1.pokemon else { fatalError("unexpectedError") }
                    return pokedexNumber.id < anotherPokedexNumber.id
                }

                // Setは要素を一意にする為、一度追加されたタイプを自動で省いてくれる。(例: フシギダネが呼ばれると草タイプと毒タイプを取得するので次のフシギソウのタイプは追加されない。
                //結果としてタイプリストの重複を避けることができる
                self?.pokemons.forEach {
                    $0.pokemon?.types.forEach { self?.pokemonTypes.insert($0.type.name) }
                }

                DispatchQueue.main.async {
                    self?.applyInitialSnapshots()
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
            case .success(let pokemonsData):
                // 順次要素を追加
                pokemonsData.forEach {
                    self?.pokemons.append(Item(pokemon: $0))
                }
                // ポケモン図鑑No.の昇順になるよう並び替え
                self?.pokemons.sort {
                    guard let pokedexNumber = $0.pokemon else { fatalError("unexpectedError") }
                    guard let pokedexNumber2 = $1.pokemon else { fatalError("unexpectedError") }
                    return pokedexNumber.id < pokedexNumber2.id
                }

                // Setは要素を一意にする為、一度追加されたタイプを自動で省いてくれる。(例: フシギダネが呼ばれると草タイプと毒タイプを取得するので次のフシギソウのタイプは追加されない。
                //結果としてタイプリストの重複を避けることができる
                self?.pokemons.forEach {
                    $0.pokemon?.types.forEach { self?.pokemonTypes.insert($0.type.name) }
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
