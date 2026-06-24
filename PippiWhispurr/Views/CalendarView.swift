//
//  CalendarView.swift
//  PippiWhispurr
//

import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @Binding var selectedDate: Date?
    @Binding var isCollapsed: Bool
    var onRecordToday: () -> Void = {}

    @State private var currentMonth = Date()
    @State private var showingMonthPicker = false
    @State private var draftMonth = Calendar.current.component(.month, from: Date())
    @State private var draftYear = Calendar.current.component(.year, from: Date())

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            monthHeader
            if !isCollapsed {
                calendarGrid
                    .transition(.move(edge: .top).combined(with: .opacity))
                if photoCount(for: Date()) == 0 {
                    Button(action: onRecordToday) {
                        Label("Record today’s memory", systemImage: "camera.fill")
                            .font(.pippi(13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PippiOutlineButtonStyle())
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, isCollapsed ? 6 : 10)
        .background(Color.cream)
        .animation(.easeInOut(duration: 0.22), value: isCollapsed)
        .sheet(isPresented: $showingMonthPicker) {
            monthPickerSheet
        }
    }

    private var monthHeader: some View {
        HStack {
            if !isCollapsed {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                }
            }

            Spacer()

            Button {
                draftMonth = calendar.component(.month, from: currentMonth)
                draftYear = calendar.component(.year, from: currentMonth)
                showingMonthPicker = true
            } label: {
                HStack(spacing: 6) {
                    Text(monthYearString)
                        .font(.pippi(18, weight: .extraBold))
                    Image(systemName: "chevron.down")
                        .font(.caption2.bold())
                }
                .foregroundColor(.forestInk)
            }

            Spacer()

            if isCollapsed {
                Button {
                    isCollapsed = false
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                }
            } else {
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                }
            }
        }
        .foregroundColor(.forestInk)
        .padding(.horizontal)
    }

    private var calendarGrid: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.pippi(8, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(.forestInk.opacity(0.35))
                }
            }
            .padding(.horizontal, 8)

            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(daysInMonth, id: \.self) { date in
                    if let date {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(
                                date,
                                inSameDayAs: selectedDate ?? Date.distantPast
                            ),
                            isToday: calendar.isDateInToday(date),
                            hasPhotos: hasPhotos(for: date),
                            photoCount: photoCount(for: date)
                        )
                        .onTapGesture {
                            if hasPhotos(for: date) {
                                selectedDate = date
                            } else if calendar.isDateInToday(date) {
                                onRecordToday()
                            }
                        }
                    } else {
                        Color.clear.frame(height: 42)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private var monthPickerSheet: some View {
        NavigationView {
            HStack(spacing: 0) {
                Picker("Month", selection: $draftMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text(monthName(month)).tag(month)
                    }
                }
                .pickerStyle(.wheel)

                Picker("Year", selection: $draftYear) {
                    ForEach(availableYears, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle("Jump to Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingMonthPicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        currentMonth = calendar.date(
                            from: DateComponents(year: draftYear, month: draftMonth, day: 1)
                        ) ?? currentMonth
                        selectedDate = nil
                        isCollapsed = false
                        showingMonthPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var monthYearString: String {
        currentMonth.formatted(.dateTime.month(.wide).year())
    }

    private var weekdaySymbols: [String] {
        DateFormatter().veryShortWeekdaySymbols
    }

    private var availableYears: [Int] {
        let photoYears = photoManager.petPhotos.map { calendar.component(.year, from: $0.date) }
        let currentYear = calendar.component(.year, from: Date())
        let earliest = min(photoYears.min() ?? currentYear, currentYear - 10)
        return Array(earliest...currentYear)
    }

    private func monthName(_ month: Int) -> String {
        DateFormatter().monthSymbols[month - 1]
    }

    private var daysInMonth: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: currentMonth) else { return [] }
        let count = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 0
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday + 7 - calendar.firstWeekday) % 7
        var days = Array<Date?>(repeating: nil, count: leading)
        days += (1...count).compactMap {
            calendar.date(byAdding: .day, value: $0 - 1, to: interval.start)
        }
        return days
    }

    private func hasPhotos(for date: Date) -> Bool {
        photoCount(for: date) > 0
    }

    private func photoCount(for date: Date) -> Int {
        photoManager.filteredPhotosByDate[calendar.startOfDay(for: date)]?.count ?? 0
    }

    private func previousMonth() {
        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }

    private func nextMonth() {
        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
    }
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasPhotos: Bool
    let photoCount: Int

    private let calendar = Calendar.current

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(cellBackground)

            Text("\(calendar.component(.day, from: date))")
                .font(.pippi(12, weight: isSelected ? .extraBold : .regular))
                .foregroundColor(isSelected ? .cream : .forestInk)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if hasPhotos {
                Text(photoCount > 9 ? "9+" : "\(photoCount)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(isSelected ? .forestInk : .cream)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.honeyYellow : Color.forestInk)
                    .clipShape(Capsule())
                    .padding(2)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isToday ? Color.blobOrange : Color.clear, lineWidth: 2)
        }
        .frame(height: 42)
        .frame(maxWidth: .infinity)
    }

    private var cellBackground: Color {
        if isSelected { return .forestInk }
        if hasPhotos { return (photoCount >= 6 ? Color.honeyYellow : Color.mintSage).opacity(0.8) }
        if isToday { return .blobOrange.opacity(0.12) }
        return .clear
    }
}
