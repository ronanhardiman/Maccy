import SwiftUI
import Defaults
import AppKit

/**
 * 历史记录管理视图
 * 用于在偏好设置中显示和管理剪贴板历史记录
 */
struct HistoryManagerView: View {
    var history: History
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchQuery = ""
    @State private var selectedItem: HistoryItemDecorator?
    @State private var showConfirmDeleteAlert = false
    @State private var showConfirmClearAlert = false
    
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
                    dismiss()
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
                    dismiss()
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