import SwiftUI

/// View model managing the interactive tutorial state
@MainActor @Observable
class TutorialViewModel {
    /// The sample data parsed into a JSONNode (computed once from TutorialContent)
    let sampleNode: JSONNode = TutorialContent.sampleNode
    let sampleJSONText: String = TutorialContent.sampleJSON

    /// Currently selected category
    var selectedCategory: TutorialCategory? = TutorialContent.categories.first

    /// Currently selected step within the category
    var selectedStep: TutorialStep?

    /// Results from running the current step's query
    var queryResults: [JSONNode] = []

    /// Error from the last query attempt
    var queryError: String?

    /// Whether we are currently computing a query result
    var isRunning: Bool = false

    /// Whether the user has run the current step (controls showing results)
    var hasRunCurrentStep: Bool = false

    /// User's editable query text (initially matches the step's query)
    var editableQuery: String = ""

    /// Track completed step IDs
    var completedStepIDs: Set<UUID> = []

    /// Current step index within the selected category
    var currentStepIndex: Int {
        guard let step = selectedStep, let category = selectedCategory else { return 0 }
        return category.steps.firstIndex(where: { $0.id == step.id }) ?? 0
    }

    /// Total steps in the current category
    var totalStepsInCategory: Int {
        selectedCategory?.steps.count ?? 0
    }

    /// Completion count for the current category
    var completedCountInCategory: Int {
        guard let category = selectedCategory else { return 0 }
        return category.steps.count(where: { completedStepIDs.contains($0.id) })
    }

    /// Navigate to a specific step
    func selectStep(_ step: TutorialStep) {
        selectedStep = step
        editableQuery = step.query
        queryResults = []
        queryError = nil
        hasRunCurrentStep = false
    }

    /// Select a category and auto-select its first step
    func selectCategory(_ category: TutorialCategory) {
        selectedCategory = category
        if let firstStep = category.steps.first {
            selectStep(firstStep)
        }
    }

    /// Navigate to the next step in the current category
    func goToNextStep() {
        guard let category = selectedCategory else { return }
        let idx = currentStepIndex
        if idx + 1 < category.steps.count {
            selectStep(category.steps[idx + 1])
        }
    }

    /// Navigate to the previous step in the current category
    func goToPreviousStep() {
        guard let category = selectedCategory else { return }
        let idx = currentStepIndex
        if idx > 0 {
            selectStep(category.steps[idx - 1])
        }
    }

    /// Run the current query against the sample data
    func runQuery() {
        let queryText = editableQuery.trimmingCharacters(in: .whitespaces)
        guard !queryText.isEmpty else {
            queryResults = []
            queryError = nil
            return
        }

        isRunning = true
        queryResults = []
        queryError = nil

        Task { @MainActor in
            let input = sampleNode
            do {
                let results = try JQEvaluator.evaluate(expression: queryText, input: input)
                queryResults = results
                queryError = nil
                if let step = selectedStep {
                    completedStepIDs.insert(step.id)
                }
            } catch {
                queryResults = []
                queryError = error.localizedDescription
            }
            isRunning = false
            hasRunCurrentStep = true
        }
    }

    /// Reset the editable query back to the step's original query
    func resetQuery() {
        guard let step = selectedStep else { return }
        editableQuery = step.query
        queryResults = []
        queryError = nil
        hasRunCurrentStep = false
    }
}
