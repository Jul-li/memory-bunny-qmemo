import SwiftUI

struct TodoListEditorView: View {
    @EnvironmentObject private var store: MemoStore
    @Environment(\.dismiss) private var dismiss

    let memo: Memo?
    let navigationChrome: MemoEditorNavigationChrome

    @State private var title: String
    @State private var items: [MemoTodoItem]
    @State private var isPinned: Bool
    @State private var savedDraftMemoID: UUID?
    @State private var isCustomNavigationVisible = false
    @State private var isSaveConfirmationVisible = false
    @State private var isDeleteConfirmationPresented = false
    @State private var isReminderPickerPresented = false
    @State private var isReminderPermissionAlertPresented = false
    @State private var reminderAlertTitle = "无法开启提醒"
    @State private var reminderAlertMessage = "请在系统设置中允许记忆兔使用通知或闹钟权限，然后重新设置提醒时间。"
    @State private var reminderAlertShowsSettings = true
    @State private var reminderEditingItemID: UUID?
    @State private var reminderDraftDate = Date()
    @State private var reminderDraftIsUrgent = false
    @State private var shouldSkipPersistOnDisappear = false
    @FocusState private var focusedField: FocusField?

    private enum FocusField: Hashable {
        case title
        case item(UUID)
    }

    private var editorTopPadding: CGFloat {
        navigationChrome == .cardExpanded ? 76 : 18
    }

    private var nonemptyItems: [MemoTodoItem] {
        items.compactMap { item in
            let cleanText = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanText.isEmpty else { return nil }

            var storedItem = item
            storedItem.text = cleanText
            return storedItem
        }
    }

    private var hasEditableDraftContent: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !nonemptyItems.isEmpty
    }

    private var shouldShowMoreButton: Bool {
        memo != nil || hasEditableDraftContent
    }

    private var metadataText: String {
        let completedCount = nonemptyItems.filter(\.isCompleted).count
        return "\(nonemptyItems.count) 项｜已完成 \(completedCount) 项"
    }

    init(
        memo: Memo?,
        navigationChrome: MemoEditorNavigationChrome = .native
    ) {
        self.memo = memo
        self.navigationChrome = navigationChrome
        _title = State(initialValue: memo?.title ?? "")
        _items = State(initialValue: Self.initialItems(for: memo))
        _isPinned = State(initialValue: memo?.isPinned ?? false)
    }

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TextField("给这组待办起个名字", text: $title)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(Theme.Colors.text)
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .title)
                        .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)

                    Text(metadataText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.Colors.muted.opacity(0.72))
                        .padding(.top, 6)

                    VStack(spacing: 10) {
                        ForEach($items) { $item in
                            todoRow(item: $item)
                        }

                        Button {
                            appendItem(after: items.last?.id)
                        } label: {
                            Label("添加待办", systemImage: "plus")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.Colors.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("添加待办")
                    }
                    .padding(.top, 24)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 20)
                .padding(.top, navigationChrome == .cardExpanded ? editorTopPadding : 0)
                .padding(.bottom, 80)
            }
            .scrollIndicators(.hidden)
            .padding(.top, navigationChrome == .cardExpanded ? 0 : editorTopPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if isDeleteConfirmationPresented {
                DeleteConfirmationOverlay(
                    onCancel: {
                        withAnimation(.easeOut(duration: 0.18)) {
                            isDeleteConfirmationPresented = false
                        }
                    },
                    onConfirm: confirmDeleteOrDiscardDraft
                )
                .zIndex(10)
            }

            if navigationChrome == .cardExpanded {
                navigationGradient
                    .zIndex(2)
                customNavigationBar
                    .zIndex(3)
            }
        }
        .navigationTitle(memo == nil ? "新建待办" : "编辑待办")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isSaveConfirmationVisible {
                ToolbarItem(placement: .confirmationAction) {
                    saveConfirmationButton
                }
            }

            if shouldShowMoreButton {
                ToolbarItem(placement: .confirmationAction) {
                    moreMenu
                }
            }
        }
        .toolbar(navigationChrome == .cardExpanded ? .hidden : .visible, for: .navigationBar)
        .sheet(isPresented: $isReminderPickerPresented) {
            TodoReminderPickerView(
                reminderDate: $reminderDraftDate,
                isUrgent: $reminderDraftIsUrgent,
                hasExistingReminder: reminderEditingItem?.reminderAt != nil,
                onCancel: {
                    isReminderPickerPresented = false
                },
                onRemove: {
                    removeReminder()
                },
                onConfirm: {
                    confirmReminder()
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
        .alert(reminderAlertTitle, isPresented: $isReminderPermissionAlertPresented) {
            if reminderAlertShowsSettings {
                Button("前往设置") {
                    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("知道了", role: .cancel) {}
        } message: {
            Text(reminderAlertMessage)
        }
        .onAppear {
            guard navigationChrome == .cardExpanded else { return }

            isCustomNavigationVisible = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.24)) {
                    isCustomNavigationVisible = true
                }
            }
        }
        .onDisappear {
            persistDraftIfNeeded()
            isCustomNavigationVisible = false
        }
        .onChange(of: title) {
            showSaveConfirmation()
        }
        .onChange(of: items) {
            showSaveConfirmation()
        }
        .onChange(of: isPinned) {
            showSaveConfirmation()
            persistExistingMemoIfNeeded()
        }
        .onChange(of: focusedField) { _, field in
            if field != nil {
                showSaveConfirmation()
            }
        }
    }

    private func todoRow(item: Binding<MemoTodoItem>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                item.wrappedValue.isCompleted.toggle()
            } label: {
                Image(systemName: item.wrappedValue.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        item.wrappedValue.isCompleted
                            ? Theme.Colors.accentStrong
                            : Theme.Colors.muted
                    )
                    .frame(width: 32, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.wrappedValue.isCompleted ? "标记为未完成" : "标记为已完成")

            VStack(alignment: .leading, spacing: 0) {
                TextField("输入待办事项", text: item.text, axis: .vertical)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Theme.Colors.text)
                    .strikethrough(item.wrappedValue.isCompleted, color: Theme.Colors.muted)
                    .lineLimit(1...)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 11)
                    .focused($focusedField, equals: .item(item.wrappedValue.id))
                    .submitLabel(.next)
                    .onSubmit {
                        appendItem(after: item.wrappedValue.id)
                    }
                    .accessibilityLabel("待办事项")

                if let reminderAt = item.wrappedValue.reminderAt {
                    Button {
                        presentReminderPicker(for: item.wrappedValue.id)
                    } label: {
                        TimelineView(.periodic(from: .now, by: 30)) { timeline in
                            Label(
                                reminderAt.formatted(date: .abbreviated, time: .shortened),
                                systemImage: "bell.fill"
                            )
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(
                                reminderAt > timeline.date
                                    ? Theme.Colors.accentStrong
                                    : Theme.Colors.muted
                            )
                            .padding(.bottom, 8)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("修改提醒时间")
                }
            }

            let isEditingItem = focusedField == .item(item.wrappedValue.id)

            Button {
                presentReminderPicker(for: item.wrappedValue.id)
            } label: {
                Image(systemName: item.wrappedValue.reminderAt == nil ? "bell" : "bell.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        item.wrappedValue.reminderAt == nil
                            ? Theme.Colors.muted
                            : Theme.Colors.accentStrong
                    )
                    .frame(width: 32, height: 44)
            }
            .buttonStyle(.plain)
            .opacity(isEditingItem ? 1 : 0)
            .allowsHitTesting(isEditingItem)
            .accessibilityHidden(!isEditingItem)
            .accessibilityLabel(item.wrappedValue.reminderAt == nil ? "设置提醒" : "修改提醒")
        }
        .frame(minHeight: 48)
    }

    private var customNavigationBar: some View {
        VStack {
            HStack(spacing: 14) {
                navigationButton(systemName: "chevron.left", accessibilityLabel: "返回") {
                    dismiss()
                }

                Spacer()

                if isSaveConfirmationVisible {
                    navigationButton(systemName: "checkmark", accessibilityLabel: "确认保存") {
                        confirmSave()
                    }
                    .transition(.scale(scale: 0.86).combined(with: .opacity))
                }

                if shouldShowMoreButton {
                    moreMenu
                }
            }
            .animation(.spring(response: 0.24, dampingFraction: 0.86), value: isSaveConfirmationVisible)
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 10)

            Spacer()
        }
        .opacity(isCustomNavigationVisible ? 1 : 0)
        .offset(y: isCustomNavigationVisible ? 0 : -34)
        .allowsHitTesting(isCustomNavigationVisible)
    }

    private func navigationButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.Colors.text)
                .frame(width: 44, height: 44)
                .background(
                    QMemoGlassBackground(
                        shape: Circle(),
                        tintOpacity: 0.20,
                        fallbackFillOpacity: 0.84,
                        strokeOpacity: 0.70,
                        lineOpacity: 0.10
                    )
                )
                .shadow(color: Theme.Colors.shadow.opacity(0.10), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var moreMenu: some View {
        EditorMoreMenuButton(
            isPinned: isPinned,
            onTogglePin: {
                isPinned.toggle()
            },
            onDelete: {
                withAnimation(.easeOut(duration: 0.18)) {
                    isDeleteConfirmationPresented = true
                }
            }
        )
        .frame(width: 44, height: 44)
    }

    private var saveConfirmationButton: some View {
        Button {
            confirmSave()
        } label: {
            Image(systemName: "checkmark")
        }
        .accessibilityLabel("确认保存")
    }

    private var navigationGradient: some View {
        VStack {
            ZStack {
                qMemoChromeMaterial(
                    tintOpacity: 0.16,
                    mask: LinearGradient(
                        colors: [.black, .black.opacity(0.72), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LinearGradient(
                    colors: [
                        Theme.Colors.background.opacity(1),
                        Theme.Colors.background.opacity(0.72),
                        Theme.Colors.background.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(height: 150)
            .ignoresSafeArea(edges: .top)

            Spacer()
        }
        .allowsHitTesting(false)
    }

    private func appendItem(after itemID: UUID?) {
        let newItem = MemoTodoItem()

        if let itemID, let index = items.firstIndex(where: { $0.id == itemID }) {
            items.insert(newItem, at: index + 1)
        } else {
            items.append(newItem)
        }

        DispatchQueue.main.async {
            focusedField = .item(newItem.id)
        }
    }

    private var reminderEditingItem: MemoTodoItem? {
        guard let reminderEditingItemID else { return nil }
        return items.first { $0.id == reminderEditingItemID }
    }

    private func presentReminderPicker(for itemID: UUID) {
        focusedField = nil
        reminderEditingItemID = itemID
        reminderDraftDate = items.first(where: { $0.id == itemID })?.reminderAt
            ?? Self.defaultReminderDate()
        reminderDraftIsUrgent = items.first(where: { $0.id == itemID })?.isUrgent ?? false
        isReminderPickerPresented = true
    }

    private func confirmReminder() {
        guard let reminderEditingItemID else { return }

        Task {
            let isUrgent = reminderDraftIsUrgent
            let isAuthorized = if reminderDraftIsUrgent {
                await TodoReminderManager.shared.requestUrgentAuthorizationIfNeeded()
            } else {
                await TodoReminderManager.shared.requestAuthorizationIfNeeded()
            }
            let schedulingContext = await MainActor.run { () -> (UUID, String, [MemoTodoItem])? in
                guard isAuthorized else {
                    isReminderPickerPresented = false
                    reminderAlertTitle = "无法开启提醒"
                    reminderAlertMessage = "请在系统设置中允许记忆兔使用通知或闹钟权限，然后重新设置提醒时间。"
                    reminderAlertShowsSettings = true
                    isReminderPermissionAlertPresented = true
                    return nil
                }

                guard let index = items.firstIndex(where: { $0.id == reminderEditingItemID }) else {
                    isReminderPickerPresented = false
                    return nil
                }

                items[index].reminderAt = reminderDraftDate
                items[index].isUrgent = reminderDraftIsUrgent
                guard let storedMemo = persistDraftIfNeeded(shouldSynchronizeReminders: false) else {
                    isReminderPickerPresented = false
                    return nil
                }
                return (storedMemo.id, storedMemo.title, items)
            }

            guard let schedulingContext else { return }
            let report = await TodoReminderManager.shared.synchronize(
                memoID: schedulingContext.0,
                title: schedulingContext.1,
                items: schedulingContext.2
            )

            await MainActor.run {
                isReminderPickerPresented = false

                guard isUrgent, #available(iOS 26.0, *) else { return }
                guard !report.systemAlarmWasScheduled(for: reminderEditingItemID) else { return }

                let reason = report.failedSystemAlarms[reminderEditingItemID]
                    ?? "系统没有返回对应的闹钟记录"
                reminderAlertTitle = "系统闹钟设置失败"
                reminderAlertMessage = "\(reason)。提醒时间已保留，并已尝试改用普通通知。"
                reminderAlertShowsSettings = false
                isReminderPermissionAlertPresented = true
            }
        }
    }

    private func removeReminder() {
        guard
            let reminderEditingItemID,
            let index = items.firstIndex(where: { $0.id == reminderEditingItemID })
        else {
            isReminderPickerPresented = false
            return
        }

        items[index].reminderAt = nil
        items[index].isUrgent = false
        isReminderPickerPresented = false
    }

    private func confirmSave() {
        focusedField = nil
        persistDraftIfNeeded()
        withAnimation(.spring(response: 0.20, dampingFraction: 0.88)) {
            isSaveConfirmationVisible = false
        }
    }

    @discardableResult
    private func persistDraftIfNeeded(
        shouldSynchronizeReminders: Bool = true
    ) -> Memo? {
        guard !shouldSkipPersistOnDisappear else { return nil }
        guard memo != nil || hasEditableDraftContent else { return nil }

        if editableStoredMemo() != nil {
            return persistExistingMemoIfNeeded(
                shouldSynchronizeReminders: shouldSynchronizeReminders
            )
        } else {
            return createDraftMemoIfNeeded(
                shouldSynchronizeReminders: shouldSynchronizeReminders
            )
        }
    }

    private func createDraftMemoIfNeeded(
        shouldSynchronizeReminders: Bool = true
    ) -> Memo? {
        guard memo == nil, hasEditableDraftContent else { return nil }

        let storedItems = nonemptyItems
        let createdMemo = store.create(
            title: storedTitle,
            content: Self.contentSummary(for: storedItems),
            category: .todo,
            isPinned: isPinned,
            todoItems: storedItems
        )
        savedDraftMemoID = createdMemo.id
        if shouldSynchronizeReminders {
            synchronizeReminders(memoID: createdMemo.id, title: createdMemo.title, items: items)
        }
        return createdMemo
    }

    @discardableResult
    private func persistExistingMemoIfNeeded(
        shouldSynchronizeReminders: Bool = true
    ) -> Memo? {
        guard !shouldSkipPersistOnDisappear, let storedMemo = editableStoredMemo() else {
            return nil
        }

        let storedItems = nonemptyItems
        let storedContent = Self.contentSummary(for: storedItems)
        let hasChanges =
            storedTitle != storedMemo.title
                || storedContent != storedMemo.content
                || isPinned != storedMemo.isPinned
                || storedItems != storedMemo.todoItems

        guard hasChanges else {
            if shouldSynchronizeReminders {
                synchronizeReminders(memoID: storedMemo.id, title: storedMemo.title, items: items)
            }
            return storedMemo
        }

        store.update(
            storedMemo,
            title: storedTitle,
            content: storedContent,
            richContentData: nil,
            isPinned: isPinned,
            stickers: [],
            todoItems: storedItems
        )
        if shouldSynchronizeReminders {
            synchronizeReminders(memoID: storedMemo.id, title: storedTitle, items: items)
        }
        return editableStoredMemo()
    }

    private var storedTitle: String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanTitle.isEmpty ? "未命名待办" : cleanTitle
    }

    private func editableStoredMemo() -> Memo? {
        if let memo {
            return store.memos.first { $0.id == memo.id } ?? memo
        }

        guard let savedDraftMemoID else { return nil }
        return store.memos.first { $0.id == savedDraftMemoID }
    }

    private func confirmDeleteOrDiscardDraft() {
        withAnimation(.easeOut(duration: 0.18)) {
            isDeleteConfirmationPresented = false
        }
        shouldSkipPersistOnDisappear = true
        if let storedMemo = editableStoredMemo() {
            store.delete(storedMemo)
        }
        dismiss()
    }

    private func showSaveConfirmation() {
        guard !isSaveConfirmationVisible else { return }

        withAnimation(.spring(response: 0.20, dampingFraction: 0.88)) {
            isSaveConfirmationVisible = true
        }
    }

    private static func initialItems(for memo: Memo?) -> [MemoTodoItem] {
        guard let memo else {
            return [MemoTodoItem()]
        }

        if !memo.todoItems.isEmpty {
            return memo.todoItems
        }

        let legacyItems = memo.content
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> MemoTodoItem? in
                let original = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !original.isEmpty else { return nil }

                let isCompleted = original.hasPrefix("☑") || original.hasPrefix("✅")
                let cleaned = original
                    .replacingOccurrences(of: "□", with: "")
                    .replacingOccurrences(of: "☐", with: "")
                    .replacingOccurrences(of: "☑", with: "")
                    .replacingOccurrences(of: "✅", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else { return nil }

                return MemoTodoItem(text: cleaned, isCompleted: isCompleted)
            }

        return legacyItems.isEmpty ? [MemoTodoItem()] : legacyItems
    }

    private static func contentSummary(for items: [MemoTodoItem]) -> String {
        items
            .map { "\($0.isCompleted ? "☑" : "□") \($0.text)" }
            .joined(separator: "\n")
    }

    private func synchronizeReminders(memoID: UUID, title: String, items: [MemoTodoItem]) {
        Task {
            await TodoReminderManager.shared.synchronize(
                memoID: memoID,
                title: title,
                items: items
            )
        }
    }

    private static func defaultReminderDate() -> Date {
        let calendar = Calendar.current
        let nextHour = calendar.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        return calendar.date(
            bySetting: .minute,
            value: 0,
            of: nextHour
        ) ?? nextHour
    }
}

private struct TodoReminderPickerView: View {
    private enum ExpandedSection {
        case date
        case time
    }

    @Binding var reminderDate: Date
    @Binding var isUrgent: Bool

    let hasExistingReminder: Bool
    let onCancel: () -> Void
    let onRemove: () -> Void
    let onConfirm: () -> Void

    @State private var isDateEnabled: Bool
    @State private var isTimeEnabled: Bool
    @State private var expandedSection: ExpandedSection?

    init(
        reminderDate: Binding<Date>,
        isUrgent: Binding<Bool>,
        hasExistingReminder: Bool,
        onCancel: @escaping () -> Void,
        onRemove: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        _reminderDate = reminderDate
        _isUrgent = isUrgent
        self.hasExistingReminder = hasExistingReminder
        self.onCancel = onCancel
        self.onRemove = onRemove
        self.onConfirm = onConfirm
        _isDateEnabled = State(initialValue: hasExistingReminder)
        _isTimeEnabled = State(initialValue: hasExistingReminder)
        _expandedSection = State(initialValue: nil)
    }

    private var dateIsEnabled: Binding<Bool> {
        Binding(
            get: { isDateEnabled },
            set: { isEnabled in
                withAnimation(.easeInOut(duration: 0.20)) {
                    isDateEnabled = isEnabled
                    if isEnabled {
                        if reminderDate < Date() {
                            reminderDate = Self.defaultReminderDate()
                        }
                        expandedSection = .date
                    } else {
                        isTimeEnabled = false
                        isUrgent = false
                        expandedSection = nil
                    }
                }
            }
        )
    }

    private var timeIsEnabled: Binding<Bool> {
        Binding(
            get: { isTimeEnabled },
            set: { isEnabled in
                withAnimation(.easeInOut(duration: 0.20)) {
                    isTimeEnabled = isEnabled
                    if isEnabled {
                        isDateEnabled = true
                        if reminderDate < Date() {
                            reminderDate = Self.defaultReminderDate()
                        }
                        expandedSection = .time
                    } else {
                        isUrgent = false
                        expandedSection = isDateEnabled ? .date : nil
                    }
                }
            }
        )
    }

    private var urgentIsEnabled: Binding<Bool> {
        Binding(
            get: { isUrgent },
            set: { isEnabled in
                withAnimation(.easeInOut(duration: 0.20)) {
                    isUrgent = isEnabled
                    guard isEnabled else { return }

                    isDateEnabled = true
                    isTimeEnabled = true
                    if reminderDate < Date() {
                        reminderDate = Self.defaultReminderDate()
                    }
                    expandedSection = .time
                }
            }
        )
    }

    private var canConfirm: Bool {
        isDateEnabled && isTimeEnabled && reminderDate > Date()
    }

    private static func defaultReminderDate() -> Date {
        let calendar = Calendar.current
        let nextHour = calendar.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        return calendar.date(bySetting: .minute, value: 0, of: nextHour) ?? nextHour
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("时间与日期")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        reminderRow(
                            title: "日期",
                            value: reminderDate.formatted(
                                .dateTime
                                    .year()
                                    .month(.wide)
                                    .day()
                                    .weekday(.wide)
                            ),
                            isEnabled: dateIsEnabled,
                            isExpanded: expandedSection == .date,
                            onHeaderTap: {
                                guard isDateEnabled else { return }
                                withAnimation(.easeInOut(duration: 0.20)) {
                                    expandedSection = .date
                                }
                            }
                        ) {
                            DatePicker(
                                "提醒日期",
                                selection: $reminderDate,
                                in: Calendar.current.startOfDay(for: Date())...,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                        }

                        Divider()
                            .padding(.leading, 16)

                        reminderRow(
                            title: "时间",
                            value: reminderDate.formatted(date: .omitted, time: .shortened),
                            isEnabled: timeIsEnabled,
                            isExpanded: expandedSection == .time,
                            onHeaderTap: {
                                guard isTimeEnabled else { return }
                                withAnimation(.easeInOut(duration: 0.20)) {
                                    expandedSection = .time
                                }
                            }
                        ) {
                            DatePicker(
                                "提醒时间",
                                selection: $reminderDate,
                                displayedComponents: [.hourAndMinute]
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipped()
                        }

                        Divider()
                            .padding(.leading, 16)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("紧急")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)

                                Text("将此提醒事项标记为紧急以设定闹钟")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 12)

                            Toggle("", isOn: urgentIsEnabled)
                                .labelsHidden()
                        }
                        .frame(minHeight: 66)
                        .padding(.horizontal, 16)
                    }
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if isDateEnabled && isTimeEnabled && reminderDate <= Date() {
                        Text("提醒时间需要晚于当前时间")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    if hasExistingReminder {
                        Button("移除提醒", role: .destructive) {
                            onRemove()
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(.background, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("设置提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        onConfirm()
                    }
                    .disabled(!canConfirm)
                }
            }
        }
    }

    private func reminderRow<Content: View>(
        title: String,
        value: String,
        isEnabled: Binding<Bool>,
        isExpanded: Bool,
        onHeaderTap: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(value)
                        .font(.footnote)
                        .foregroundStyle(isEnabled.wrappedValue ? .secondary : .tertiary)
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onHeaderTap)

                Spacer(minLength: 12)

                Toggle("", isOn: isEnabled)
                    .labelsHidden()
            }
            .frame(minHeight: 56)
            .padding(.horizontal, 16)

            if isExpanded {
                Divider()
                    .padding(.leading, 16)

                content()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.20), value: isExpanded)
    }
}
