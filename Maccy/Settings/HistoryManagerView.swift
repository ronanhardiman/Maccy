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
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
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
    
    /**
     * 过滤后的历史记录项目
     * 根据搜索查询过滤历史记录
     */
    private var filteredItems: [HistoryItemDecorator] {
        if searchQuery.isEmpty {
            return history.all
        } else {
            return history.all.filter { item in
                item.title.localizedCaseInsensitiveContains(searchQuery)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 添加标题栏带关闭按钮
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
            
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(NSLocalizedString("SearchHistory", tableName: "GeneralSettings", comment: ""), text: $searchQuery)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding([.horizontal])
            
            // 历史记录列表
            List(selection: $selectedItem) {
                ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                    HistoryItemRow(item: item, index: index, history: history)
                        .tag(item)
                }
            }
            .listStyle(.bordered)
            
            // 底部操作按钮
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
                
                Button(action: {
                    if let selectedItem = selectedItem {
                        Task {
                            await history.delete(selectedItem)
                            self.selectedItem = nil
                        }
                    }
                }) {
                    Label(NSLocalizedString("DeleteItem", tableName: "GeneralSettings", comment: ""), systemImage: "trash")
                }
                .disabled(selectedItem == nil)
                
                Button(action: {
                    showConfirmClearAlert = true
                }) {
                    Label(NSLocalizedString("ClearHistory", tableName: "GeneralSettings", comment: ""), systemImage: "trash.slash")
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
        .alert(NSLocalizedString("ClearHistoryConfirmation", tableName: "GeneralSettings", comment: ""), isPresented: $showConfirmClearAlert) {
            Button(NSLocalizedString("Cancel", tableName: "GeneralSettings", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("ClearUnpinned", tableName: "GeneralSettings", comment: ""), role: .destructive) {
                Task {
                    await history.clear()
                }
            }
            Button(NSLocalizedString("ClearAll", tableName: "GeneralSettings", comment: ""), role: .destructive) {
                Task {
                    await history.clearAll()
                }
            }
        } message: {
            Text(NSLocalizedString("ClearHistoryMessage", tableName: "GeneralSettings", comment: ""))
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
            Text("\(index)")
                .frame(width: 30)
                .foregroundStyle(.secondary)
            
            Image(nsImage: item.applicationImage.nsImage)
                .resizable()
                .frame(width: 16, height: 16)
            
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
            
            Spacer()
            
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .foregroundColor(.accentColor)
            }
            
            Text(formattedDate(item.item.lastCopiedAt))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contextMenu {
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