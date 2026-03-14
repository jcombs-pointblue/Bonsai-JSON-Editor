import SwiftUI

/// Detail view for a single tutorial step: instruction, sample data, query, and live results
struct TutorialStepDetailView: View {
    @Bindable var viewModel: TutorialViewModel
    let step: TutorialStep
    @State private var isSampleDataExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                stepHeader
                descriptionSection

                if let hint = step.hint {
                    hintCallout(hint)
                }

                querySection

                if viewModel.hasRunCurrentStep {
                    resultsSection
                }

                sampleDataSection

                Spacer(minLength: 24)

                navigationFooter
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Step Header

    @ViewBuilder
    private var stepHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let category = viewModel.selectedCategory {
                    Text(category.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }

                Text(step.title)
                    .font(.title)
                    .bold()
            }

            Spacer()

            Text("\(viewModel.currentStepIndex + 1) / \(viewModel.totalStepsInCategory)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
        }
        .padding(.bottom, 16)
    }

    // MARK: - Description

    @ViewBuilder
    private var descriptionSection: some View {
        Text(step.description)
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 16)
    }

    // MARK: - Hint Callout

    @ViewBuilder
    private func hintCallout(_ hint: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
                .font(.callout)
            Text(hint)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .padding(.bottom, 16)
    }

    // MARK: - Query Section

    @ViewBuilder
    private var querySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HelpSubheading("Query")

            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                Text("jq")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))

                TextField("jq expression", text: $viewModel.editableQuery)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { viewModel.runQuery() }

                if viewModel.editableQuery != step.query {
                    Button("Reset Query", systemImage: "arrow.counterclockwise", action: viewModel.resetQuery)
                        .labelStyle(.iconOnly)
                        .font(.caption)
                        .help("Reset to original query")
                        .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))

            HStack {
                Button {
                    viewModel.runQuery()
                } label: {
                    Label(viewModel.hasRunCurrentStep ? "Run Again" : "Try It",
                          systemImage: "play.fill")
                }
                .controlSize(.regular)
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRunning)

                if viewModel.isRunning {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()

                if viewModel.editableQuery != step.query {
                    Text("Modified")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Results Section

    @ViewBuilder
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HelpSubheading("Result")

                if !viewModel.queryResults.isEmpty {
                    Text("\(viewModel.queryResults.count) value\(viewModel.queryResults.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)
                }
            }

            if let error = viewModel.queryError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                    Text(error)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.red)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            } else if viewModel.queryResults.isEmpty {
                Text("No results returned.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(viewModel.queryResults.enumerated()), id: \.offset) { index, result in
                        if viewModel.queryResults.count > 1 {
                            Text("Result \(index + 1)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Text(result.prettyPrinted())
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if index < viewModel.queryResults.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(12)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Sample Data Section

    @ViewBuilder
    private var sampleDataSection: some View {
        DisclosureGroup(isExpanded: $isSampleDataExpanded) {
            Text(viewModel.sampleJSONText)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.caption)
                Text("Sample Data (sample.json)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Navigation Footer

    @ViewBuilder
    private var navigationFooter: some View {
        HStack {
            Button {
                viewModel.goToPreviousStep()
            } label: {
                Label("Previous", systemImage: "chevron.left")
            }
            .disabled(viewModel.currentStepIndex == 0)

            Spacer()

            if let category = viewModel.selectedCategory {
                Text("\(viewModel.completedCountInCategory) of \(category.steps.count) completed")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                viewModel.goToNextStep()
            } label: {
                HStack(spacing: 4) {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
            }
            .disabled(viewModel.currentStepIndex >= viewModel.totalStepsInCategory - 1)
        }
        .padding(.top, 8)
    }
}
