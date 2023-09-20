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

final class PokemonListPresenter {
    // ハードコーディング対策
    static let storyboardName = "PokemonList"
    static let identifier = "PokemonList"
    
    // 通信で取得してパースしたデータを格納する配列
    private var pokemons: [Pokemon] = []
    // ポケモンのタイプをまとめるSet
    private var pokemonTypes = Set<String>()
    // CellのLabel&Snapshotに渡すデータの配列
    // PokemonTypeListのSetの要素をItemインスタンスの初期値に指定し、mapで配列にして返す
    private var pokemonTypeNames: [String] { ["all"] + pokemonTypes }
    // PresenterはViewを弱参照で持つ。
    private weak var view: PokemonListPresenterOutput!
    private var model: APIInput
    private var pokemonDownloder: PokemonDownloderDelegate

    init(view: PokemonListPresenterOutput, model: APIInput, pokemonDownloder: PokemonDownloderDelegate) {
        self.view = view
        self.model = model
        self.pokemonDownloder = pokemonDownloder
    }

    deinit {
        print(String(describing: PokemonListPresenter.self) + " " + "is deinitialized.")
    }

    /// 通信を実行し、取得データを配列pokemonsに渡す
    private func fetchPokemons() async throws {
        do {
            let pokemonsData = try await pokemonDownloder.fetchPokemons(model: model, view: view)
            pokemons.append(contentsOf: pokemonsData)
            // Setは要素を一意にする為、一度追加されたタイプを自動で省いてくれる。(例: フシギダネが呼ばれると草タイプと毒タイプを取得するので次のフシギソウのタイプは追加されない。
            // 結果としてタイプリストの重複を避けることができる
            // TODO: 加工した結果をどうこうしたいというわけではないのでこれもやはりforEachになってしまうのでは？
            pokemons.forEach {
                $0.types.forEach { pokemonTypes.insert($0) }
            }
            view.updateView(pokemonTypeNames: pokemonTypeNames, pokemons: pokemons)
        } catch let error as URLError {
            view.showAlertMessage(errorMessage: error.message)
        } catch let error as HTTPError {
            view.showAlertMessage(errorMessage: error.description)
        } catch let error as APIError {
            view.showAlertMessage(errorMessage: error.description)
        }
    }
}

extension PokemonListPresenter: PokemonListPresenterInput {
    // アプリ起動時にviewから通知
    func viewDidLoad() {
        Task {
            try await fetchPokemons()
        }
    }

    /// 再度通信処理を実行
    func didTapRestartURLSessionButton() {
        Task {
            try await fetchPokemons()
        }
    }

    // PokemonTypeCellタップ時にViewから呼び出される処理
    /// タップしたタイプに該当するポケモンのみを表示する
    func didTapPokemonTypeCell(pokemonType: String) {
        // 取得したタイプに該当するポケモンのみを要素とした配列を返す
        let filteredPokemons = pokemons.filter {
            return $0.types.contains {
                // "all"Cellをタップ時は無条件に配列の要素として追加する
                if pokemonType == "all" { return true }
                return $0.contains(pokemonType)
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
