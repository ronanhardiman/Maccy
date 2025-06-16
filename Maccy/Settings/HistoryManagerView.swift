import SwiftUI
import Defaults
import AppKit

/**
 * 历史记录管理窗口控制器
 * 用于显示可调整大小的历史记录管理窗口
 */
class HistoryManagerWindowController: NSWindowController {
    private var historyRef: History
    
    /**
     * 创建一个新的历史记录管理窗口控制器
     * @param history 历史记录对象
     */
    init(history: History) {
        self.historyRef = history
        
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = NSLocalizedString("HistoryManager", tableName: "GeneralSettings", comment: "")
        window.center()
        window.minSize = NSSize(width: 500, height: 300) // 设置最小窗口大小
        
        super.init(window: window)
        
        // 在初始化完成后设置内容视图
        setupContentView()
    }
    
    /**
     * 设置窗口内容视图
     */
    private func setupContentView() {
        // 创建内容视图，传入窗口控制器引用
        let contentView = HistoryManagerView(history: historyRef, windowController: self)
            .ignoresSafeArea() // 忽略安全区域以使用整个窗口
        
        // 设置窗口的内容视图
        window?.contentView = NSHostingView(rootView: contentView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /**
     * 显示窗口并使其成为按键窗口
     */
    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/**
 * 历史记录管理视图
 * 用于在偏好设置中显示和管理剪贴板历史记录
 */
struct HistoryManagerView: View {
    var history: History
    var windowController: HistoryManagerWindowController?
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchQuery = ""
    @State private var selectedItem: HistoryItemDecorator?
    @State private var showConfirmDeleteAlert = false
    @State private var showConfirmClearAlert = false
    @State private var scrollTarget: UUID?
    @State private var isKeyboardNavigating = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            TitleBarView(windowController: windowController, dismiss: dismiss)
            
            // 搜索栏
            SearchBarView(searchQuery: $searchQuery, onSubmit: selectFirstItem)
            
            // 历史记录内容
            HistoryContentView(
                history: history,
                searchQuery: searchQuery,
                selectedItem: $selectedItem,
                scrollTarget: $scrollTarget,
                onNavigateUp: navigateUp,
                onNavigateDown: navigateDown,
                onDeleteItem: deleteSelectedItem,
                onCopyItem: copySelectedItem
            )
            .padding([.horizontal, .bottom])
            
            // 底部操作按钮
            ActionButtonsView(
                windowController: windowController,
                dismiss: dismiss,
                selectedItem: selectedItem,
                onDeleteItem: deleteSelectedItem,
                onClearHistory: { showConfirmClearAlert = true }
            )
        }
        .frame(minWidth: 600, minHeight: 400)
        .alert(NSLocalizedString("ClearHistoryConfirmation", tableName: "GeneralSettings", comment: ""), isPresented: $showConfirmClearAlert) {
            Button(NSLocalizedString("Cancel", tableName: "GeneralSettings", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("ClearUnpinned", tableName: "GeneralSettings", comment: ""), role: .destructive) {
                Task { await history.clear() }
            }
            Button(NSLocalizedString("ClearAll", tableName: "GeneralSettings", comment: ""), role: .destructive) {
                Task { await history.clearAll() }
            }
        } message: {
            Text(NSLocalizedString("ClearHistoryMessage", tableName: "GeneralSettings", comment: ""))
        }
    }
    
    /**
     * 选择第一个项目
     */
    private func selectFirstItem() {
        let pinned = history.all.filter(\.isPinned)
        let unpinned = history.all.filter { !$0.isPinned }
        
        let filteredPinned = searchQuery.isEmpty ? 
            pinned : 
            pinned.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
        
        let filteredUnpinned = searchQuery.isEmpty ? 
            unpinned : 
            unpinned.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
        
        if let firstItem = filteredPinned.first ?? filteredUnpinned.first {
            selectedItem = firstItem
            scrollTarget = firstItem.id
        }
    }
    
    /**
     * 删除选中的项目
     */
    private func deleteSelectedItem() {
        if let item = selectedItem {
            Task {
                await history.delete(item)
                self.selectedItem = nil
            }
        }
    }
    
    /**
     * 复制选中的项目
     */
    private func copySelectedItem() {
        if let item = selectedItem {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.title, forType: .string)
        }
    }
    
    /**
     * 在新窗口中显示历史记录管理器
     * @param history 历史记录对象
     */
    static func showInWindow(history: History) {
        let windowController = HistoryManagerWindowController(history: history)
        windowController.show()
    }
    
    /**
     * 向上导航选择项目
     */
    private func navigateUp() {
        isKeyboardNavigating = true
        
        let pinned = history.all.filter(\.isPinned)
        let unpinned = history.all.filter { !$0.isPinned }
        
        let filteredPinned = searchQuery.isEmpty ? 
            pinned : 
            pinned.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
        
        let filteredUnpinned = searchQuery.isEmpty ? 
            unpinned : 
            unpinned.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
        
        let allItems = filteredPinned + filteredUnpinned
        let allItemsIds = allItems.map(\.id)
        
        if let selectedItem = selectedItem, let currentIndex = allItemsIds.firstIndex(of: selectedItem.id) {
            if currentIndex > 0 {
                let targetIndex = currentIndex - 1
                self.selectedItem = allItems[targetIndex]
                scrollTarget = allItems[targetIndex].id
            }
        } else if !allItems.isEmpty {
            // 如果没有选中项目，选择最后一个
            self.selectedItem = allItems.last
            scrollTarget = allItems.last!.id
        }
    }
    
    /**
     * 向下导航选择项目
     */
    private func navigateDown() {
        isKeyboardNavigating = true
        
        let pinned = history.all.filter(\.isPinned)
        let unpinned = history.all.filter { !$0.isPinned }
        
        let filteredPinned = searchQuery.isEmpty ? 
            pinned : 
            pinned.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
        
        let filteredUnpinned = searchQuery.isEmpty ? 
            unpinned : 
            unpinned.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
        
        let allItems = filteredPinned + filteredUnpinned
        let allItemsIds = allItems.map(\.id)
        
        if let selectedItem = selectedItem, let currentIndex = allItemsIds.firstIndex(of: selectedItem.id) {
            if currentIndex < allItems.count - 1 {
                let targetIndex = currentIndex + 1
                self.selectedItem = allItems[targetIndex]
                scrollTarget = allItems[targetIndex].id
            }
        } else if !allItems.isEmpty {
            // 如果没有选中项目，选择第一个
            self.selectedItem = allItems.first
            scrollTarget = allItems.first!.id
        }
    }
}

/**
 * 标题栏视图
 */
struct TitleBarView: View {
    var windowController: HistoryManagerWindowController?
    var dismiss: DismissAction
    
    var body: some View {
        HStack {
            Text(NSLocalizedString("HistoryManager", tableName: "GeneralSettings", comment: ""))
                .font(.headline)
            
            Spacer()
            
            Button(action: {
                if let windowController = windowController {
                    windowController.close()
                } else {
                    dismiss()
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .imageScale(.large)
            }
            .buttonStyle(.borderless)
        }
        .padding()
    }
}

/**
 * 搜索栏视图
 */
struct SearchBarView: View {
    @Binding var searchQuery: String
    var onSubmit: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(NSLocalizedString("SearchHistory", tableName: "GeneralSettings", comment: ""), text: $searchQuery)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit(onSubmit)
            
            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding([.horizontal])
    }
}

/**
 * 历史记录内容视图
 */
struct HistoryContentView: View {
    var history: History
    var searchQuery: String
    @Binding var selectedItem: HistoryItemDecorator?
    @Binding var scrollTarget: UUID?
    var onNavigateUp: () -> Void
    var onNavigateDown: () -> Void
    var onDeleteItem: () -> Void
    var onCopyItem: () -> Void
    
    private var pinnedItems: [HistoryItemDecorator] {
        searchQuery.isEmpty ?
            history.all.filter(\.isPinned) :
            history.all.filter { $0.isPinned && $0.title.localizedCaseInsensitiveContains(searchQuery) }
    }
    
    private var unpinnedItems: [HistoryItemDecorator] {
        searchQuery.isEmpty ?
            history.all.filter { !$0.isPinned } :
            history.all.filter { !$0.isPinned && $0.title.localizedCaseInsensitiveContains(searchQuery) }
    }
    
    private var showPinsSeparator: Bool {
        !pinnedItems.isEmpty && !unpinnedItems.isEmpty
    }
    
    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 0) {
                    // 固定项目
                    PinnedItemsView(
                        items: pinnedItems,
                        selectedItem: $selectedItem,
                        history: history
                    )
                    
                    // 分隔符
                    if showPinsSeparator {
                        Divider()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                    }
                    
                    // 非固定项目
                    UnpinnedItemsView(
                        items: unpinnedItems,
                        selectedItem: $selectedItem,
                        history: history,
                        showHeader: !pinnedItems.isEmpty
                    )
                    
                    // 空状态
                    if pinnedItems.isEmpty && unpinnedItems.isEmpty {
                        EmptyStateView()
                    }
                    
                    // 导航帮助器
                    NavigationHelperView(
                        scrollTarget: $scrollTarget,
                        selectedItem: $selectedItem,
                        pinnedItems: pinnedItems,
                        unpinnedItems: unpinnedItems,
                        proxy: proxy,
                        onNavigateUp: onNavigateUp,
                        onNavigateDown: onNavigateDown,
                        onCopyItem: onCopyItem,
                        onDeleteItem: onDeleteItem
                    )
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 1)
        )
    }
}

/**
 * 固定项目视图
 */
struct PinnedItemsView: View {
    var items: [HistoryItemDecorator]
    @Binding var selectedItem: HistoryItemDecorator?
    var history: History
    
    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading) {
                Text(NSLocalizedString("PinnedItems", tableName: "GeneralSettings", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding([.horizontal, .top])
                
                ItemsList(items: items, selectedItem: $selectedItem, history: history)
            }
        }
    }
}

/**
 * 非固定项目视图
 */
struct UnpinnedItemsView: View {
    var items: [HistoryItemDecorator]
    @Binding var selectedItem: HistoryItemDecorator?
    var history: History
    var showHeader: Bool
    
    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading) {
                if showHeader {
                    Text(NSLocalizedString("UnpinnedItems", tableName: "GeneralSettings", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding([.horizontal, .top])
                }
                
                ItemsList(items: items, selectedItem: $selectedItem, history: history)
            }
        }
    }
}

/**
 * 项目列表视图
 */
struct ItemsList: View {
    var items: [HistoryItemDecorator]
    @Binding var selectedItem: HistoryItemDecorator?
    var history: History
    
    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HistoryItemRow(item: item, index: index, history: history)
                    .tag(item.id)
                    .background(selectedItem?.id == item.id ? Color.accentColor.opacity(0.25) : Color.clear)
                    .cornerRadius(4)
                    .onTapGesture {
                        selectedItem = item
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
            }
        }
    }
}

/**
 * 空状态视图
 */
struct EmptyStateView: View {
    var body: some View {
        VStack {
            Spacer()
            Text(NSLocalizedString("NoItemsFound", tableName: "GeneralSettings", comment: "没有找到相关历史记录"))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(height: 200)
    }
}

/**
 * 导航辅助视图
 */
struct NavigationHelperView: View {
    @Binding var scrollTarget: UUID?
    @Binding var selectedItem: HistoryItemDecorator?
    var pinnedItems: [HistoryItemDecorator]
    var unpinnedItems: [HistoryItemDecorator]
    var proxy: ScrollViewProxy
    var onNavigateUp: () -> Void
    var onNavigateDown: () -> Void
    var onCopyItem: () -> Void
    var onDeleteItem: () -> Void
    
    var body: some View {
        Color.clear.frame(height: 0)
            .onChange(of: scrollTarget) { newTargetID in
                guard let targetID = newTargetID else { return }
                proxy.scrollTo(targetID, anchor: .center)
                scrollTarget = nil
            }
            .onAppear {
                if selectedItem == nil {
                    selectedItem = pinnedItems.first ?? unpinnedItems.first
                }
            }
            .onKeyPress(.upArrow) {
                onNavigateUp()
                return .handled
            }
            .onKeyPress(.downArrow) {
                onNavigateDown()
                return .handled
            }
            .onKeyPress(.return) {
                onCopyItem()
                return .handled
            }
            .onKeyPress(.delete) {
                onDeleteItem()
                return .handled
            }
    }
}

/**
 * 底部操作按钮视图
 */
struct ActionButtonsView: View {
    var windowController: HistoryManagerWindowController?
    var dismiss: DismissAction
    var selectedItem: HistoryItemDecorator?
    var onDeleteItem: () -> Void
    var onClearHistory: () -> Void
    
    var body: some View {
        HStack {
            Button(action: {
                if let windowController = windowController {
                    windowController.close()
                } else {
                    dismiss()
                }
            }) {
                Text(NSLocalizedString("Close", tableName: "GeneralSettings", comment: ""))
            }
            
            Spacer()
            
            Button(action: onDeleteItem) {
                Label(NSLocalizedString("DeleteItem", tableName: "GeneralSettings", comment: ""), systemImage: "trash")
            }
            .disabled(selectedItem == nil)
            .keyboardShortcut(.delete, modifiers: [])
            
            Button(action: onClearHistory) {
                Label(NSLocalizedString("ClearHistory", tableName: "GeneralSettings", comment: ""), systemImage: "trash.slash")
            }
            .keyboardShortcut("k", modifiers: [.command])
        }
        .padding()
    }
}

/**
 * 历史记录项行视图
 * 用于在历史记录管理列表中显示单个历史记录项
 */
struct HistoryItemRow: View {
    @Bindable var item: HistoryItemDecorator
    var index: Int
    var history: History
    
    var body: some View {
        HStack {
            // 索引
            Text("\(index)")
                .frame(width: 30)
                .foregroundStyle(.secondary)
            
            // 应用图标
            Image(nsImage: item.applicationImage.nsImage)
                .resizable()
                .frame(width: 16, height: 16)
            
            // 主要内容
            itemContent
            
            Spacer()
            
            // 固定图标
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .foregroundColor(.accentColor)
            }
            
            // 日期显示
            Text(formattedDate(item.item.lastCopiedAt))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contextMenu {
            itemContextMenu
        }
    }
    
    /**
     * 项目主要内容视图
     */
    private var itemContent: some View {
        Group {
            if let image = item.thumbnailImage {
                HStack {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 30)
                    Text(item.title)
                        .lineLimit(1)
                }
            } else {
                Text(item.title)
                    .lineLimit(1)
            }
        }
    }
    
    /**
     * 上下文菜单内容
     */
    private var itemContextMenu: some View {
        Group {
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.title, forType: .string)
            }) {
                Label(NSLocalizedString("Copy", tableName: "GeneralSettings", comment: ""), systemImage: "doc.on.doc")
            }
            
            Button(action: {
                Task {
                    await history.togglePin(item)
                }
            }) {
                if item.isPinned {
                    Label(NSLocalizedString("Unpin", tableName: "GeneralSettings", comment: ""), systemImage: "pin.slash")
                } else {
                    Label(NSLocalizedString("Pin", tableName: "GeneralSettings", comment: ""), systemImage: "pin")
                }
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                Task {
                    await history.delete(item)
                }
            }) {
                Label(NSLocalizedString("Delete", tableName: "GeneralSettings", comment: ""), systemImage: "trash")
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    HistoryManagerView(history: History.shared)
} 
