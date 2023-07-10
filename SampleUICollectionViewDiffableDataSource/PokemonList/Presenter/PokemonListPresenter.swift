//
//  PokemonListPresenter.swift
//  SampleUICollectionViewDiffableDataSource
//
//  Created by Johnny Toda on 2023/01/31.
//

import Foundation
import UIKit

// ViewからPresenterに処理を依頼する際に呼ばれるメソッド
protocol PokemonListPresenterInput {
    func viewDidLoad()
    func didTapRestartURLSessionButton()
    func didTapAlertCancelButton()
    func didTapPokemonTypeCell(pokemonType: String)
    func didTapPokemonCell(pokemon: Pokemon)
}

// ViewからPresenterに処理を依頼する際の処理
protocol PokemonListPresenterOutput: AnyObject {
    func startIndicator()
    func updateView(pokemonTypeNames: [String], pokemons: [Pokemon])
    func updateDataSoure(pokemons: [Pokemon])
    func showAlertMessage(errorMessage: String)
    func showPokemonDetailsVC(pokemon: Pokemon)
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
    static let identifier = "PokemonList"
    
    // 通信で取得してパースしたデータを格納する配列
    private var pokemons: [Pokemon] = []
    // ポケモンのタイプをまとめるSet
    private var pokemonTypes = Set<String>()
    // CellのLabel&Snapshotに渡すデータの配列
    // PokemonTypeListのSetの要素をItemインスタンスの初期値に指定し、mapで配列にして返す
    private var pokemonTypeNames: [String] {
        ["all"] + pokemonTypes
    }
    // PresenterはViewを弱参照で持つ。
    private weak var view: PokemonListPresenterOutput!
    var model: APIInput

    init(view: PokemonListPresenterOutput, model: APIInput) {
        self.view = view
        self.model = model
    }

    deinit {
        print(String(describing: PokemonListPresenter.self) + " " + "is deinitialized.")
    }

    // アプリ起動時にviewから通知
    func viewDidLoad() {
        fetchPokemons()
    }

    /// 再度通信処理を実行
    func didTapRestartURLSessionButton() {
        fetchPokemons()
    }

    private func fetchPokemons() {
        view.startIndicator()
        model.decodePokemonData(completion: { [weak self] result in
            switch result {
            case .success(let pokemonsData):
                print("pokemonsData", pokemonsData)
                DispatchQueue.main.async { [weak self] in
                    guard let strongSelf = self else { return }

                    // 順次要素を追加
                    // ポケモン図鑑No.の昇順になるよう並び替え
                    strongSelf.pokemons.append(
                        contentsOf: pokemonsData.sorted(
                            by: { $0.id < $1.id }
                        )
                    )

                    // Setは要素を一意にする為、一度追加されたタイプを自動で省いてくれる。(例: フシギダネが呼ばれると草タイプと毒タイプを取得するので次のフシギソウのタイプは追加されない。
                    // 結果としてタイプリストの重複を避けることができる
                    strongSelf.pokemons.forEach {
                        $0.types.forEach { strongSelf.pokemonTypes.insert($0.type.name) }
                    }

                    strongSelf.view.updateView(pokemonTypeNames: strongSelf.pokemonTypeNames, pokemons: strongSelf.pokemons)
                }
            case .failure(let error as URLError):
                DispatchQueue.main.async { [weak self] in
                    self?.view.showAlertMessage(errorMessage: error.message)
                }
            case .failure:
                fatalError("unexpectedError")
            }
        })
    }

    // PokemonTypeCellタップ時にViewから呼び出される処理
    /// タップしたタイプに該当するポケモンのみを表示する
    func didTapPokemonTypeCell(pokemonType: String) {
        // 取得したタイプに該当するポケモンのみを要素とした配列を返す
        let filteredPokemons = pokemons.filter {
            return $0.types.contains {
                // "all"Cellをタップ時は無条件に配列の要素として追加する
                if pokemonType == pokemonTypeNames[0] { return true }
                return $0.type.name.contains(pokemonType)
            }
        }
        // DataSrourceを更新
        view.updateDataSoure(pokemons: filteredPokemons)
    }

    // PokemonCellタップ時にViewから呼び出される処理
    /// タップしたポケモンの詳細画面に遷移する
    func didTapPokemonCell(pokemon: Pokemon) {
        // TODO: Presenterを噛ませるメリットはあるのか？テストしやすい？
        view.showPokemonDetailsVC(pokemon: pokemon)
    }

    func didTapAlertCancelButton() {
        view.updateView(pokemonTypeNames: pokemonTypeNames, pokemons: pokemons)
    }
}
