import SwiftUI

struct SearchPanelView: View {
    @ObservedObject var viewModel: SearchPanelViewModel
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            if viewModel.results.isEmpty && !viewModel.query.isEmpty {
                VStack {
                    Spacer()
                    Text("No matching windows")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Spacer()
                }
            } else {
                ZStack {
                    resultsList
                    if viewModel.showingActions {
                        actionsOverlay
                    }
                }
            }
        }
        .frame(width: 600, height: 400)
        .background(.ultraThinMaterial)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 16))
            TextField("Search windows...", text: $viewModel.query)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .focused($isSearchFieldFocused)
                .disabled(viewModel.showingActions)
                .onSubmit {
                    viewModel.commitSelection()
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onAppear { isSearchFieldFocused = true }
        .onChange(of: viewModel.isVisible) { _, visible in
            if visible { isSearchFieldFocused = true }
        }
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            List(Array(viewModel.results.enumerated()), id: \.element.id) { index, ranked in
                WindowRowView(
                    ranked: ranked,
                    isSelected: index == viewModel.selectedIndex && !viewModel.showingActions
                )
                .id(index)
                .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                .listRowBackground(
                    index == viewModel.selectedIndex
                        ? Color.accentColor.opacity(viewModel.showingActions ? 0.1 : 0.2)
                        : Color.clear
                )
            }
            .listStyle(.plain)
            .onChange(of: viewModel.selectedIndex) { _, newIndex in
                proxy.scrollTo(newIndex, anchor: .center)
            }
        }
    }

    private var actionsOverlay: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 0) {
                if viewModel.selectedIndex < viewModel.results.count {
                    let selected = viewModel.results[viewModel.selectedIndex]
                    HStack {
                        Text("Actions for")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(selected.window.appName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("esc to cancel")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                Divider()
                ForEach(Array(viewModel.actions.enumerated()), id: \.element.id) { index, action in
                    ActionRowView(
                        action: action,
                        isSelected: index == viewModel.actionIndex
                    )
                }
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}

private struct ActionRowView: View {
    let action: WindowAction
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: action.icon)
                .frame(width: 20)
                .foregroundStyle(action == .close ? .secondary : .primary)
            Text(action.rawValue)
                .font(.system(size: 13))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
    }
}
