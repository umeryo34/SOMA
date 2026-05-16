//
//  MuscleExerciseCatalog.swift
//  Fiture
//
//  部位ごとの定番種目と、種目名から部位への逆引き（ハイライト表示用）
//

import Foundation

enum MuscleExerciseCatalog {

    static func exercises(for muscle: InteractiveBodyModelView.MuscleType) -> [String] {
        exercisesMap[muscle] ?? []
    }

    /// 保存済みの種目名から、アプリ内の部位へ変換（完全一致）
    static func muscleType(forExerciseType name: String) -> InteractiveBodyModelView.MuscleType? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for (muscle, list) in exercisesMap where list.contains(trimmed) {
            return muscle
        }
        return nil
    }

    private static let exercisesMap: [InteractiveBodyModelView.MuscleType: [String]] = [
        .chest: [
            "ベンチプレス", "インクラインベンチプレス", "ダンベルベンチプレス", "ディップス", "荷重ディップス",
            "ダンベルフライ", "インクラインダンベルフライ", "腕立て伏せ", "ナロープッシュアップ",
            "チェストプレスマシン", "ペックデッキフライ"
        ],
        .back: [
            "グッドモーニング", "デッドリフト", "プルアップ", "ベントオーバーロー", "ラットプルダウン",
            "シーテッドロウマシン", "シーテッドケーブルロウ", "ダンベルロウ", "ワンハンドダンベルロウ"
        ],
        .abs: [
            "腹筋(クランチ)", "Vアップ", "プランク", "レッグレイズ", "レッグレイズマシン"
        ],
        .biceps: [
            "バーベルカール", "ダンベルカール", "プリーチャーカールマシン", "ケーブルカール"
        ],
        .shoulders: [
            "ダンベルショルダープレス", "バーベルショルダープレス", "アーノルドプレス",
            "サイドレイズ", "フロントレイズ", "リアレイズ", "アップライトロウ", "フェイスプル"
        ],
        /// 上腕・前腕まとめた「腕」
        .arms: [
            "ダンベルリストカール"
        ],
        .triceps: [
            "ダンベルフレンチプレス", "バーベルフレンチプレス", "クローズグリップベンチプレス",
            "ケーブルトライセプスエクステンション"
        ],
        .thighs: [
            "スクワット", "ハーフスクワット", "レッグプレス", "レッグエクステンション",
            "ブルガリアンスクワット"
        ],
        .lowerLegs: [
            "レッグカール", "シーテッドカーフレイズ"
        ],
        .glutes: []
    ]
}
