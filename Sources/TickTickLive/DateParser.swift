import Foundation

/// Local date parsing. The model returns dates as English phrases ("next Friday 3pm"), and the
/// review screen accepts free text in the interface languages ("завтра в 15:00").
enum DateParser {
    struct Result: Equatable {
        var date: Date
        var hasTime: Bool
    }

    static func parse(_ raw: String, now: Date = Date(), calendar: Calendar = .current) -> Result? {
        var cal = calendar
        cal.firstWeekday = 2
        var s = " " + raw.lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .replacingOccurrences(of: ",", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines) + " "
        s = s.replacingOccurrences(of: "  ", with: " ")
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || ["none", "null", "no", "no date"].contains(trimmed) { return nil }

        if let iso = parseISO(raw.trimmingCharacters(in: .whitespacesAndNewlines)) { return iso }
        if let rel = parseRelativeDuration(s, now: now, cal: cal) { return rel }

        var day: Date?
        // Weekday words are cut out first so "martes"/"mardi" never read as "mar(ch)".
        let weekday = extractWeekday(s)
        let withoutWeekday = weekday?.1 ?? s
        // Explicit month dates win ("friday september 30", "30 сентября", "30.09").
        if let (d, rest) = extractMonthDate(withoutWeekday, now: now, cal: cal) {
            day = d; s = rest
        } else if let (offset, rest) = extractDayWord(s) {
            day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now)); s = rest
        } else if let (wd, rest) = weekday {
            day = nextWeekday(wd, after: now, cal: cal); s = rest
        }
        let time = extractTime(s)

        if let day {
            if let (h, m) = time {
                return Result(date: cal.date(bySettingHour: h, minute: m, second: 0, of: day)!, hasTime: true)
            }
            return Result(date: day, hasTime: false)
        }
        if let (h, m) = time {
            var d = cal.date(bySettingHour: h, minute: m, second: 0, of: now)!
            if d < now { d = cal.date(byAdding: .day, value: 1, to: d)! }
            return Result(date: d, hasTime: true)
        }
        return detectorFallback(raw, now: now, cal: cal)
    }

    // MARK: - ISO / absolute numeric

    private static func parseISO(_ s: String) -> Result? {
        let withTime = ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm"]
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        for fmt in withTime {
            f.dateFormat = fmt
            if let d = f.date(from: s) { return Result(date: d, hasTime: true) }
        }
        f.dateFormat = "yyyy-MM-dd"
        if let d = f.date(from: s) { return Result(date: d, hasTime: false) }
        return nil
    }

    // MARK: - "in 2 hours", "через 3 дня"

    private static func parseRelativeDuration(_ s: String, now: Date, cal: Calendar) -> Result? {
        guard let m = firstMatch(#"(?:^|\s)(?:in|через|en|za|tra|fra)\s+(\d+|an?|one|half\s+an?|пол)\s*([\p{L}]+)"#, s) else { return nil }
        let qty = m[1]
        let unit = m[2]
        var n = Int(qty) ?? 1
        var minutesExtra = 0
        if qty.hasPrefix("half") || qty == "пол" { n = 0; minutesExtra = 30 }
        let comps: (Calendar.Component, Bool)?
        switch true {
        case unit.hasPrefix("min") || unit.hasPrefix("мин") || unit.hasPrefix("хв") || unit.hasPrefix("minut"):
            comps = (.minute, true)
        case unit.hasPrefix("hour") || unit.hasPrefix("hr") || unit.hasPrefix("час") || unit.hasPrefix("годин") || unit.hasPrefix("hora") || unit.hasPrefix("godzin") || unit.hasPrefix("stund") || unit.hasPrefix("or"):
            comps = (.hour, true)
        case unit.hasPrefix("day") || unit.hasPrefix("дн") || unit.hasPrefix("ден") || unit.hasPrefix("дня") || unit.hasPrefix("día") || unit.hasPrefix("dni") || unit.hasPrefix("dzie") || unit.hasPrefix("tag") || unit.hasPrefix("giorn"):
            comps = (.day, false)
        case unit.hasPrefix("week") || unit.hasPrefix("недел") || unit.hasPrefix("тиж") || unit.hasPrefix("seman") || unit.hasPrefix("tydz") || unit.hasPrefix("tygod") || unit.hasPrefix("woche") || unit.hasPrefix("settiman"):
            comps = (.weekOfYear, false)
        case unit.hasPrefix("month") || unit.hasPrefix("месяц") || unit.hasPrefix("місяц") || unit.hasPrefix("mes") || unit.hasPrefix("miesi") || unit.hasPrefix("monat") || unit.hasPrefix("mes"):
            comps = (.month, false)
        default:
            comps = nil
        }
        guard let (component, timed) = comps else { return nil }
        if component == .hour && minutesExtra == 30 {
            return Result(date: cal.date(byAdding: .minute, value: 30, to: now)!, hasTime: true)
        }
        guard var d = cal.date(byAdding: component, value: n, to: now) else { return nil }
        if timed { return Result(date: d, hasTime: true) }
        if let (h, mm) = extractTime(s.replacingOccurrences(of: m[0], with: " ")) {
            d = cal.date(bySettingHour: h, minute: mm, second: 0, of: d)!
            return Result(date: d, hasTime: true)
        }
        return Result(date: cal.startOfDay(for: d), hasTime: false)
    }

    // MARK: - Day words

    private static let dayWords: [(String, Int)] = [
        // Longest first so "day after tomorrow" beats "tomorrow".
        ("the day after tomorrow", 2), ("day after tomorrow", 2), ("послезавтра", 2), ("післязавтра", 2),
        ("pasado mañana", 2), ("pojutrze", 2), ("übermorgen", 2), ("dopodomani", 2),
        ("tomorrow", 1), ("завтра", 1), ("mañana", 1), ("jutro", 1), ("morgen", 1), ("domani", 1),
        ("tonight", 0), ("today", 0), ("сегодня", 0), ("сьогодні", 0), ("hoy", 0), ("dzisiaj", 0), ("dziś", 0),
        ("heute", 0), ("oggi", 0), ("stasera", 0),
    ]

    private static func extractDayWord(_ s: String) -> (Int, String)? {
        for (word, offset) in dayWords {
            if let r = s.range(of: word) {
                var rest = s
                rest.replaceSubrange(r, with: " ")
                if word == "tonight" || word == "stasera", extractTime(rest) == nil {
                    rest += " 20:00 "
                }
                return (offset, rest)
            }
        }
        return nil
    }

    // MARK: - Weekdays (Calendar weekday numbers: 1 = Sunday)

    private static let weekdayStems: [(String, Int)] = [
        ("monday", 2), ("tuesday", 3), ("wednesday", 4), ("thursday", 5), ("friday", 6), ("saturday", 7), ("sunday", 1),
        ("понедельник", 2), ("вторник", 3), ("сред", 4), ("четверг", 5), ("пятниц", 6), ("суббот", 7), ("воскресень", 1),
        ("понеділ", 2), ("вівтор", 3), ("серед", 4), ("четвер", 5), ("п'ятниц", 6), ("пʼятниц", 6), ("субот", 7), ("неділ", 1),
        ("lunes", 2), ("martes", 3), ("miércoles", 4), ("miercoles", 4), ("jueves", 5), ("viernes", 6), ("sábado", 7), ("sabado", 7), ("domingo", 1),
        ("poniedział", 2), ("wtor", 3), ("środ", 4), ("czwart", 5), ("piąt", 6), ("sobot", 7), ("niedziel", 1),
        ("montag", 2), ("dienstag", 3), ("mittwoch", 4), ("donnerstag", 5), ("freitag", 6), ("samstag", 7), ("sonntag", 1),
        ("lunedì", 2), ("lunedi", 2), ("martedì", 3), ("martedi", 3), ("mercoledì", 4), ("mercoledi", 4), ("giovedì", 5), ("giovedi", 5),
        ("venerdì", 6), ("venerdi", 6), ("sabato", 7), ("domenica", 1),
        ("mon ", 2), ("tue ", 3), ("wed ", 4), ("thu ", 5), ("fri ", 6), ("sat ", 7), ("sun ", 1),
    ]

    private static func extractWeekday(_ s: String) -> (Int, String)? {
        for (stem, wd) in weekdayStems {
            guard let r = s.range(of: stem) else { continue }
            // Remove the whole word containing the stem.
            var start = r.lowerBound
            while start > s.startIndex, s[s.index(before: start)].isLetter { start = s.index(before: start) }
            var end = r.upperBound
            while end < s.endIndex, s[end].isLetter || s[end] == "'" { end = s.index(after: end) }
            var rest = s
            rest.replaceSubrange(start..<end, with: " ")
            return (wd, rest)
        }
        return nil
    }

    /// Nearest upcoming weekday strictly after today ("Friday" said on a Friday means next week).
    private static func nextWeekday(_ weekday: Int, after now: Date, cal: Calendar) -> Date {
        let today = cal.startOfDay(for: now)
        let current = cal.component(.weekday, from: today)
        var diff = (weekday - current + 7) % 7
        if diff == 0 { diff = 7 }
        return cal.date(byAdding: .day, value: diff, to: today)!
    }

    // MARK: - Month dates

    /// Prefixes; the word must stand next to a day number, so short stems are safe.
    private static let monthStems: [(String, Int)] = [
        // English
        ("jan", 1), ("feb", 2), ("mar", 3), ("apr", 4), ("may", 5), ("jun", 6), ("jul", 7), ("aug", 8),
        ("sep", 9), ("oct", 10), ("nov", 11), ("dec", 12),
        // Russian
        ("янв", 1), ("фев", 2), ("мар", 3), ("апр", 4), ("мая", 5), ("май", 5), ("июн", 6), ("июл", 7), ("авг", 8),
        ("сен", 9), ("окт", 10), ("ноя", 11), ("дек", 12),
        // Ukrainian
        ("січ", 1), ("лют", 2), ("бер", 3), ("кві", 4), ("тра", 5), ("чер", 6), ("лип", 7), ("сер", 8),
        ("вер", 9), ("жов", 10), ("лис", 11), ("гру", 12),
        // Spanish
        ("ene", 1), ("abr", 4), ("ago", 8), ("set", 9), ("dic", 12),
        // German
        ("mär", 3), ("mai", 5), ("okt", 10), ("dez", 12),
        // Polish
        ("sty", 1), ("lut", 2), ("kwi", 4), ("maj", 5), ("cze", 6), ("lip", 7), ("sie", 8), ("wrz", 9),
        ("paź", 10), ("lis", 11), ("gru", 12),
        // Italian
        ("gen", 1), ("mag", 5), ("giu", 6), ("lug", 7), ("ott", 10),
    ]

    private static func extractMonthDate(_ s: String, now: Date, cal: Calendar) -> (Date, String)? {
        // Numeric: 30.09, 30/09, 30.09.2026
        if let m = firstMatch(#"(?<![\d:])(\d{1,2})[./](\d{1,2})(?:[./](\d{2,4}))?(?![\d:])"#, s),
           let d = Int(m[1]), let mo = Int(m[2]), (1...31).contains(d), (1...12).contains(mo) {
            var year = m[3].isEmpty ? nil : Int(m[3])
            if let y = year, y < 100 { year = 2000 + y }
            if let date = makeDate(day: d, month: mo, year: year, now: now, cal: cal) {
                return (date, s.replacingOccurrences(of: m[0], with: " "))
            }
        }
        for (stem, month) in monthStems {
            // "30 сентября" / "september 30" / "30th of september"
            let stemPattern = NSRegularExpression.escapedPattern(for: stem)
            let patterns = [
                #"(?<![\d:])(\d{1,2})(?:st|nd|rd|th|\.)?\s+(?:of\s+|de\s+)?"# + stemPattern + #"[\p{L}]*"#,
                #"(?:^|\s)"# + stemPattern + #"[\p{L}]*\s+(\d{1,2})(?:st|nd|rd|th)?(?![\d:])"#,
            ]
            for p in patterns {
                if let m = firstMatch(p, s), let d = Int(m[1]), (1...31).contains(d),
                   let date = makeDate(day: d, month: month, year: nil, now: now, cal: cal) {
                    return (date, s.replacingOccurrences(of: m[0], with: " "))
                }
            }
        }
        return nil
    }

    private static func makeDate(day: Int, month: Int, year: Int?, now: Date, cal: Calendar) -> Date? {
        var comps = DateComponents()
        comps.day = day
        comps.month = month
        comps.year = year ?? cal.component(.year, from: now)
        guard var d = cal.date(from: comps) else { return nil }
        if year == nil, d < cal.startOfDay(for: now) {
            d = cal.date(byAdding: .year, value: 1, to: d)!
        }
        return d
    }

    // MARK: - Time of day

    static func extractTime(_ s: String) -> (Int, Int)? {
        // 15:00, 9.30, 3pm, 3:30 pm
        if let m = firstMatch(#"(?<![\d./])(\d{1,2})[:.](\d{2})\s*(a\.?m\.?|p\.?m\.?)?(?![\d./])"#, s),
           var h = Int(m[1]), let mm = Int(m[2]), mm < 60 {
            h = applyMeridiem(h, m[3])
            if h < 24 { return (h, mm) }
        }
        if let m = firstMatch(#"(?<![\d./])(\d{1,2})\s*(a\.?m\.?|p\.?m\.?)(?![\p{L}])"#, s), var h = Int(m[1]) {
            h = applyMeridiem(h, m[2])
            if h < 24 { return (h, 0) }
        }
        // "в 15", "at 3", "um 15", "alle 15", "o 15", "a las 15", "15 ч", "15 uhr", "15h"
        if let m = firstMatch(#"(?:^|\s)(?:at|в|во|о|об|um|alle|a\s+las|a\s+la|o\s+godz\.?|o|godz\.?)\s+(\d{1,2})(?![\d./])"#, s),
           let h = Int(m[1]), h < 24 {
            var hour = h
            if hour < 8, s.contains("вечер") || s.contains("evening") || s.contains("night") || s.contains("дня") {
                hour += 12
            }
            return (hour, 0)
        }
        if let m = firstMatch(#"(?<![\d./])(\d{1,2})\s*(?:h|ч|час|часов|часа|uhr|годин[аи]?)(?![\p{L}])"#, s),
           let h = Int(m[1]), h < 24 {
            return (h, 0)
        }
        let named: [(String, (Int, Int))] = [
            ("noon", (12, 0)), ("midday", (12, 0)), ("полдень", (12, 0)), ("полудні", (12, 0)), ("mediodía", (12, 0)),
            ("południe", (12, 0)), ("mittag", (12, 0)), ("mezzogiorno", (12, 0)), ("midnight", (0, 0)), ("полночь", (0, 0)),
            ("morning", (9, 0)), ("утром", (9, 0)), ("вранці", (9, 0)), ("зранку", (9, 0)), ("afternoon", (15, 0)),
            ("evening", (19, 0)), ("вечером", (19, 0)), ("ввечері", (19, 0)),
        ]
        for (word, t) in named where s.contains(word) { return t }
        return nil
    }

    private static func applyMeridiem(_ hour: Int, _ meridiem: String) -> Int {
        let m = meridiem.replacingOccurrences(of: ".", with: "")
        if m == "pm", hour < 12 { return hour + 12 }
        if m == "am", hour == 12 { return 0 }
        return hour
    }

    // MARK: - NSDataDetector fallback (English phrases)

    private static func detectorFallback(_ raw: String, now: Date, cal: Calendar) -> Result? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let range = NSRange(raw.startIndex..., in: raw)
        guard let match = detector.firstMatch(in: raw, options: [], range: range), let date = match.date else { return nil }
        let hasTime = extractTime(raw.lowercased()) != nil
        return Result(date: hasTime ? date : cal.startOfDay(for: date), hasTime: hasTime)
    }

    // MARK: - Regex helper

    /// Returns [whole match, group1, group2, …]; missing groups are "".
    private static func firstMatch(_ pattern: String, _ s: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        guard let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            guard let r = Range(m.range(at: i), in: s) else { return "" }
            return String(s[r])
        }
    }
}
