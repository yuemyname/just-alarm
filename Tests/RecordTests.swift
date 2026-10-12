import Foundation

@main struct RecordTests {
    static func main() throws {
        // Old records include an extra protection field; existing schedules must survive.
        let legacy = Data("""
        [{"id":"63DE9A02-45B5-48F1-91AF-649102C889E1","hour":7,"minute":30,"title":"출근","weekdays":[2,3,4,5,6],"isProtected":true,"isEnabled":true}]
        """.utf8)
        let records = try JSONDecoder().decode([AlarmRecord].self, from: legacy)
        precondition(records.count == 1 && records[0].timeText == "07:30")
        precondition(records[0].title == "출근" && records[0].isEnabled)
        precondition(records[0].repeatText(in: .korean) == "평일")
        let data = try JSONEncoder().encode(records)
        precondition(!String(decoding: data, as: UTF8.self).contains("isProtected"))
        let restored = try JSONDecoder().decode([AlarmRecord].self, from: data)
        precondition(restored == records)
        print("PASS: existing alarms migrate without losing time, title, recurrence, or enabled state")
    }
}
