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
        VStack(spacing: 12) {
            // Month header
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                }

                Spacer()

                Text(monthYearString)
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)

            // Weekday headers
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
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
                            .frame(height: 44)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
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
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
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
        return photoManager.photosByDate[startOfDay] != nil
    }

    private func photoCount(for date: Date) -> Int {
        let startOfDay = calendar.startOfDay(for: date)
        return photoManager.photosByDate[startOfDay]?.count ?? 0
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
        VStack(spacing: 4) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 16))
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundColor(isSelected ? .white : (hasPhotos ? .primary : .secondary))
                .frame(height: 30)

            if hasPhotos {
                Circle()
                    .fill(isSelected ? Color.white : Color.blue)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(hasPhotos && !isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}
