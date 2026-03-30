import SwiftUI
import SwiftData

@Observable
@MainActor
class CardGenerationViewModel {
    var isGenerating = false
    var errorMessage: String?
    var generatedCount = 0
    var cardCount = 10
    var additionalPrompt = ""

    func generateCards(for lesson: Lesson, context: ModelContext) async {
        isGenerating = true
        errorMessage = nil
        generatedCount = 0

        do {
            let cards = try await LLMService.shared.generateLessonCards(
                lesson: lesson,
                count: cardCount,
                additionalPrompt: additionalPrompt.isEmpty ? nil : additionalPrompt
            )

            for generated in cards {
                let cardType: CardType
                if let typeStr = generated.type, let parsed = CardType(rawValue: typeStr) {
                    cardType = parsed
                } else {
                    cardType = .vocabulary
                }

                let card = Card(
                    lessonId: lesson.id,
                    front: generated.front,
                    back: generated.back,
                    contextSentence: generated.context ?? "",
                    cardType: cardType
                )
                context.insert(card)
            }

            // Mark lesson as having generated cards
            let lessonId = lesson.id
            let descriptor = FetchDescriptor<LessonProgress>(
                predicate: #Predicate<LessonProgress> { $0.lessonId == lessonId }
            )
            if let progress = try? context.fetch(descriptor).first {
                progress.cardsGenerated = true
            } else {
                let progress = LessonProgress(lessonId: lesson.id, cardsGenerated: true)
                context.insert(progress)
            }

            try? context.save()
            generatedCount = cards.count
        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }
}
