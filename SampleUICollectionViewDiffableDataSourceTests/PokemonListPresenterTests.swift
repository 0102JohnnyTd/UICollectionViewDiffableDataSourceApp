//
//  PokemonListPresenterTests.swift
//  SampleUICollectionViewDiffableDataSourceTests
//
//  Created by Johnny Toda on 2023/06/25.
//

import XCTest
@testable import SampleUICollectionViewDiffableDataSource

final class PokemonListPresenterTests: XCTestCase {
    // 1体のポケモンデータが取得できているかのテスト
    func testOnePokemonList() {
        let expectaion = self.expectation(description: "Viewが更新された")
        // 1体のポケモンデータが含まれたデータ配列を代入
        let mockAPI = MockAPI(mockPokemonData: [PokemonListSampleData().pikachu])
        let mockPokemonListView = MockPokemonListView(expectationForUpdateView: expectaion)
        let presenter = PokemonListPresenter(view: mockPokemonListView, model: mockAPI)

        // 仮想通信を実行
        presenter.viewDidLoad()
        wait(for: [expectaion], timeout: 5)
        
        // mockPokemonListViewで定義されているupdateViewHistoryにデータが正しく渡されているかをテスト
        XCTAssertEqual(mockPokemonListView.updateViewHistory, [[PokemonListSampleData().pikachu]])
        XCTAssertEqual(mockPokemonListView.showAlertMessageHistory, [])
    }

    // 通信処理後、View側で空データになっているかをテスト
    func testEmptyPokemonsList() {
        let expectaion = self.expectation(description: "Viewが更新された")
        // デフォルト引数でnilが入り、二項演算子でPokemonデータがnilである場合は空の配列を返す
        // 1体のポケモンデータが含まれたデータ配列を代入
        let mockAPI = MockAPI(mockPokemonData: [])
        let mockPokemonListView = MockPokemonListView(expectationForUpdateView: expectaion)
        let presenter = PokemonListPresenter(view: mockPokemonListView, model: mockAPI)

        // 仮想通信を実行
        presenter.viewDidLoad()
        wait(for: [expectaion], timeout: 5)

        // mockPokemonListViewで定義されているupdateViewHistoryが空であることをテスト
        XCTAssertEqual(mockPokemonListView.updateViewHistory, [[]])
        XCTAssertEqual(mockPokemonListView.showAlertMessageHistory, [])
    }

    // 5体のポケモンデータをViewに正しく渡せているかのテスト
    func testFivePokemonsList() {
        let expectaion = self.expectation(description: "Viewが更新された")
        // 5体のポケモンデータが含まれたデータ配列を代入
        let mockAPI = MockAPI(mockPokemonData: PokemonListSampleData().favoriteFivePokemons)
        let mockPokemonListView = MockPokemonListView(expectationForUpdateView: expectaion)
        let presenter = PokemonListPresenter(view: mockPokemonListView, model: mockAPI)

        // 仮想通信を実行
        presenter.viewDidLoad()
        wait(for: [expectaion], timeout: 5)

        // mockPokemonListViewで定義されているupdateViewHistoryに5つのデータが正しく渡されているかをテスト
        XCTAssertEqual(mockPokemonListView.updateViewHistory, [PokemonListSampleData().favoriteFivePokemons])
        XCTAssertEqual(mockPokemonListView.showAlertMessageHistory, [])
    }

    // エラー発生時のテスト
    func testCheckError() {
        let expectaion = self.expectation(description: "Viewが更新された")

        // パース処理失敗時のエラーを代入
        let mockAPI = MockAPI(apiError: .decodingFailed, mockPokemonData: [])
        let mockPokemonListView = MockPokemonListView(expectationForUpdateView: expectaion)
        let presenter = PokemonListPresenter(view: mockPokemonListView, model: mockAPI)

        // 仮想通信を実行
        presenter.viewDidLoad()
        wait(for: [expectaion], timeout: 5)

        XCTAssertEqual(mockPokemonListView.updateViewHistory, [[]])
        XCTAssertEqual(mockPokemonListView.showAlertMessageHistory, ["デコードに失敗しました"])
    }
}
