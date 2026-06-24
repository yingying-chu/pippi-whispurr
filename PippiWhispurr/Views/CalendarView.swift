//
//  CalendarView.swift
//  PippiWhispurr
//
//  Calendar view showing days with pet photos
//

import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @Binding var selectedDate: Date?
    @State private var currentMonth = Date()

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            // Month header
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.forestInk)
                }

                Spacer()

                Text(monthYearString)
                    .font(.pippi(18, weight: .extraBold))
                    .foregroundColor(.forestInk)

                Spacer()

                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.forestInk)
                }
            }
            .padding(.horizontal)

            // Weekday headers
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.pippi(8, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(.forestInk.opacity(0.35))
                }
            }
            .padding(.horizontal, 8)

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(daysInMonth, id: \.self) { date in
                    if let date = date {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate ?? Date.distantPast),
                            hasPhotos: hasPhotos(for: date),
                            photoCount: photoCount(for: date)
                        )
                        .onTapGesture {
                            if hasPhotos(for: date) {
                                selectedDate = date
                            }
                        }
                    } else {
                        Color.clear
                            .frame(height: 36)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 10)
        .background(Color.cream)
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        return formatter.veryShortWeekdaySymbols
    }

    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return []
        }

        var days: [Date?] = []
        let numberOfDays = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 0

        // Get first day of month
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let firstWeekdayIndex = (firstWeekday + 7 - calendar.firstWeekday) % 7

        // Add empty cells for days before month starts
        for _ in 0..<firstWeekdayIndex {
            days.append(nil)
        }

        // Add all days in month
        for day in 1...numberOfDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) {
                days.append(date)
            }
        }

        return days
    }

    private func hasPhotos(for date: Date) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        return photoManager.filteredPhotosByDate[startOfDay] != nil
    }

    private func photoCount(for date: Date) -> Int {
        let startOfDay = calendar.startOfDay(for: date)
        return photoManager.filteredPhotosByDate[startOfDay]?.count ?? 0
    }

    private func previousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    private func nextMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
        }
    }
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let hasPhotos: Bool
    let photoCount: Int

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 1) {
            Text("\(calendar.component(.day, from: date))")
                .font(.pippi(12, weight: isSelected ? .extraBold : .regular))
                .foregroundColor(isSelected ? .cream : .forestInk)
                .frame(width: 30, height: 30)
                .background(isSelected ? Color.forestInk : Color.clear)
                .clipShape(Circle())

            if hasPhotos && !isSelected {
                Circle()
                    .fill(markerColor)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(height: 36)
        .frame(maxWidth: .infinity)
    }

    private var markerColor: Color {
        switch calendar.component(.day, from: date) % 3 {
        case 0: return .honeyYellow
        case 1: return .mintSage
        default: return .stickyLavender
        }
    }
}
