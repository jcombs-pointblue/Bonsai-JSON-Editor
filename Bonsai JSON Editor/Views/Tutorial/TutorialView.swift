import SwiftUI

/// Main tutorial window with sidebar for category/step navigation and detail area for interactive content
struct TutorialView: View {
    @State private var viewModel = TutorialViewModel()

    var body: some View {
        NavigationSplitView {
            tutorialSidebar
        } detail: {
            if let step = viewModel.selectedStep {
                TutorialStepDetailView(viewModel: viewModel, step: step)
            } else {
                ContentUnavailableView(
                    "Select a Lesson",
                    systemImage: "graduationcap",
                    description: Text("Choose a category and step from the sidebar to begin.")
                )
            }
        }
        .frame(minWidth: 900, minHeight: 650)
        .onAppear {
            if let first = TutorialContent.categories.first {
                viewModel.selectCategory(first)
            }
        }
    }

    private var selectedStepBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.selectedStep?.id },
            set: { newID in
                for category in TutorialContent.categories {
                    if let step = category.steps.first(where: { $0.id == newID }) {
                        viewModel.selectedCategory = category
                        viewModel.selectStep(step)
                        return
                    }
                }
            }
        )
    }

    @ViewBuilder
    private var tutorialSidebar: some View {
        List(selection: selectedStepBinding) {
            ForEach(TutorialContent.categories) { category in
                Section {
                    ForEach(category.steps) { step in
                        stepRow(step)
                    }
                } header: {
                    Label(category.name, systemImage: category.icon)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
    }

    @ViewBuilder
    private func stepRow(_ step: TutorialStep) -> some View {
        let isCompleted = viewModel.completedStepIDs.contains(step.id)
        HStack {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isCompleted ? Color.green : Color.gray.opacity(0.4))
                .font(.caption)
            Text(step.title)
                .lineLimit(1)
        }
        .tag(step.id)
    }
}
