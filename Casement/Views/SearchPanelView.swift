import SwiftUI

struct SearchPanelView: View {
    @ObservedObject var viewModel: SearchPanelViewModel

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            resultsList
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
                .onSubmit {
                    viewModel.commitSelection()
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            List(Array(viewModel.results.enumerated()), id: \.element.id) { index, ranked in
                WindowRowView(
                    ranked: ranked,
                    isSelected: index == viewModel.selectedIndex
                )
                .id(index)
                .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                .listRowBackground(
                    index == viewModel.selectedIndex
                        ? Color.accentColor.opacity(0.2)
                        : Color.clear
                )
            }
            .listStyle(.plain)
            .onChange(of: viewModel.selectedIndex) { _, newIndex in
                proxy.scrollTo(newIndex, anchor: .center)
            }
        }
    }
}
