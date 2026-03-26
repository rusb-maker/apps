import SwiftUI

struct StudyIntervalsSettingsView: View {
    @AppStorage("study_again_minutes") private var againMinutes = 0
    @AppStorage("study_hard_minutes") private var hardMinutes = 2
    @AppStorage("study_good_days") private var goodDays = 1
    @AppStorage("study_easy_days") private var easyDays = 2

    var body: some View {
        Form {
            Section {
                Stepper("Again: \(againMinutes)m", value: $againMinutes, in: 0...120)
                Stepper("Hard: \(hardMinutes)m", value: $hardMinutes, in: 0...120)
                Stepper("Good: \(goodDays)d", value: $goodDays, in: 1...60)
                Stepper("Easy: \(easyDays)d", value: $easyDays, in: 1...90)
            } footer: {
                Text("Base intervals for first review. Subsequent reviews scale with the ease factor.")
            }
        }
        .navigationTitle("Study Intervals")
    }
}
