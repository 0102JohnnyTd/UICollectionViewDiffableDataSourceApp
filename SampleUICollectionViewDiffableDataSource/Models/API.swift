//
//  API.swift
//  SampleUICollectionViewDiffableDataSource
//
//  Created by Johnny Toda on 2023/01/31.
//

import Foundation


protocol APIInput {
    func asyncFetchPokemonData() async -> [Pokemon]
    func decodePokemonData(completion: @escaping (Result<[Pokemon], Error>) -> Void)
}


final class API: APIInput {
//    呼び出し時にネスト地獄を避けるためにasync-awaitに対応させる処理を定義
    func asyncFetchPokemonData() async -> [Pokemon] {
        return await withCheckedContinuation { continuation in
            decodePokemonData { result in
                switch result {
                case .success(let pokemons):
                    continuation.resume(returning: pokemons)
                case .failure(let error):
                    // 🍎Neverって何。
                    continuation.resume(throwing: error as! Never)
                }
            }
        }
    }
    
    // 通信によって取得したデータをパース
    // 取得したポケモンのデータをSwiftの型として扱う為にデコード
    func decodePokemonData(completion: @escaping (Result<[Pokemon], Error>) -> Void) {
        print(#function)
        // データの取得を実行
        fetchPokemonData(completion: { result in
            switch result {
            case .success(let dataArray):
                var pokemons: [Pokemon] = []
                dataArray.forEach {
                    do {
                        let pokemon = try JSONDecoder().decode(Pokemon.self, from: $0)
                        pokemons.append(pokemon)
                    } catch {
                        completion(.failure(error))
                    }
                }
                completion(.success(pokemons))
            case .failure(let error as URLError):
                completion(.failure(error))
            case .failure(_):
                fatalError("Unexpected Error")
            }
        })
    }

    // 通信を実行
    private func fetchPokemonData(completion: @escaping (Result<[Data], Error>) -> Void) {
        var dataArray: [Data] = []
        let urls = getURLs()
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

//    private func fetchPokemonsData() async throws -> [Data] {
//        var dataArray: [Data] = []
//        let urls = getURLs()
//        urls.forEach {
//            guard let url = $0 else { fatalError("Unexpected Error") }
//            let task = URLSession.shared.dataTask(with: url) { data, _, _ in
//                if let data = data {
//                    dataArray.append(data)
//                }
//            }
//            task.resume()
//        }
//        return dataArray
//    }

    // ポケモン151匹分のリクエストURLを取得
    private func getURLs() -> [URL?] {
        let pokeDexRange = 1...151
        let urls = pokeDexRange.map { URL(string: "https://pokeapi.co/api/v2/pokemon/\($0)/") }

        return urls
    }
}
