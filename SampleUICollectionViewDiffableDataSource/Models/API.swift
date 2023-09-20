//
//  API.swift
//  SampleUICollectionViewDiffableDataSource
//
//  Created by Johnny Toda on 2023/01/31.
//

import Foundation


protocol APIInput {
    //    func asyncFetchPokemonData() async -> [Pokemon]
    func decodePokemonData(completion: @escaping (Result<[Pokemon], Error>) -> Void)
    func decodePokemonData() async throws -> [Pokemon]
}


final class API: APIInput {
    private var dataArray: [Data] = []
    private let decoder = JSONDecoder()
//    private var pokemons: [Pokemon] = []

    // 通信によって取得したデータをパース
    // 取得したポケモンのデータをSwiftの型として扱う為にデコード
    func decodePokemonData(completion: @escaping (Result<[Pokemon], Error>) -> Void) {
        print(#function)
        // データの取得を実行
        fetchPokemonData(completion: { result in
            switch result {
            case .success(let dataArray):
                    do {
                        // DTOにdecode
                        // DTOをEntity(Pokemon)に変換
                        let pokemons = try dataArray.map { try JSONDecoder().decode(PokemonDTO.self, from: $0).convertToPokemon() }
                        // pokemonsを呼び出し元に通知
                        completion(.success(pokemons))
                    } catch {
                        completion(.failure(error))
                    }
            case .failure(let error as URLError):
                completion(.failure(error))
            case .failure(_):
                fatalError("Unexpected Error")
            }
        })
    }

    func decodePokemonData() async throws -> [Pokemon] {
        do {
            let dataArray = try await fetchPokemonData()
            return try dataArray.map { try decoder.decode(PokemonDTO.self, from: $0).convertToPokemon() }
        } catch {
            throw error
        }
    }

    // 通信を実行
    private func fetchPokemonData(completion: @escaping (Result<[Data], Error>) -> Void) {
        var dataArray: [Data] = []
        let urls = getURLs()
        // TODO: 下に同じく。
        urls.forEach {
            guard let url = $0 else { return }
            let task = URLSession.shared.dataTask(with: url, completionHandler: { data, _, error in
                if let error = error {
                    completion(.failure(error))
                }
                if let data = data {
                    dataArray.append(data)
                }
                if urls.count == dataArray.count {
                    completion(.success(dataArray))
                }
            })
            task.resume()
        }
    }

    private func fetchPokemonData() async throws -> [Data] {
        let urls = getURLs()
        return try await withCheckedThrowingContinuation { continuation in
            // TODO: これ、forEach使わない方法あるのか？
            // こればっかりは493個のURLで通信してデータを取得しないといけないので代替案が思い浮かばない。
            urls.forEach {
                guard let url = $0 else { return }
                let task = URLSession.shared.dataTask(with: url, completionHandler: { [weak self] data, _, error in
                    guard let strongSelf = self else { return }
                    if let error = error {
                        continuation.resume(throwing: error)
                    }
                    if let data = data {
                        strongSelf.dataArray.append(data)
                    }
                    if urls.count == strongSelf.dataArray.count {
                        continuation.resume(returning: strongSelf.dataArray)
                    }
                })
                task.resume()
            }
        }
    }

    // ポケモン151匹分のリクエストURLを取得
    private func getURLs() -> [URL?] {
        let pokeDexRange = 1...151
        let urls = pokeDexRange.map { URL(string: "https://pokeapi.co/api/v2/pokemon/\($0)/") }
        return urls
    }
}
