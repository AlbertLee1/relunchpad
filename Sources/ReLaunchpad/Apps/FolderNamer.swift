import Foundation

/// Original Launchpad names new folders after the apps' App Store category.
enum FolderNamer {
    static let fallback = "未命名文件夹"

    private static let categoryNames: [String: String] = [
        "public.app-category.business": "商务",
        "public.app-category.developer-tools": "开发者工具",
        "public.app-category.education": "教育",
        "public.app-category.entertainment": "娱乐",
        "public.app-category.finance": "财务",
        "public.app-category.games": "游戏",
        "public.app-category.graphics-design": "图形与设计",
        "public.app-category.healthcare-fitness": "健康与健身",
        "public.app-category.lifestyle": "生活方式",
        "public.app-category.medical": "医疗",
        "public.app-category.music": "音乐",
        "public.app-category.news": "新闻",
        "public.app-category.photography": "摄影",
        "public.app-category.productivity": "效率",
        "public.app-category.reference": "参考",
        "public.app-category.social-networking": "社交",
        "public.app-category.sports": "体育",
        "public.app-category.travel": "旅行",
        "public.app-category.utilities": "实用工具",
        "public.app-category.video": "视频",
        "public.app-category.weather": "天气",
    ]

    /// Majority category across the folder's members, ties broken by first seen.
    static func suggestedName(forAppsAt urls: [URL]) -> String {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for url in urls {
            guard let category = Bundle(url: url)?
                .object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String,
                let name = categoryNames[category] else { continue }
            if counts[name] == nil { order.append(name) }
            counts[name, default: 0] += 1
        }
        guard let best = order.max(by: { (counts[$0] ?? 0) < (counts[$1] ?? 0) }) else {
            return fallback
        }
        return best
    }
}
