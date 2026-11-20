import Foundation

/// カテゴリ推定ルール。配列の並び順が優先順位（先に一致した方が採用される）。
struct CategoryRule: Equatable {
    let category: ExpenseCategory
    let keywords: [String]

    init(category: ExpenseCategory, keywords: [String]) {
        self.category = category
        self.keywords = keywords
    }
}

/// 商品名からカテゴリを推定する。ルールを差し替え・追加できる構造。
struct CategoryClassifier {
    let rules: [CategoryRule]

    init(rules: [CategoryRule]) {
        self.rules = rules
    }

    /// 既定ルール。具体的なカテゴリを先に、汎用的な「食料品」を後ろに置く。
    static let defaultRules: [CategoryRule] = [
        CategoryRule(category: .medical, keywords: [
            "薬", "マスク", "絆創膏", "ばんそうこう", "消毒", "体温計", "目薬", "湿布",
            "胃薬", "風邪", "ビタミン", "サプリ", "処方", "ドラッグ", "鎮痛", "鎮咳",
            "のど飴", "介護", "衛生"
        ]),
        CategoryRule(category: .dailyGoods, keywords: [
            "洗剤", "柔軟剤", "漂白", "ティッシュ", "トイレットペーパー", "キッチンペーパー",
            "ペーパータオル", "シャンプー", "リンス", "コンディショナー", "石鹸", "石けん",
            "ハンドソープ", "ボディソープ", "歯磨き", "歯ブラシ", "洗口", "ゴミ袋", "ごみ袋",
            "スポンジ", "たわし", "掃除", "ぞうきん", "フローリング", "電池", "電球",
            "カイロ", "除菌", "洗濯", "ラップ", "アルミホイル", "キッチン", "タオル",
            "ハンカチ", "ティッシュペーパー", "ドライヤー", "洗面", "収納", "ハンガー",
            "アイロン", "裁縫", "傘"
        ]),
        CategoryRule(category: .clothing, keywords: [
            "シャツ", "ワイシャツ", "ズボン", "パンツ", "スカート", "靴下", "靴",
            "スニーカー", "サンダル", "コート", "ジャケット", "上着", "下着", "衣類",
            "ユニクロ", "しまむら", "帽子", "ベルト", "ネクタイ", "リュック", "バッグ"
        ]),
        CategoryRule(category: .entertainment, keywords: [
            "映画", "シネマ", "ゲーム", "書籍", "本", "雑誌", "コミック", "チケット",
            "ライブ", "コンサート", "カラオケ", "ボウリング", "レジャー", "玩具",
            "おもちゃ", "フィギュア", "映画館", "美術館", "水族館", "動物園", "サブスク",
            "Netflix", "Spotify", "Amazonプライム"
        ]),
        CategoryRule(category: .utilities, keywords: [
            "電気料金", "電力", "ガス料金", "都市ガス", "水道料金", "上下水道", "熱量",
            "電気", "ガス", "水道"
        ]),
        CategoryRule(category: .communication, keywords: [
            "通信", "携帯", "スマホ", "モバイル", "Wi-Fi", "WiFi", "インターネット",
            "データ通信", "NTT", "ドコモ", "ソフトバンク", "楽天モバイル", "ahamo",
            "格安SIM", "プロバイダ", "電話料金", "NHK"
        ]),
        CategoryRule(category: .transport, keywords: [
            "電車", "バス", "地下鉄", "タクシー", "運賃", "切符", "定期券", "ガソリン",
            "給油", "駐車", "駐輪", "高速", "ETC", "新幹線", "JR", "航空", "フェリー",
            "suica", "pasmo", "チャージ", "モノレール"
        ]),
        CategoryRule(category: .food, keywords: [
            "牛乳", "卵", "玉子", "たまご", "肉", "鶏肉", "豚肉", "牛肉", "ひき肉",
            "ソーセージ", "ハム", "ベーコン", "魚", "鮭", "さば", "ツナ", "野菜",
            "果物", "フルーツ", "りんご", "バナナ", "みかん", "オレンジ", "いちご",
            "トマト", "きゅうり", "キャベツ", "レタス", "にんじん", "人参", "玉ねぎ",
            "じゃがいも", "ねぎ", "ほうれん草", "大根", "かぼちゃ", "なす", "ピーマン",
            "きのこ", "しいたけ", "米", "ごはん", "パン", "食パン", "麺", "パスタ",
            "小麦粉", "砂糖", "塩", "醤油", "しょうゆ", "味噌", "みそ", "酢", "油",
            "オリーブ", "マヨネーズ", "ケチャップ", "ソース", "ドレッシング", "豆腐",
            "納豆", "ヨーグルト", "チーズ", "バター", "豆乳", "クリーム", "アイス",
            "冷凍", "お菓子", "菓子", "チョコ", "クッキー", "スナック", "ポテトチップス",
            "せんべい", "ジュース", "飲料", "お茶", "紅茶", "コーヒー", "ミネラルウォーター",
            "ビール", "酒", "ワイン", "焼酎", "調味料", "ふりかけ", "のり", "海苔",
            "わかめ", "缶詰", "カップ麺", "インスタント", "レトルト", "カレールー",
            "ちくわ", "かまぼこ", "天ぷら", "コロッケ", "惣菜", "サラダ", "キムチ",
            "バナナ", "キウイ", "ぶどう", "梨", "桃", "メロン", "すいか", "レモン",
            "酢飯", "もち", "うどん粉", "ホットケーキ", "ジャム", "はちみつ", "スープ"
        ]),
        CategoryRule(category: .dining, keywords: [
            "ラーメン", "うどん", "そば", "寿司", "すし", "定食", "カレー", "ピザ",
            "ハンバーガー", "弁当", "お弁当", "サンドイッチ", "焼肉", "居酒屋",
            "カフェ", "喫茶", "コーヒーショップ", "ドーナツ", "マクドナルド", "モスバーガー",
            "ケンタッキー", "スターバックス", "ドトール", "コメダ", "吉野家", "すき家",
            "松屋", "サイゼリヤ", "ガスト", "デニーズ", "ロイヤルホスト", "ファミレス",
            "食堂", "レストラン", "料理", "デリバリー", "テイクアウト"
        ])
    ]

    static let `default` = CategoryClassifier(rules: defaultRules)

    /// 追加ルールを先頭に差し込んだ分類器を作る（拡張用）。
    func adding(rules newRules: [CategoryRule]) -> CategoryClassifier {
        CategoryClassifier(rules: newRules + rules)
    }

    func category(for itemName: String, merchantName: String? = nil) -> ExpenseCategory {
        let key = TextNormalizer.searchKey(itemName)
        if !key.isEmpty {
            for rule in rules {
                for keyword in rule.keywords {
                    let normalizedKeyword = TextNormalizer.searchKey(keyword)
                    if !normalizedKeyword.isEmpty && key.contains(normalizedKeyword) {
                        return rule.category
                    }
                }
            }
        }
        return merchantFallback(merchantName)
    }

    /// 商品名から判定できない場合の店舗ヒント。
    private func merchantFallback(_ merchantName: String?) -> ExpenseCategory {
        guard let merchantName else { return .other }
        let key = TextNormalizer.searchKey(merchantName)
        guard !key.isEmpty else { return .other }

        let hints: [(ExpenseCategory, [String])] = [
            (.dining, [
                "レストラン", "食堂", "カフェ", "喫茶", "珈琲", "居酒屋", "ラーメン",
                "寿司", "焼肉", "ハンバーガー", "マクドナルド", "モスバーガー",
                "ケンタッキー", "スターバックス", "ドトール", "コメダ", "吉野家",
                "すき家", "松屋", "サイゼリヤ", "ガスト", "デニーズ", "ベーカリー",
                "ピザ", "カレー", "うどん", "そば", "弁当", "キッチン", "ダイニング"
            ]),
            (.medical, ["薬局", "ドラッグ", "調剤", "クリニック", "病院", "歯科"]),
            (.transport, ["タクシー", "鉄道", "バス", "駅", "モノレール", "フェリー"]),
            (.utilities, ["電力", "ガス", "水道"]),
            (.communication, ["通信", "モバイル", "電話"]),
            (.food, [
                "スーパー", "イオン", "セブン", "ローソン", "ファミリーマート",
                "マート", "ストア", "西友", "ライフ", "マルエツ", "業務スーパー",
                "ドン・キホーテ", "コンビニ", "市場", "青果", "精肉", "鮮魚"
            ])
        ]

        for (category, keywords) in hints {
            if keywords.contains(where: { key.contains(TextNormalizer.searchKey($0)) }) {
                return category
            }
        }
        return .other
    }
}
