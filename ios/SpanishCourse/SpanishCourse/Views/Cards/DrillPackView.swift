import SwiftUI

// MARK: - Drill Card Model

struct DrillCard: Identifiable {
    let id = UUID()
    let front: String      // "Yo ___ en Madrid."
    let back: String        // "estoy (ESTAR — местонахождение)"
    let context: String?    // full sentence override
    var translation: String? // Russian translation

    /// Build full Spanish sentence by replacing ___ with the answer word
    var fullSentence: String {
        if let context, !context.isEmpty { return context }
        // Extract answer from back (first word before space or parenthesis)
        let answer = back.split(separator: " ").first.map(String.init) ?? back
        return front.replacingOccurrences(of: "___", with: answer)
    }
}

// MARK: - Drill Pack View

struct DrillPackView: View {
    let title: String
    let cheatSheet: String
    let cards: [DrillCard]

    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var correctCount = 0
    @State private var incorrectCount = 0
    @State private var showingCheatSheet = false
    @State private var sessionComplete = false
    @Environment(\.dismiss) private var dismiss

    private var currentCard: DrillCard? {
        guard currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessionComplete {
                    resultView
                } else if let card = currentCard {
                    cardView(card: card)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCheatSheet = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
            .sheet(isPresented: $showingCheatSheet) {
                cheatSheetView
            }
        }
    }

    // MARK: - Card View

    private func cardView(card: DrillCard) -> some View {
        VStack(spacing: 20) {
            // Progress
            VStack(spacing: 6) {
                ProgressView(value: Double(currentIndex), total: Double(cards.count))
                Text("\(currentIndex + 1) / \(cards.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            Spacer()

            FlipCardView(
                front: card.front,
                back: card.back,
                context: card.context ?? "",
                isFlipped: $isFlipped
            )
            .padding(.horizontal)

            if isFlipped, let translation = card.translation, !translation.isEmpty {
                Text(translation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
                    .padding(.horizontal)
                    .transition(.opacity)
            }

            Spacer()

            if isFlipped {
                HStack(spacing: 16) {
                    Button {
                        incorrectCount += 1
                        advance()
                    } label: {
                        Label("Не знаю", systemImage: "xmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Button {
                        correctCount += 1
                        advance()
                    } label: {
                        Label("Знаю", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
            } else {
                HStack {
                    Button {
                        showingCheatSheet = true
                    } label: {
                        Label("Шпаргалка", systemImage: "questionmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    Button {
                        withAnimation { isFlipped = true }
                    } label: {
                        Text("Показать ответ")
                            .font(.headline)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }

    // MARK: - Result

    private var resultView: some View {
        VStack(spacing: 24) {
            Spacer()
            let accuracy = Double(correctCount) / Double(max(cards.count, 1))
            Image(systemName: accuracy >= 0.8 ? "star.fill" : "arrow.counterclockwise")
                .font(.system(size: 56))
                .foregroundStyle(accuracy >= 0.8 ? .yellow : .orange)
            Text("Результат: \(correctCount)/\(cards.count)")
                .font(.title.bold())
            Text("\(Int(accuracy * 100))% правильно")
                .font(.headline)
                .foregroundStyle(accuracy >= 0.8 ? .green : .orange)
            Spacer()
            HStack(spacing: 16) {
                Button {
                    resetDrill()
                } label: {
                    Text("Ещё раз")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Button {
                    dismiss()
                } label: {
                    Text("Готово")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Cheat Sheet

    private var cheatSheetView: some View {
        NavigationStack {
            ScrollView {
                Text(cheatSheet)
                    .font(.body)
                    .lineSpacing(6)
                    .padding()
            }
            .navigationTitle("Шпаргалка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { showingCheatSheet = false }
                }
            }
        }
    }

    // MARK: - Logic

    private func advance() {
        withAnimation {
            isFlipped = false
            currentIndex += 1
            if currentIndex >= cards.count {
                sessionComplete = true
            }
        }
    }

    private func resetDrill() {
        currentIndex = 0
        correctCount = 0
        incorrectCount = 0
        isFlipped = false
        sessionComplete = false
    }
}

// MARK: - SER vs ESTAR Drill Data

struct SerEstarDrill {

    static let cheatSheet = """
    СПРЯЖЕНИЕ SER — ВСЕ ФОРМЫ (Presente):
    yo soy — я есть
    tú eres — ты есть
    él/ella/usted es — он/она/Вы есть
    nosotros somos — мы есть
    vosotros sois — вы есть
    ellos/ellas/ustedes son — они есть

    Пример с прилагательным (alto — высокий):
    • yo soy alto/alta — я высокий/высокая
    • tú eres alto/alta — ты высокий/высокая
    • él es alto — он высокий
    • ella es alta — она высокая
    • nosotros somos altos — мы высокие
    • nosotras somos altas — мы (жен.) высокие
    • vosotros sois altos — вы высокие
    • ellos son altos — они высокие
    • ellas son altas — они (жен.) высокие

    СПРЯЖЕНИЕ ESTAR — ВСЕ ФОРМЫ (Presente):
    yo estoy — я нахожусь/чувствую
    tú estás — ты находишься
    él/ella/usted está — он/она находится
    nosotros estamos — мы находимся
    vosotros estáis — вы находитесь
    ellos/ellas/ustedes están — они находятся

    Пример с прилагательным (cansado — уставший):
    • yo estoy cansado/cansada — я устал(а)
    • tú estás cansado/cansada — ты устал(а)
    • él está cansado — он устал
    • ella está cansada — она устала
    • nosotros estamos cansados — мы устали
    • nosotras estamos cansadas — мы (жен.) устали
    • vosotros estáis cansados — вы устали
    • vosotras estáis cansadas — вы (жен.) устали
    • ellos están cansados — они устали
    • ellas están cansadas — они (жен.) устали
    • ustedes están cansados — Вы (вежл.) устали

    Пример с estar + ubicación (местонахождение):
    • yo estoy en casa — я дома
    • tú estás en el trabajo — ты на работе
    • él está en Madrid — он в Мадриде
    • nosotros estamos aquí — мы здесь
    • ellos están en el parque — они в парке

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    SER — постоянные характеристики:
    • Идентичность: Soy María. Soy profesor.
    • Происхождение: Soy de Rusia.
    • Национальность: Soy ruso.
    • Материал: La mesa es de madera.
    • Время: Son las tres. Es lunes.
    • Характер: Es inteligente. Es simpático.
    • Цвет (постоянный): El cielo es azul.
    • Профессия: Es médico.
    • Отношения: Es mi hermano.

    ESTAR — временные состояния и местоположение:
    • Местонахождение: Estoy en Madrid. Está aquí.
    • Состояние: Estoy cansado. Está enfermo.
    • Эмоции: Estoy contento. Está triste.
    • Результат: La puerta está abierta.
    • Estar + gerundio: Estoy comiendo.
    • Еда (вкус): La paella está buena.
    • Внешний вид (сейчас): Estás muy guapa hoy.

    ПРИЛАГАТЕЛЬНЫЕ С РАЗНЫМ ЗНАЧЕНИЕМ:
    • ser aburrido = скучный ↔ estar aburrido = скучающий
    • ser listo = умный ↔ estar listo = готовый
    • ser malo = плохой ↔ estar malo = больной
    • ser bueno = хороший ↔ estar bueno = вкусный
    • ser rico = богатый ↔ estar rico = вкусный
    • ser vivo = хитрый ↔ estar vivo = живой
    • ser abierto = открытый (характер) ↔ estar abierto = открытый (дверь)
    • ser orgulloso = гордый (негат.) ↔ estar orgulloso = гордиться

    СПРЯЖЕНИЕ SER: soy, eres, es, somos, sois, son
    СПРЯЖЕНИЕ ESTAR: estoy, estás, está, estamos, estáis, están
    """

    static let cards: [DrillCard] = [
        // SER — identity
        DrillCard(front:"Yo ___ María.",back:"soy (SER — идентичность)",context:"Yo soy María.",translation:"Я — Мария."),
        DrillCard(front:"Él ___ profesor.",back:"es (SER — профессия)",context:"Él es profesor.",translation:"Он преподаватель."),
        DrillCard(front:"Nosotros ___ estudiantes.",back:"somos (SER — идентичность)",context:nil,translation:"Мы студенты."),
        DrillCard(front:"Ellos ___ hermanos.",back:"son (SER — отношения)",context:nil,translation:"Они братья."),
        DrillCard(front:"Tú ___ mi amigo.",back:"eres (SER — отношения)",context:nil,translation:"Ты мой друг."),
        // SER — origin
        DrillCard(front:"Yo ___ de Rusia.",back:"soy (SER — происхождение)",context:"Soy de Rusia.",translation:"Я из России."),
        DrillCard(front:"Ella ___ de España.",back:"es (SER — происхождение)",context:nil,translation:"Она из Испании."),
        DrillCard(front:"Nosotros ___ de Moscú.",back:"somos (SER — происхождение)",context:nil,translation:"Мы из Москвы."),
        DrillCard(front:"¿De dónde ___ tú?",back:"eres (SER — происхождение)",context:nil,translation:"Откуда ты?"),
        DrillCard(front:"Ellos ___ rusos.",back:"son (SER — национальность)",context:nil,translation:"Они русские."),
        // SER — characteristics
        DrillCard(front:"Ella ___ inteligente.",back:"es (SER — характер)",context:nil,translation:"Она умная."),
        DrillCard(front:"La mesa ___ de madera.",back:"es (SER — материал)",context:nil,translation:"Стол из дерева."),
        DrillCard(front:"El cielo ___ azul.",back:"es (SER — постоянный цвет)",context:nil,translation:"Небо голубое."),
        DrillCard(front:"Mi hermano ___ alto.",back:"es (SER — физ. характеристика)",context:nil,translation:"Мой брат высокий."),
        DrillCard(front:"___ las tres de la tarde.",back:"Son (SER — время)",context:nil,translation:"Три часа дня."),
        DrillCard(front:"Hoy ___ lunes.",back:"es (SER — день недели)",context:nil,translation:"Сегодня понедельник."),
        DrillCard(front:"La fiesta ___ el sábado.",back:"es (SER — событие/дата)",context:nil,translation:"Вечеринка в субботу."),
        DrillCard(front:"Ella ___ simpática y amable.",back:"es (SER — характер)",context:nil,translation:"Она приятная и добрая."),
        DrillCard(front:"Este libro ___ interesante.",back:"es (SER — характеристика)",context:nil,translation:"Эта книга интересная."),
        DrillCard(front:"La casa ___ grande.",back:"es (SER — характеристика)",context:nil,translation:"Дом большой."),
        // ESTAR — location
        DrillCard(front:"Yo ___ en Madrid.",back:"estoy (ESTAR — местонахождение)",context:nil,translation:"Я в Мадриде."),
        DrillCard(front:"El libro ___ en la mesa.",back:"está (ESTAR — местонахождение)",context:nil,translation:"Книга на столе."),
        DrillCard(front:"¿Dónde ___ el baño?",back:"está (ESTAR — местонахождение)",context:nil,translation:"Где ванная?"),
        DrillCard(front:"Nosotros ___ en casa.",back:"estamos (ESTAR — местонахождение)",context:nil,translation:"Мы дома."),
        DrillCard(front:"Ellos ___ en el parque.",back:"están (ESTAR — местонахождение)",context:nil,translation:"Они в парке."),
        DrillCard(front:"¿Dónde ___ tú?",back:"estás (ESTAR — местонахождение)",context:nil,translation:"Где ты?"),
        DrillCard(front:"El restaurante ___ cerca.",back:"está (ESTAR — местонахождение)",context:nil,translation:"Ресторан рядом."),
        DrillCard(front:"Mi coche ___ en el garaje.",back:"está (ESTAR — местонахождение)",context:nil,translation:"Моя машина в гараже."),
        DrillCard(front:"Madrid ___ en España.",back:"está (ESTAR — географ. положение)",context:nil,translation:"Мадрид в Испании."),
        DrillCard(front:"Las llaves ___ aquí.",back:"están (ESTAR — местонахождение)",context:nil,translation:"Ключи здесь."),
        // ESTAR — state/emotion
        DrillCard(front:"Yo ___ cansado.",back:"estoy (ESTAR — состояние)",context:nil,translation:"Я устал."),
        DrillCard(front:"Ella ___ enferma.",back:"está (ESTAR — состояние)",context:nil,translation:"Она больна."),
        DrillCard(front:"Nosotros ___ contentos.",back:"estamos (ESTAR — эмоция)",context:nil,translation:"Мы довольны."),
        DrillCard(front:"Él ___ triste hoy.",back:"está (ESTAR — эмоция)",context:nil,translation:"Он грустный сегодня."),
        DrillCard(front:"Yo ___ nervioso.",back:"estoy (ESTAR — эмоция)",context:nil,translation:"Я нервничаю."),
        DrillCard(front:"¿Cómo ___? — Bien, gracias.",back:"estás (ESTAR — состояние)",context:nil,translation:"Как дела? — Хорошо, спасибо."),
        DrillCard(front:"Ella ___ ocupada ahora.",back:"está (ESTAR — состояние)",context:nil,translation:"Она сейчас занята."),
        DrillCard(front:"Ellos ___ preocupados.",back:"están (ESTAR — эмоция)",context:nil,translation:"Они обеспокоены."),
        DrillCard(front:"La puerta ___ abierta.",back:"está (ESTAR — результат)",context:nil,translation:"Дверь открыта."),
        DrillCard(front:"La comida ___ lista.",back:"está (ESTAR — готовность)",context:nil,translation:"Еда готова."),
        // ESTAR + gerundio
        DrillCard(front:"Yo ___ comiendo.",back:"estoy (ESTAR + gerundio)",context:nil,translation:"Я ем (сейчас)."),
        DrillCard(front:"Ella ___ estudiando.",back:"está (ESTAR + gerundio)",context:nil,translation:"Она учится (сейчас)."),
        DrillCard(front:"Nosotros ___ trabajando.",back:"estamos (ESTAR + gerundio)",context:nil,translation:"Мы работаем (сейчас)."),
        DrillCard(front:"¿Qué ___ haciendo?",back:"estás (ESTAR + gerundio)",context:nil,translation:"Что ты делаешь?"),
        DrillCard(front:"Ellos ___ jugando.",back:"están (ESTAR + gerundio)",context:nil,translation:"Они играют (сейчас)."),
        // Mixed — tricky adjectives
        DrillCard(front:"Juan ___ aburrido. (= ему скучно)",back:"está (ESTAR — временное состояние)",context:nil,translation:"Хуану скучно."),
        DrillCard(front:"Juan ___ aburrido. (= он скучный)",back:"es (SER — характеристика)",context:nil,translation:"Хуан скучный человек."),
        DrillCard(front:"Ella ___ lista. (= готова)",back:"está (ESTAR — готовность)",context:nil,translation:"Она готова."),
        DrillCard(front:"Ella ___ lista. (= умная)",back:"es (SER — характер)",context:nil,translation:"Она умная."),
        DrillCard(front:"Él ___ malo. (= болеет)",back:"está (ESTAR — состояние)",context:nil,translation:"Он болен."),
        DrillCard(front:"Él ___ malo. (= плохой человек)",back:"es (SER — характер)",context:nil,translation:"Он плохой."),
        DrillCard(front:"La paella ___ buena. (= вкусная)",back:"está (ESTAR — вкус сейчас)",context:nil,translation:"Паэлья вкусная."),
        DrillCard(front:"María ___ buena persona.",back:"es (SER — характер)",context:nil,translation:"Мария хороший человек."),
        DrillCard(front:"Él ___ rico. (= у него деньги)",back:"es (SER — характеристика)",context:nil,translation:"Он богатый."),
        DrillCard(front:"El café ___ rico. (= вкусный)",back:"está (ESTAR — вкус)",context:nil,translation:"Кофе вкусный."),
        DrillCard(front:"Es un hombre ___. (= хитрый)",back:"vivo (SER vivo = хитрый)",context:nil,translation:"Он хитрый человек."),
        DrillCard(front:"El perro ___ vivo. (= живой)",back:"está (ESTAR vivo = живой)",context:nil,translation:"Собака жива."),
        DrillCard(front:"Pedro ___ orgulloso. (= гордый, негат.)",back:"es (SER — характер)",context:nil,translation:"Педро гордец."),
        DrillCard(front:"Pedro ___ orgulloso de su hijo.",back:"está (ESTAR — гордится)",context:nil,translation:"Педро гордится сыном."),
        DrillCard(front:"La tienda ___ abierta.",back:"está (ESTAR — открыта сейчас)",context:nil,translation:"Магазин открыт."),
        DrillCard(front:"Es una persona ___. (= открытая)",back:"abierta (SER abierto = открытый характер)",context:nil,translation:"Он открытый человек."),
        // More mixed
        DrillCard(front:"La película ___ interesante.",back:"es (SER — характеристика)",context:nil,translation:"Фильм интересный."),
        DrillCard(front:"Yo ___ interesado en el tema.",back:"estoy (ESTAR — состояние)",context:nil,translation:"Я заинтересован в теме."),
        DrillCard(front:"Mi padre ___ médico.",back:"es (SER — профессия)",context:nil,translation:"Мой отец врач."),
        DrillCard(front:"Mi padre ___ en el hospital.",back:"está (ESTAR — местонахождение)",context:nil,translation:"Мой отец в больнице."),
        DrillCard(front:"___ importante estudiar.",back:"Es (SER — оценка)",context:nil,translation:"Важно учиться."),
        DrillCard(front:"Todo ___ bien.",back:"está (ESTAR — состояние)",context:nil,translation:"Всё хорошо."),
        DrillCard(front:"Ella ___ guapa. (= всегда)",back:"es (SER — постоянная характеристика)",context:nil,translation:"Она красивая."),
        DrillCard(front:"Ella ___ guapa hoy. (= сегодня)",back:"está (ESTAR — сегодня особенно)",context:nil,translation:"Она красивая сегодня."),
        DrillCard(front:"El agua ___ fría.",back:"está (ESTAR — температура сейчас)",context:nil,translation:"Вода холодная."),
        DrillCard(front:"El hielo ___ frío.",back:"es (SER — по природе)",context:nil,translation:"Лёд холодный (по природе)."),
        DrillCard(front:"¿Qué hora ___?",back:"es (SER — время)",context:nil,translation:"Который час?"),
        DrillCard(front:"¿Cómo ___ tu hermano? (= какой он)",back:"es (SER — описание)",context:nil,translation:"Какой твой брат?"),
        DrillCard(front:"¿Cómo ___ tu hermano? (= как дела)",back:"está (ESTAR — состояние)",context:nil,translation:"Как твой брат? (здоровье)"),
        DrillCard(front:"La boda ___ en junio.",back:"es (SER — событие)",context:nil,translation:"Свадьба в июне."),
        DrillCard(front:"La boda ___ en la iglesia.",back:"es (SER — место события)",context:nil,translation:"Свадьба в церкви."),
        DrillCard(front:"Yo ___ seguro. (= уверен)",back:"estoy (ESTAR — состояние)",context:nil,translation:"Я уверен."),
        DrillCard(front:"Este camino ___ seguro.",back:"es (SER — характеристика)",context:nil,translation:"Эта дорога безопасная."),
        DrillCard(front:"Ella ___ callada hoy.",back:"está (ESTAR — сегодня молчит)",context:nil,translation:"Она молчаливая сегодня."),
        DrillCard(front:"Ella ___ callada. (= тихий человек)",back:"es (SER — характер)",context:nil,translation:"Она тихий человек."),
        DrillCard(front:"Los niños ___ dormidos.",back:"están (ESTAR — состояние)",context:nil,translation:"Дети спят."),
        DrillCard(front:"Yo ___ de acuerdo.",back:"estoy (ESTAR — мнение)",context:nil,translation:"Я согласен."),
        DrillCard(front:"Tú ___ loco. (= сумасшедший всегда)",back:"eres (SER — характер)",context:nil,translation:"Ты сумасшедший."),
        DrillCard(front:"Tú ___ loco. (= ведёшь себя безумно)",back:"estás (ESTAR — сейчас)",context:nil,translation:"Ты с ума сошёл! (сейчас)"),
        DrillCard(front:"La habitación ___ limpia.",back:"está (ESTAR — результат уборки)",context:nil,translation:"Комната чистая."),
        DrillCard(front:"Mi hermana ___ joven.",back:"es (SER — характеристика)",context:nil,translation:"Моя сестра молодая."),
        DrillCard(front:"Mi abuela ___ muy bien para su edad.",back:"está (ESTAR — состояние)",context:nil,translation:"Бабушка отлично для своего возраста."),
        DrillCard(front:"___ necesario practicar.",back:"Es (SER — безличное)",context:nil,translation:"Необходимо практиковаться."),
        DrillCard(front:"No ___ mal para ser principiante.",back:"está (ESTAR — оценка результата)",context:nil,translation:"Неплохо для новичка."),
        DrillCard(front:"El concierto ___ a las ocho.",back:"es (SER — время события)",context:nil,translation:"Концерт в восемь."),
        DrillCard(front:"Todo ___ claro. (= понятно)",back:"está (ESTAR — результат)",context:nil,translation:"Всё понятно."),
        DrillCard(front:"Yo no ___ de aquí.",back:"soy (SER — происхождение)",context:nil,translation:"Я не отсюда."),
        DrillCard(front:"Ellos ___ muy felices juntos.",back:"son (SER — постоянное)",context:nil,translation:"Они очень счастливы вместе."),
        DrillCard(front:"Hoy ___ un día especial.",back:"es (SER — характеристика)",context:nil,translation:"Сегодня особенный день."),
        DrillCard(front:"Yo ___ listo para el examen.",back:"estoy (ESTAR — готовность)",context:nil,translation:"Я готов к экзамену."),
        DrillCard(front:"El café ___ caliente.",back:"está (ESTAR — температура)",context:nil,translation:"Кофе горячий."),
    ]
}

// MARK: - Pronouns Drill Data

struct PronounsDrill {

    static let cheatSheet = """
    ЛИЧНЫЕ МЕСТОИМЕНИЯ (подлежащее):
    yo — я
    tú — ты
    él / ella / usted — он / она / Вы
    nosotros / nosotras — мы
    vosotros / vosotras — вы
    ellos / ellas / ustedes — они / Вы (мн.)

    ПРЯМОЕ ДОПОЛНЕНИЕ (Objeto Directo):
    me — меня         nos — нас
    te — тебя          os — вас
    lo — его            los — их (м.)
    la — её             las — их (ж.)

    Пример: Veo a Juan → Lo veo (Вижу его)
    Пример: Compro las flores → Las compro (Покупаю их)

    КОСВЕННОЕ ДОПОЛНЕНИЕ (Objeto Indirecto):
    me — мне           nos — нам
    te — тебе           os — вам
    le — ему/ей         les — им

    Пример: Doy un libro a María → Le doy un libro (Даю ей книгу)

    ДВОЙНЫЕ МЕСТОИМЕНИЯ:
    Порядок: косвенное + прямое (перед глаголом)
    le/les + lo/la/los/las → SE lo/la/los/las

    Пример: Doy el libro a Juan → Se lo doy (Даю ему его)
    Пример: Digo la verdad a ella → Se la digo (Говорю ей её)

    ВОЗВРАТНЫЕ МЕСТОИМЕНИЯ:
    me — себя (yo)     nos — себя (nosotros)
    te — себя (tú)      os — себя (vosotros)
    se — себя (él/ellos)

    Пример: Me lavo (Я моюсь), Se levanta (Он встаёт)

    ПРЕДЛОЖНЫЕ МЕСТОИМЕНИЯ (после предлогов):
    a mí — мне          a nosotros — нам
    a ti — тебе          a vosotros — вам
    a él/ella — ему/ей   a ellos/ellas — им
    conmigo — со мной
    contigo — с тобой
    consigo — с собой

    ПОЗИЦИЯ МЕСТОИМЕНИЙ:
    • Перед спрягаемым глаголом: Lo veo. Me gusta. Te llamo.
    • После инфинитива (слитно): Quiero verlo. Voy a comprarlo.
    • После герундия (слитно): Estoy haciéndolo. Está diciéndome.
    • После утвердительного imperativo: ¡Dime! ¡Hazlo! ¡Siéntate!
    • Перед отрицательным imperativo: ¡No me digas! ¡No lo hagas!
    """

    static let cards: [DrillCard] = [
        // Subject pronouns
        DrillCard(front:"___ hablo español.",back:"Yo",context:nil,translation:"Я говорю по-испански."),
        DrillCard(front:"___ eres mi amigo.",back:"Tú",context:nil,translation:"Ты мой друг."),
        DrillCard(front:"___ es profesor.",back:"Él",context:nil,translation:"Он преподаватель."),
        DrillCard(front:"___ somos estudiantes.",back:"Nosotros",context:nil,translation:"Мы студенты."),
        DrillCard(front:"___ son de España.",back:"Ellos",context:nil,translation:"Они из Испании."),
        // Direct object: lo/la/los/las
        DrillCard(front:"Veo a Juan. → ___ veo.",back:"Lo (прямое, м.р.)",context:"Lo veo.",translation:"Вижу его."),
        DrillCard(front:"Veo a María. → ___ veo.",back:"La (прямое, ж.р.)",context:"La veo.",translation:"Вижу её."),
        DrillCard(front:"Compro los libros. → ___ compro.",back:"Los (прямое, м.р. мн.)",context:"Los compro.",translation:"Покупаю их."),
        DrillCard(front:"Leo las cartas. → ___ leo.",back:"Las (прямое, ж.р. мн.)",context:"Las leo.",translation:"Читаю их."),
        DrillCard(front:"¿Conoces a Pedro? — Sí, ___ conozco.",back:"lo (прямое)",context:nil,translation:"Да, я его знаю."),
        DrillCard(front:"¿Ves la película? — Sí, ___ veo.",back:"la (прямое)",context:nil,translation:"Да, я её смотрю."),
        DrillCard(front:"___ quiero mucho. (a ti)",back:"Te (прямое)",context:"Te quiero mucho.",translation:"Я тебя очень люблю."),
        DrillCard(front:"Ella ___ llama cada día. (a mí)",back:"me (прямое)",context:"Ella me llama.",translation:"Она мне звонит каждый день."),
        DrillCard(front:"___ invito a la fiesta. (a vosotros)",back:"Os (прямое)",context:"Os invito.",translation:"Приглашаю вас на вечеринку."),
        DrillCard(front:"El profesor ___ ve. (a nosotros)",back:"nos (прямое)",context:"Nos ve.",translation:"Преподаватель нас видит."),
        // Indirect object: me/te/le/nos/les
        DrillCard(front:"Doy un libro a María. → ___ doy un libro.",back:"Le (косвенное)",context:"Le doy un libro.",translation:"Даю ей книгу."),
        DrillCard(front:"Escribo a mis padres. → ___ escribo.",back:"Les (косвенное, мн.)",context:"Les escribo.",translation:"Пишу им."),
        DrillCard(front:"¿___ puedes ayudar? (a mí)",back:"Me (косвенное)",context:"¿Me puedes ayudar?",translation:"Можешь мне помочь?"),
        DrillCard(front:"___ digo la verdad. (a ti)",back:"Te (косвенное)",context:"Te digo la verdad.",translation:"Говорю тебе правду."),
        DrillCard(front:"El médico ___ receta pastillas. (a nosotros)",back:"nos (косвенное)",context:"Nos receta pastillas.",translation:"Врач нам прописывает таблетки."),
        DrillCard(front:"___ gusta el café. (a mí)",back:"Me (косвенное + gustar)",context:"Me gusta el café.",translation:"Мне нравится кофе."),
        DrillCard(front:"___ gustan los libros. (a ella)",back:"Le (косвенное + gustar)",context:"Le gustan los libros.",translation:"Ей нравятся книги."),
        DrillCard(front:"¿___ interesa el arte? (a ti)",back:"Te (косвенное + interesar)",context:"¿Te interesa el arte?",translation:"Тебе интересно искусство?"),
        DrillCard(front:"___ duele la cabeza. (a él)",back:"Le (косвенное + doler)",context:"Le duele la cabeza.",translation:"У него болит голова."),
        DrillCard(front:"___ molesta el ruido. (a nosotros)",back:"Nos (косвенное)",context:"Nos molesta el ruido.",translation:"Нас раздражает шум."),
        // Double pronouns: se lo/la
        DrillCard(front:"Doy el libro a Juan. → ___ ___ doy.",back:"Se lo (le+lo → se lo)",context:"Se lo doy.",translation:"Даю ему его."),
        DrillCard(front:"Digo la verdad a ella. → ___ ___ digo.",back:"Se la (le+la → se la)",context:"Se la digo.",translation:"Говорю ей её (правду)."),
        DrillCard(front:"Compro flores a mi madre. → ___ ___ compro.",back:"Se las (le+las → se las)",context:"Se las compro.",translation:"Покупаю ей их (цветы)."),
        DrillCard(front:"Envío los documentos al jefe. → ___ ___ envío.",back:"Se los (le+los → se los)",context:"Se los envío.",translation:"Отправляю ему их."),
        DrillCard(front:"¿___ ___ das? (el libro, a mí)",back:"Me lo (косв.+прям.)",context:"¿Me lo das?",translation:"Ты мне его дашь?"),
        DrillCard(front:"___ ___ doy mañana. (la carta, a ti)",back:"Te la (косв.+прям.)",context:"Te la doy mañana.",translation:"Дам тебе её завтра."),
        DrillCard(front:"Le + lo = ?",back:"Se lo (le→se перед lo/la/los/las)",context:nil,translation:"Правило: le+lo → se lo"),
        DrillCard(front:"Les + las = ?",back:"Se las (les→se перед lo/la/los/las)",context:nil,translation:"Правило: les+las → se las"),
        // Reflexive pronouns
        DrillCard(front:"___ levanto a las siete.",back:"Me (возвратное, yo)",context:"Me levanto.",translation:"Я встаю в семь."),
        DrillCard(front:"___ duchas por la mañana.",back:"Te (возвратное, tú)",context:"Te duchas.",translation:"Ты моешься утром."),
        DrillCard(front:"Ella ___ viste rápido.",back:"se (возвратное, ella)",context:"Se viste.",translation:"Она быстро одевается."),
        DrillCard(front:"___ acostamos a las once.",back:"Nos (возвратное, nosotros)",context:"Nos acostamos.",translation:"Мы ложимся в одиннадцать."),
        DrillCard(front:"Ellos ___ despiertan temprano.",back:"se (возвратное, ellos)",context:"Se despiertan.",translation:"Они просыпаются рано."),
        DrillCard(front:"___ siento bien hoy.",back:"Me (возвратное, yo)",context:"Me siento bien.",translation:"Я чувствую себя хорошо."),
        DrillCard(front:"¿___ llamas? (tú)",back:"Cómo te (возвратное)",context:"¿Cómo te llamas?",translation:"Как тебя зовут?"),
        // Prepositional pronouns
        DrillCard(front:"Este regalo es para ___. (yo)",back:"mí",context:"Es para mí.",translation:"Этот подарок для меня."),
        DrillCard(front:"Voy con ___. (tú)",back:"contigo",context:"Voy contigo.",translation:"Иду с тобой."),
        DrillCard(front:"Hablo de ___. (él)",back:"él",context:"Hablo de él.",translation:"Говорю о нём."),
        DrillCard(front:"Vengo con ___. (yo)",back:"conmigo",context:"Ven conmigo.",translation:"Иди со мной."),
        DrillCard(front:"Es para ___. (nosotros)",back:"nosotros",context:"Es para nosotros.",translation:"Это для нас."),
        DrillCard(front:"Lo hago por ___. (tú)",back:"ti",context:"Lo hago por ti.",translation:"Делаю это ради тебя."),
        DrillCard(front:"Piensa en ___. (ella)",back:"ella",context:"Piensa en ella.",translation:"Думает о ней."),
        // Position: before/after verb
        DrillCard(front:"Quiero ver + lo = ?",back:"Quiero verlo (слитно после инфинитива)",context:nil,translation:"Хочу это увидеть."),
        DrillCard(front:"Estoy haciendo + lo = ?",back:"Estoy haciéndolo (слитно после герундия)",context:nil,translation:"Делаю это (сейчас)."),
        DrillCard(front:"¡Di + me + lo! = ?",back:"¡Dímelo! (слитно после imperativo)",context:nil,translation:"Скажи мне это!"),
        DrillCard(front:"¡No + me + digas! = ?",back:"¡No me digas! (раздельно, перед глаголом)",context:nil,translation:"Не говори мне! / Да ладно!"),
        DrillCard(front:"Voy a comprar + lo = ?",back:"Voy a comprarlo (слитно после инфинитива)",context:nil,translation:"Собираюсь это купить."),
        DrillCard(front:"Está diciendo + me = ?",back:"Está diciéndome (слитно после герундия)",context:nil,translation:"Говорит мне (сейчас)."),
        DrillCard(front:"¡Sienta + se! = ?",back:"¡Siéntese! (слитно + ударение)",context:nil,translation:"Садитесь!"),
        DrillCard(front:"¡No + se + siente! = ?",back:"¡No se siente! (раздельно при отрицании)",context:nil,translation:"Не садитесь!"),
        // Mixed practice
        DrillCard(front:"___ lo dije ayer. (a él)",back:"Se (le→se перед lo)",context:"Se lo dije ayer.",translation:"Я ему это сказал вчера."),
        DrillCard(front:"Ella ___ quiere. (a mí)",back:"me",context:"Ella me quiere.",translation:"Она меня любит."),
        DrillCard(front:"No ___ conozco. (a ella)",back:"la",context:"No la conozco.",translation:"Я её не знаю."),
        DrillCard(front:"¿___ ayudas? (a mí)",back:"Me",context:"¿Me ayudas?",translation:"Поможешь мне?"),
        DrillCard(front:"___ llamo Pedro. (yo, возвратное)",back:"Me",context:"Me llamo Pedro.",translation:"Меня зовут Педро."),
        DrillCard(front:"¿Puedes dar___ ? (a mí + lo)",back:"dármelo (dar+me+lo)",context:"¿Puedes dármelo?",translation:"Можешь мне это дать?"),
        DrillCard(front:"Voy a decír___ . (a ella + lo)",back:"decírselo (decir+se+lo)",context:"Voy a decírselo.",translation:"Собираюсь ей это сказать."),
        DrillCard(front:"___ vemos mañana. (nosotros, возвратное)",back:"Nos",context:"Nos vemos mañana.",translation:"Увидимся завтра."),
        DrillCard(front:"¿___ gusta bailar? (a ti)",back:"Te",context:"¿Te gusta bailar?",translation:"Тебе нравится танцевать?"),
        DrillCard(front:"No ___ importa. (a mí)",back:"me",context:"No me importa.",translation:"Мне всё равно."),
        // lo/la vs le distinction
        DrillCard(front:"lo = ?",back:"его (прямое дополнение, м.р.)",context:"Lo veo — Вижу его.",translation:nil),
        DrillCard(front:"la = ?",back:"её (прямое дополнение, ж.р.)",context:"La conozco — Знаю её.",translation:nil),
        DrillCard(front:"le = ?",back:"ему/ей (косвенное дополнение)",context:"Le doy — Даю ему/ей.",translation:nil),
        DrillCard(front:"les = ?",back:"им (косвенное дополнение, мн.)",context:"Les escribo — Пишу им.",translation:nil),
        DrillCard(front:"lo vs le: Veo a Juan → ?",back:"Lo veo (прямое — кого вижу)",context:nil,translation:"Вижу его (lo = прямое)."),
        DrillCard(front:"lo vs le: Doy un libro a Juan → ?",back:"Le doy (косвенное — кому даю)",context:nil,translation:"Даю ему (le = косвенное)."),
        // conmigo/contigo
        DrillCard(front:"con + yo = ?",back:"conmigo (не con yo!)",context:"Ven conmigo.",translation:"Иди со мной."),
        DrillCard(front:"con + tú = ?",back:"contigo (не con tú!)",context:"Voy contigo.",translation:"Иду с тобой."),
        DrillCard(front:"con + él = ?",back:"con él (без изменений)",context:"Hablo con él.",translation:"Говорю с ним."),
        // More practice
        DrillCard(front:"Ella ___ escribe una carta. (a nosotros)",back:"nos",context:"Nos escribe una carta.",translation:"Она пишет нам письмо."),
        DrillCard(front:"___ presento a mi amigo. (a ti)",back:"Te",context:"Te presento a mi amigo.",translation:"Представляю тебе моего друга."),
        DrillCard(front:"No ___ entiendo. (a usted)",back:"le/lo",context:"No le entiendo.",translation:"Я Вас не понимаю."),
        DrillCard(front:"___ echo de menos. (a ti)",back:"Te",context:"Te echo de menos.",translation:"Скучаю по тебе."),
        DrillCard(front:"¿___ ___ puedes repetir? (a mí + lo)",back:"Me lo",context:"¿Me lo puedes repetir?",translation:"Можешь мне это повторить?"),
        DrillCard(front:"No ___ ___ digas. (a él + lo)",back:"se lo",context:"No se lo digas.",translation:"Не говори ему это."),
        DrillCard(front:"___ ___ compré ayer. (a ella + las)",back:"Se las",context:"Se las compré ayer.",translation:"Купил ей их вчера."),
        DrillCard(front:"Dame + lo = ?",back:"Dámelo",context:"¡Dámelo!",translation:"Дай мне это!"),
        DrillCard(front:"Di + le + lo = ?",back:"Díselo (le→se)",context:"¡Díselo!",translation:"Скажи ему это!"),
    ]
}

// MARK: - TENER Drill Data

struct TenerDrill {

    static let cheatSheet = """
    СПРЯЖЕНИЕ TENER — PRESENTE:
    yo tengo — я имею / у меня есть
    tú tienes — ты имеешь / у тебя есть
    él/ella/usted tiene — он/она имеет / у него есть
    nosotros tenemos — мы имеем / у нас есть
    ellos/ellas/ustedes tienen — они имеют / у них есть

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    TENER = ВЛАДЕНИЕ (иметь что-то):
    • Tengo un perro — У меня есть собака
    • Ella tiene dos hermanos — У неё два брата
    • No tenemos coche — У нас нет машины

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    TENER + ВОЗРАСТ (не ser!):
    • Tengo 25 años — Мне 25 лет (НЕ soy 25!)
    • ¿Cuántos años tienes? — Сколько тебе лет?
    • Mi abuela tiene 80 años — Бабушке 80 лет

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    TENER + 6 БАЗОВЫХ СОСТОЯНИЙ:
    • tener hambre — быть голодным (букв. «иметь голод»)
    • tener sed — хотеть пить
    • tener sueño — хотеть спать
    • tener frío — мёрзнуть
    • tener calor — быть жарко
    • tener miedo — бояться

    Пример всех форм (tener hambre):
    • yo tengo hambre — я голоден
    • tú tienes hambre — ты голоден
    • él tiene hambre — он голоден
    • nosotros tenemos hambre — мы голодны
    • ellos tienen hambre — они голодны
    """

    static let cards: [DrillCard] = [
        // --- Спряжение: базовое владение ---
        DrillCard(front:"Yo ___ un perro.",back:"tengo (TENER — yo)",context:"Yo tengo un perro.",translation:"У меня есть собака."),
        DrillCard(front:"Tú ___ dos hermanos.",back:"tienes (TENER — tú)",context:"Tú tienes dos hermanos.",translation:"У тебя два брата."),
        DrillCard(front:"Él ___ un coche nuevo.",back:"tiene (TENER — él)",context:"Él tiene un coche nuevo.",translation:"У него новая машина."),
        DrillCard(front:"Nosotros ___ una casa grande.",back:"tenemos (TENER — nosotros)",context:"Nosotros tenemos una casa grande.",translation:"У нас большой дом."),
        DrillCard(front:"Ellos ___ muchos amigos.",back:"tienen (TENER — ellos)",context:"Ellos tienen muchos amigos.",translation:"У них много друзей."),
        DrillCard(front:"¿___ tú tiempo?",back:"Tienes (TENER — tú)",context:"¿Tienes tiempo?",translation:"У тебя есть время?"),
        // --- Возраст ---
        DrillCard(front:"Yo ___ 25 años.",back:"tengo (TENER — возраст)",context:"Yo tengo 25 años.",translation:"Мне 25 лет."),
        DrillCard(front:"¿Cuántos años ___ tú?",back:"tienes (TENER — возраст)",context:"¿Cuántos años tienes?",translation:"Сколько тебе лет?"),
        DrillCard(front:"Mi abuela ___ 80 años.",back:"tiene (TENER — возраст)",context:"Mi abuela tiene 80 años.",translation:"Бабушке 80 лет."),
        DrillCard(front:"El niño ___ 5 años.",back:"tiene (TENER — возраст)",context:"El niño tiene 5 años.",translation:"Ребёнку 5 лет."),
        // --- 6 базовых состояний ---
        DrillCard(front:"Yo ___ hambre.",back:"tengo (tener hambre — быть голодным)",context:"Tengo mucha hambre.",translation:"Я очень голоден."),
        DrillCard(front:"Ella ___ sed.",back:"tiene (tener sed — хотеть пить)",context:"Ella tiene sed.",translation:"Она хочет пить."),
        DrillCard(front:"Nosotros ___ sueño.",back:"tenemos (tener sueño — хотеть спать)",context:"Tenemos mucho sueño.",translation:"Мы очень хотим спать."),
        DrillCard(front:"El niño ___ miedo.",back:"tiene (tener miedo — бояться)",context:"El niño tiene miedo de la oscuridad.",translation:"Ребёнок боится темноты."),
        DrillCard(front:"Yo ___ frío.",back:"tengo (tener frío — мёрзнуть)",context:"Tengo mucho frío.",translation:"Мне очень холодно."),
        DrillCard(front:"Ella ___ calor.",back:"tiene (tener calor — быть жарко)",context:"Tiene mucho calor.",translation:"Ей очень жарко."),
        // --- Ещё владение и спряжение ---
        DrillCard(front:"Ella ___ 3 gatos y 2 perros.",back:"tiene (TENER — владение)",context:"Tiene 3 gatos y 2 perros.",translation:"У неё 3 кота и 2 собаки."),
        DrillCard(front:"Nosotros no ___ coche.",back:"tenemos (TENER — отрицание)",context:"No tenemos coche.",translation:"У нас нет машины."),
        DrillCard(front:"¿Cuántos hijos ___ usted?",back:"tiene (TENER — usted)",context:"¿Cuántos hijos tiene?",translation:"Сколько у Вас детей?"),
        DrillCard(front:"Los estudiantes ___ muchos exámenes.",back:"tienen (TENER — ellos)",context:"Tienen muchos exámenes.",translation:"У студентов много экзаменов."),
        DrillCard(front:"Yo ___ una pregunta.",back:"tengo (TENER — yo)",context:"Tengo una pregunta.",translation:"У меня есть вопрос."),
        DrillCard(front:"Ella no ___ hermanos.",back:"tiene (TENER — отрицание)",context:"No tiene hermanos.",translation:"У неё нет братьев и сестёр."),
        DrillCard(front:"___ mucho trabajo hoy.",back:"Tengo (TENER — yo)",context:"Tengo mucho trabajo.",translation:"У меня много работы сегодня."),
        DrillCard(front:"Nosotros ___ tiempo libre.",back:"tenemos (TENER — nosotros)",context:"Tenemos tiempo libre.",translation:"У нас есть свободное время."),
        DrillCard(front:"Ellos ___ una idea.",back:"tienen (TENER — ellos)",context:"Tienen una buena idea.",translation:"У них есть хорошая идея."),
        // --- Ещё возраст ---
        DrillCard(front:"¿Cuántos años ___ tu madre?",back:"tiene (TENER — возраст)",context:"¿Cuántos años tiene?",translation:"Сколько лет твоей маме?"),
        DrillCard(front:"Yo ___ 18 años.",back:"tengo (TENER — возраст)",context:"Tengo 18 años.",translation:"Мне 18 лет."),
        DrillCard(front:"Возраст по-испански: мне 20 лет = ?",back:"Tengo 20 años (TENER, не SER!)",context:"Tengo veinte años.",translation:"Мне 20 лет."),
        DrillCard(front:"Сколько тебе лет? = ?",back:"¿Cuántos años tienes?",context:nil,translation:"Сколько тебе лет?"),
        // --- Ещё состояния: разные формы ---
        DrillCard(front:"El bebé ___ sueño.",back:"tiene (tener sueño)",context:"El bebé tiene mucho sueño.",translation:"Малыш очень хочет спать."),
        DrillCard(front:"Los niños ___ miedo de la tormenta.",back:"tienen (tener miedo)",context:"Los niños tienen miedo.",translation:"Дети боятся грозы."),
        DrillCard(front:"Nosotros ___ hambre después de clase.",back:"tenemos (tener hambre)",context:"Tenemos hambre.",translation:"Мы голодны после занятий."),
        DrillCard(front:"Yo ___ mucho frío en invierno.",back:"tengo (tener frío)",context:"Tengo mucho frío.",translation:"Мне очень холодно зимой."),
        DrillCard(front:"¿No ___ (tú) calor con ese abrigo?",back:"tienes (tener calor)",context:"¿No tienes calor?",translation:"Тебе не жарко в этом пальто?"),
        // --- Определения: 6 состояний ---
        DrillCard(front:"tener hambre = ?",back:"быть голодным (букв. «иметь голод»)",context:nil,translation:"Tengo hambre — Я голоден."),
        DrillCard(front:"tener sed = ?",back:"хотеть пить",context:nil,translation:"Tengo sed — Я хочу пить."),
        DrillCard(front:"tener sueño = ?",back:"хотеть спать",context:nil,translation:"Tengo sueño — Я хочу спать."),
        DrillCard(front:"tener miedo = ?",back:"бояться",context:nil,translation:"Tengo miedo — Мне страшно."),
        DrillCard(front:"tener frío = ?",back:"мёрзнуть, мне холодно",context:nil,translation:"Tengo frío — Мне холодно."),
        DrillCard(front:"tener calor = ?",back:"быть жарко, мне жарко",context:nil,translation:"Tengo calor — Мне жарко."),
        // --- Новые карточки: спряжение в контексте ---
        DrillCard(front:"Yo ___ un libro interesante.",back:"tengo (TENER — yo)",context:"Tengo un libro interesante.",translation:"У меня есть интересная книга."),
        DrillCard(front:"¿___ (tú) hermanos?",back:"Tienes (TENER — tú)",context:"¿Tienes hermanos?",translation:"У тебя есть братья/сёстры?"),
        DrillCard(front:"Ella ___ una familia grande.",back:"tiene (TENER — ella)",context:"Ella tiene una familia grande.",translation:"У неё большая семья."),
        DrillCard(front:"Nosotros ___ un gato negro.",back:"tenemos (TENER — nosotros)",context:"Tenemos un gato negro.",translation:"У нас чёрный кот."),
        DrillCard(front:"Ellos no ___ dinero.",back:"tienen (TENER — отрицание)",context:"Ellos no tienen dinero.",translation:"У них нет денег."),
        DrillCard(front:"¿___ usted hijos?",back:"Tiene (TENER — usted)",context:"¿Tiene usted hijos?",translation:"У Вас есть дети?"),
        // --- Новые карточки: возраст в контексте ---
        DrillCard(front:"Mi hermano ___ 10 años.",back:"tiene (TENER — возраст)",context:"Mi hermano tiene 10 años.",translation:"Моему брату 10 лет."),
        DrillCard(front:"¿Cuántos años ___ ella?",back:"tiene (TENER — возраст)",context:"¿Cuántos años tiene ella?",translation:"Сколько ей лет?"),
        // --- Новые карточки: состояния в контексте ---
        DrillCard(front:"Tú ___ hambre, ¿no?",back:"tienes (tener hambre)",context:"Tienes hambre, ¿no?",translation:"Ты голоден, да?"),
        DrillCard(front:"Ellos ___ sed después del fútbol.",back:"tienen (tener sed)",context:"Tienen sed después del fútbol.",translation:"Они хотят пить после футбола."),
        DrillCard(front:"Yo ___ miedo de los perros.",back:"tengo (tener miedo de)",context:"Tengo miedo de los perros.",translation:"Я боюсь собак."),
        DrillCard(front:"Ella ___ sueño por la noche.",back:"tiene (tener sueño)",context:"Ella tiene sueño por la noche.",translation:"Она хочет спать вечером."),
        DrillCard(front:"Nosotros ___ frío en la montaña.",back:"tenemos (tener frío)",context:"Tenemos frío en la montaña.",translation:"Нам холодно в горах."),
        DrillCard(front:"Él ___ calor en verano.",back:"tiene (tener calor)",context:"Tiene calor en verano.",translation:"Ему жарко летом."),
        // --- Перевод с русского ---
        DrillCard(front:"У меня есть кот. = ?",back:"Tengo un gato.",context:"Tengo un gato.",translation:"У меня есть кот."),
        DrillCard(front:"Мне 30 лет. = ?",back:"Tengo 30 años. (TENER, не SER!)",context:"Tengo 30 años.",translation:"Мне 30 лет."),
        DrillCard(front:"Мне холодно. = ?",back:"Tengo frío. (TENER, не ESTOY!)",context:"Tengo frío.",translation:"Мне холодно."),
        DrillCard(front:"Я голоден. = ?",back:"Tengo hambre. (TENER, не SOY/ESTOY!)",context:"Tengo hambre.",translation:"Я голоден."),
        DrillCard(front:"У неё нет братьев. = ?",back:"No tiene hermanos.",context:"Ella no tiene hermanos.",translation:"У неё нет братьев."),
        DrillCard(front:"Мне страшно. = ?",back:"Tengo miedo.",context:"Tengo miedo.",translation:"Мне страшно."),
    ]
}

// MARK: - A1: TENER — расширенные выражения

struct TenerA1Drill {

    static let cheatSheet = """
    TENER QUE + INFINITIVO (должен, обязан):
    • Tengo que estudiar — Я должен учиться
    • Tienes que comer — Ты должен поесть
    • Tiene que ir al médico — Он должен к врачу
    • Tenemos que salir — Мы должны выйти
    • Tienen que trabajar — Они должны работать

    Отрицание: No tienes que ir = Ты не обязан идти

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    HAY QUE + INFINITIVO (безлично: нужно, надо):
    • Hay que estudiar — Надо учиться
    • Hay que tener paciencia — Нужно иметь терпение

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    IMPERATIVO TEN (ты — повелительная форма):
    • ¡Ten cuidado! — Будь осторожен!
    • Ten en cuenta que... — Имей в виду, что...

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    TENER + РАСШИРЕННЫЕ СОСТОЯНИЯ:
    • tener prisa — спешить
    • tener razón — быть правым
    • tener suerte — быть везучим
    • tener cuidado — быть осторожным
    • tener ganas de — хотеть (иметь желание)
    • tener éxito — иметь успех
    • tener vergüenza — стыдиться
    • tener la culpa — быть виноватым

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    ИДИОМАТИЧЕСКИЕ ВЫРАЖЕНИЯ:
    • tener en cuenta — иметь в виду, учитывать
    • tener sentido — иметь смысл
    • tener lugar — проходить, состояться
    • no tener ni idea — понятия не иметь
    • tener dolor de... — иметь боль (болит...)
    • tener buena/mala memoria — хорошая/плохая память

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    VOSOTROS: tenéis
    • ¿Tenéis planes? — У вас есть планы?
    • Tenéis mucha suerte — Вам очень везёт

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    TENER vs HAY vs SER:
    • Tengo un gato (TENER — владение)
    • Hay una farmacia (HAY — существование)
    • Tengo 30 años (TENER — возраст, НЕ soy!)
    • Tengo frío (TENER — ощущение, НЕ estoy!)
    """

    static let cards: [DrillCard] = [
        // --- Tener que + infinitivo ---
        DrillCard(front:"Yo ___ que estudiar.",back:"tengo (tener que — должен)",context:"Tengo que estudiar.",translation:"Я должен учиться."),
        DrillCard(front:"Tú ___ que comer.",back:"tienes (tener que — должен)",context:"Tienes que comer.",translation:"Ты должен поесть."),
        DrillCard(front:"Él ___ que ir al médico.",back:"tiene (tener que — должен)",context:"Tiene que ir al médico.",translation:"Он должен к врачу."),
        DrillCard(front:"Nosotros ___ que salir.",back:"tenemos (tener que — должны)",context:"Tenemos que salir.",translation:"Мы должны выйти."),
        DrillCard(front:"Ellos ___ que trabajar.",back:"tienen (tener que — должны)",context:"Tienen que trabajar.",translation:"Они должны работать."),
        DrillCard(front:"¿___ que hacer algo?",back:"Tienes (tener que — должен ли)",context:"¿Tienes que hacer algo?",translation:"Тебе нужно что-то делать?"),
        DrillCard(front:"No ___ que ir, si no quieres.",back:"tienes (no tener que — не обязан)",context:"No tienes que ir.",translation:"Ты не обязан идти."),
        DrillCard(front:"¿Qué ___ que hacer primero?",back:"tengo (tener que — что должен)",context:"¿Qué tengo que hacer?",translation:"Что мне нужно сделать первым?"),
        DrillCard(front:"Yo ___ que irme ya.",back:"tengo (tener que — должен уйти)",context:"Tengo que irme.",translation:"Мне пора уходить."),
        DrillCard(front:"Nosotros ___ que hablar con el jefe.",back:"tenemos (tener que)",context:"Tenemos que hablar con el jefe.",translation:"Нам нужно поговорить с начальником."),
        DrillCard(front:"Ella ___ que estudiar para el examen.",back:"tiene (tener que)",context:"Tiene que estudiar.",translation:"Ей нужно учиться к экзамену."),
        DrillCard(front:"No ___ que preocuparte.",back:"tienes (tener que — не должен)",context:"No tienes que preocuparte.",translation:"Тебе не нужно волноваться."),
        // --- Hay que (безличное) ---
        DrillCard(front:"___ que tener paciencia.",back:"Hay (hay que — безличное: нужно)",context:"Hay que tener paciencia.",translation:"Нужно иметь терпение."),
        DrillCard(front:"___ que estudiar más.",back:"Hay (hay que — безличное: надо)",context:"Hay que estudiar más.",translation:"Надо больше учиться."),
        DrillCard(front:"___ que ser puntual.",back:"Hay (hay que — безличное)",context:"Hay que ser puntual.",translation:"Нужно быть пунктуальным."),
        // --- Imperativo: Ten ---
        DrillCard(front:"___ cuidado con el perro.",back:"Ten (imperativo — будь осторожен)",context:"¡Ten cuidado!",translation:"Будь осторожен с собакой."),
        DrillCard(front:"___ en cuenta que el plazo es mañana.",back:"Ten (tener en cuenta — имей в виду)",context:"Ten en cuenta que el plazo es mañana.",translation:"Имей в виду, что срок завтра."),
        DrillCard(front:"___ cuidado con el escalón.",back:"Ten (imperativo: tener cuidado)",context:"¡Ten cuidado!",translation:"Осторожно со ступенькой."),
        DrillCard(front:"___ paciencia, todo va a salir bien.",back:"Ten (imperativo — имей терпение)",context:"¡Ten paciencia!",translation:"Имей терпение, всё будет хорошо."),
        // --- Расширенные состояния ---
        DrillCard(front:"___ prisa, llegamos tarde.",back:"Tengo (tener prisa — спешить)",context:"Tengo prisa.",translation:"Я спешу, опаздываем."),
        DrillCard(front:"Tú ___ razón.",back:"tienes (tener razón — быть правым)",context:"Tienes razón.",translation:"Ты прав."),
        DrillCard(front:"Ella ___ suerte.",back:"tiene (tener suerte — везти)",context:"Tiene mucha suerte.",translation:"Ей очень везёт."),
        DrillCard(front:"Yo ___ ganas de viajar.",back:"tengo (tener ganas de — хотеть)",context:"Tengo ganas de viajar.",translation:"Мне хочется путешествовать."),
        DrillCard(front:"Ella ___ éxito en su trabajo.",back:"tiene (tener éxito — иметь успех)",context:"Tiene éxito.",translation:"Она успешна в работе."),
        DrillCard(front:"Él ___ vergüenza.",back:"tiene (tener vergüenza — стыдиться)",context:"Tiene vergüenza.",translation:"Ему стыдно."),
        DrillCard(front:"Tú ___ la culpa.",back:"tienes (tener la culpa — быть виноватым)",context:"Tienes la culpa.",translation:"Ты виноват."),
        DrillCard(front:"Tú siempre ___ prisa por la mañana.",back:"tienes (tener prisa)",context:"Siempre tienes prisa.",translation:"Ты всегда утром спешишь."),
        DrillCard(front:"Él ___ razón, debemos cambiar el plan.",back:"tiene (tener razón)",context:"Tiene razón.",translation:"Он прав, надо менять план."),
        DrillCard(front:"Yo ___ ganas de dormir.",back:"tengo (tener ganas de — хотеть)",context:"Tengo ganas de dormir.",translation:"Хочу спать."),
        DrillCard(front:"Ella ___ vergüenza de hablar en público.",back:"tiene (tener vergüenza — стесняться)",context:"Tiene vergüenza de hablar en público.",translation:"Ей стыдно говорить публично."),
        // --- Идиоматические выражения ---
        DrillCard(front:"Esto no ___ sentido.",back:"tiene (tener sentido — иметь смысл)",context:"Esto no tiene sentido.",translation:"Это не имеет смысла."),
        DrillCard(front:"La reunión ___ lugar a las 10.",back:"tiene (tener lugar — проходить)",context:"La reunión tiene lugar a las 10.",translation:"Собрание проходит в 10."),
        DrillCard(front:"Ella ___ dolor de cabeza.",back:"tiene (tener dolor de — болит)",context:"Tiene dolor de cabeza.",translation:"У неё болит голова."),
        DrillCard(front:"Yo no ___ ni idea.",back:"tengo (no tener ni idea — понятия не иметь)",context:"No tengo ni idea.",translation:"Понятия не имею."),
        DrillCard(front:"Ella ___ buena memoria.",back:"tiene (TENER — характеристика)",context:"Tiene buena memoria.",translation:"У неё хорошая память."),
        DrillCard(front:"¿___ sentido esta frase?",back:"Tiene (tener sentido)",context:"¿Tiene sentido?",translation:"Эта фраза имеет смысл?"),
        DrillCard(front:"Yo no ___ la culpa de nada.",back:"tengo (tener la culpa)",context:"No tengo la culpa.",translation:"Я ни в чём не виноват."),
        // --- Vosotros ---
        DrillCard(front:"Vosotros ___ mucha suerte.",back:"tenéis (TENER — vosotros)",context:"Tenéis mucha suerte.",translation:"Вам очень везёт."),
        DrillCard(front:"¿___ (vosotros) planes para el fin de semana?",back:"Tenéis",context:"¿Tenéis planes?",translation:"У вас есть планы на выходные?"),
        // --- Tener vs Haber vs Ser ---
        DrillCard(front:"У меня есть кот. = Yo ___ un gato.",back:"tengo (TENER — владение)",context:"Tengo un gato.",translation:"У меня есть кот."),
        DrillCard(front:"Есть аптека рядом. = ___ una farmacia cerca.",back:"Hay (HABER — существование, не TENER!)",context:"Hay una farmacia cerca.",translation:"Есть аптека рядом."),
        DrillCard(front:"Мне 30 лет. = ___ 30 años.",back:"Tengo (TENER — возраст, не SOY!)",context:"Tengo 30 años.",translation:"Мне 30 лет."),
        DrillCard(front:"Мне холодно. = ___ frío.",back:"Tengo (TENER frío, не ESTOY frío!)",context:"Tengo frío.",translation:"Мне холодно."),
        DrillCard(front:"Я голоден. = ___ hambre.",back:"Tengo (TENER hambre, не SOY/ESTOY!)",context:"Tengo hambre.",translation:"Я голоден."),
        DrillCard(front:"¿___ algo que decir?",back:"Tienes (TENER — вопрос)",context:"¿Tienes algo que decir?",translation:"Тебе есть что сказать?"),
        // --- Определения ---
        DrillCard(front:"tener que + inf = ?",back:"должен (обязанность)",context:nil,translation:"Tengo que ir — Я должен идти."),
        DrillCard(front:"hay que + inf = ?",back:"нужно, надо (безлично)",context:nil,translation:"Hay que estudiar — Надо учиться."),
        DrillCard(front:"tener prisa = ?",back:"спешить",context:nil,translation:"Tengo prisa — Я спешу."),
        DrillCard(front:"tener razón = ?",back:"быть правым",context:nil,translation:"Tienes razón — Ты прав."),
        DrillCard(front:"tener suerte = ?",back:"быть везучим",context:nil,translation:"Tiene suerte — Ему везёт."),
        DrillCard(front:"tener ganas de = ?",back:"хотеть, иметь желание",context:nil,translation:"Tengo ganas de bailar — Хочу танцевать."),
        DrillCard(front:"tener cuidado = ?",back:"быть осторожным",context:nil,translation:"Ten cuidado — Будь осторожен."),
        DrillCard(front:"tener éxito = ?",back:"иметь успех",context:nil,translation:"Tiene éxito — Он успешен."),
        DrillCard(front:"tener la culpa = ?",back:"быть виноватым",context:nil,translation:"Tienes la culpa — Ты виноват."),
        DrillCard(front:"tener en cuenta = ?",back:"иметь в виду, учитывать",context:nil,translation:"Ten en cuenta — Имей в виду."),
        DrillCard(front:"tener sentido = ?",back:"иметь смысл",context:nil,translation:"Tiene sentido — Имеет смысл."),
        DrillCard(front:"tener lugar = ?",back:"проходить, состояться",context:nil,translation:"Tiene lugar — Проходит/состоится."),
        DrillCard(front:"no tener ni idea = ?",back:"понятия не иметь",context:nil,translation:"No tengo ni idea — Понятия не имею."),
        DrillCard(front:"tener dolor de = ?",back:"иметь боль (болит...)",context:nil,translation:"Tiene dolor de cabeza — У него болит голова."),
        DrillCard(front:"tener vergüenza = ?",back:"стыдиться, стесняться",context:nil,translation:"Tiene vergüenza — Ему стыдно."),
        // --- Новые карточки: tener que в контексте ---
        DrillCard(front:"Yo ___ que llamar a mi madre.",back:"tengo (tener que — должен позвонить)",context:"Tengo que llamar a mi madre.",translation:"Я должен позвонить маме."),
        DrillCard(front:"Tú ___ que dormir más.",back:"tienes (tener que — должен)",context:"Tienes que dormir más.",translation:"Ты должен больше спать."),
        DrillCard(front:"Nosotros ___ que comprar comida.",back:"tenemos (tener que — должны)",context:"Tenemos que comprar comida.",translation:"Нам нужно купить еду."),
        DrillCard(front:"Ellos ___ que limpiar la casa.",back:"tienen (tener que — должны)",context:"Tienen que limpiar la casa.",translation:"Они должны убрать дом."),
        // --- Новые: расширенные состояния в контексте ---
        DrillCard(front:"No ___ prisa, tenemos tiempo.",back:"tengas (no tener prisa — не спеши)",context:"No tengas prisa.",translation:"Не спеши, у нас есть время."),
        DrillCard(front:"Ella siempre ___ éxito en los exámenes.",back:"tiene (tener éxito)",context:"Siempre tiene éxito.",translation:"Она всегда сдаёт экзамены успешно."),
        DrillCard(front:"Yo ___ ganas de comer pizza.",back:"tengo (tener ganas de)",context:"Tengo ganas de comer pizza.",translation:"Мне хочется пиццу."),
        DrillCard(front:"Nosotros ___ suerte con el tiempo.",back:"tenemos (tener suerte)",context:"Tenemos suerte con el tiempo.",translation:"Нам повезло с погодой."),
        DrillCard(front:"Él ___ dolor de estómago.",back:"tiene (tener dolor de — болит)",context:"Tiene dolor de estómago.",translation:"У него болит живот."),
        DrillCard(front:"Yo no ___ la culpa del problema.",back:"tengo (tener la culpa)",context:"No tengo la culpa.",translation:"Это не моя вина."),
        DrillCard(front:"Esto ___ mucho sentido.",back:"tiene (tener sentido — иметь смысл)",context:"Esto tiene mucho sentido.",translation:"Это имеет большой смысл."),
        DrillCard(front:"El concierto ___ lugar en el parque.",back:"tiene (tener lugar — проходить)",context:"El concierto tiene lugar en el parque.",translation:"Концерт проходит в парке."),
    ]
}

// MARK: - English: Business Phrasal Verbs

struct PhrasalVerbsDrill {
    static let cheatSheet = """
    ФРАЗОВЫЕ ГЛАГОЛЫ В БИЗНЕСЕ И IT

    ЗАПУСК И РАЗВИТИЕ:
    • roll out — запустить, развернуть: We're rolling out a new feature.
    • ramp up — наращивать: We need to ramp up production.
    • scale up — масштабировать: Scale up the infrastructure.
    • spin up — запустить (сервер): Spin up a new instance.
    • set up — настроить: Set up the development environment.

    ЗАВЕРШЕНИЕ И УДАЛЕНИЕ:
    • phase out — постепенно убрать: Phase out the legacy system.
    • shut down — отключить: Shut down the old servers.
    • wind down — сворачивать: Wind down the project gradually.
    • wrap up — завершить: Let's wrap up this meeting.
    • sign off on — утвердить: The CTO signed off on the architecture.

    АНАЛИЗ И КОММУНИКАЦИЯ:
    • drill down — углубиться: Drill down into the root cause.
    • figure out — разобраться: We need to figure out why it crashed.
    • follow up — связаться повторно: I'll follow up on this tomorrow.
    • circle back — вернуться к теме: Let's circle back on this next week.
    • bring up — поднять вопрос: I'd like to bring up a concern.
    • loop in — подключить: Loop in the security team.
    • reach out — обратиться: Reach out to the vendor.

    УПРАВЛЕНИЕ:
    • carry out — выполнить: Carry out the migration plan.
    • take on — взять на себя: I'll take on this task.
    • hand off — передать: Hand off the project to Team B.
    • push back — возразить: We pushed back on the deadline.
    • opt in / opt out — подписаться / отказаться: Users opt in to notifications.
    """

    static let cards: [DrillCard] = [
        DrillCard(front:"roll out",back:"запустить, развернуть",context:"We're rolling out the new feature next week.",translation:"Мы запускаем новую фичу на следующей неделе."),
        DrillCard(front:"ramp up",back:"наращивать",context:"We need to ramp up hiring.",translation:"Нам нужно наращивать набор."),
        DrillCard(front:"scale up",back:"масштабировать вверх",context:"Scale up the servers for the launch.",translation:"Масштабируйте серверы к запуску."),
        DrillCard(front:"spin up",back:"запустить (сервер/среду)",context:"Spin up a new dev environment.",translation:"Запусти новую среду разработки."),
        DrillCard(front:"set up",back:"настроить",context:"Set up the CI/CD pipeline.",translation:"Настрой конвейер CI/CD."),
        DrillCard(front:"phase out",back:"постепенно убрать",context:"We're phasing out the legacy API.",translation:"Мы постепенно убираем старый API."),
        DrillCard(front:"shut down",back:"отключить",context:"Shut down the staging servers.",translation:"Отключи стейджинг серверы."),
        DrillCard(front:"wind down",back:"сворачивать",context:"We're winding down the project.",translation:"Мы сворачиваем проект."),
        DrillCard(front:"wrap up",back:"завершить",context:"Let's wrap up this meeting.",translation:"Давайте завершим совещание."),
        DrillCard(front:"sign off on",back:"утвердить",context:"The manager signed off on the release.",translation:"Менеджер утвердил релиз."),
        DrillCard(front:"drill down",back:"углубиться в детали",context:"Let's drill down into the metrics.",translation:"Давайте углубимся в метрики."),
        DrillCard(front:"figure out",back:"разобраться",context:"We need to figure out the root cause.",translation:"Нам нужно разобраться в первопричине."),
        DrillCard(front:"follow up",back:"связаться повторно",context:"I'll follow up with the client.",translation:"Свяжусь с клиентом повторно."),
        DrillCard(front:"circle back",back:"вернуться к вопросу",context:"Let's circle back on this next week.",translation:"Вернёмся к этому на следующей неделе."),
        DrillCard(front:"bring up",back:"поднять вопрос",context:"I'd like to bring up a concern.",translation:"Хочу поднять один вопрос."),
        DrillCard(front:"loop in",back:"подключить к обсуждению",context:"Loop in the security team.",translation:"Подключи команду безопасности."),
        DrillCard(front:"reach out",back:"обратиться",context:"Reach out to the vendor for pricing.",translation:"Обратись к вендору за ценами."),
        DrillCard(front:"carry out",back:"выполнить",context:"Carry out the migration plan.",translation:"Выполните план миграции."),
        DrillCard(front:"take on",back:"взять на себя",context:"I'll take on this feature.",translation:"Я возьму эту фичу на себя."),
        DrillCard(front:"hand off",back:"передать",context:"Hand off the project to the new team.",translation:"Передай проект новой команде."),
        DrillCard(front:"push back",back:"возразить, отказаться",context:"We pushed back on the tight deadline.",translation:"Мы возразили против жёсткого дедлайна."),
        DrillCard(front:"opt in",back:"подписаться, согласиться",context:"Users must opt in to email notifications.",translation:"Пользователи должны подписаться на уведомления."),
        DrillCard(front:"opt out",back:"отказаться, отписаться",context:"You can opt out at any time.",translation:"Вы можете отказаться в любое время."),
        DrillCard(front:"come up with",back:"придумать",context:"We came up with a creative solution.",translation:"Мы придумали креативное решение."),
        DrillCard(front:"run into",back:"столкнуться с проблемой",context:"We ran into a performance issue.",translation:"Мы столкнулись с проблемой производительности."),
        DrillCard(front:"look into",back:"изучить, расследовать",context:"I'll look into this bug.",translation:"Я изучу этот баг."),
        DrillCard(front:"point out",back:"указать, отметить",context:"She pointed out a flaw in the design.",translation:"Она указала на недостаток в дизайне."),
        DrillCard(front:"turn around",back:"развернуть (ситуацию), обработать",context:"We turned the project around in two weeks.",translation:"Мы развернули проект за две недели."),
        DrillCard(front:"break down",back:"разбить на части / сломаться",context:"Break down the epic into smaller tasks.",translation:"Разбей эпик на мелкие задачи."),
        DrillCard(front:"lay off",back:"уволить (по сокращению)",context:"The company laid off 200 employees.",translation:"Компания уволила 200 сотрудников."),
        DrillCard(front:"We need to ___ ___ hiring. (increase)",back:"ramp up",context:"We need to ramp up hiring.",translation:"Нужно наращивать набор."),
        DrillCard(front:"Let's ___ ___ this meeting. (finish)",back:"wrap up",context:"Let's wrap up.",translation:"Давайте завершим."),
        DrillCard(front:"I'll ___ ___ on this tomorrow. (contact again)",back:"follow up",context:"I'll follow up tomorrow.",translation:"Свяжусь завтра повторно."),
        DrillCard(front:"We ___ ___ a bug in production. (encountered)",back:"ran into",context:"We ran into a bug.",translation:"Мы столкнулись с багом."),
        DrillCard(front:"___ ___ the security team. (include)",back:"Loop in",context:"Loop in the security team.",translation:"Подключи безопасников."),
        DrillCard(front:"The CTO ___ ___ on the plan. (approved)",back:"signed off",context:"The CTO signed off on the plan.",translation:"CTO утвердил план."),
        DrillCard(front:"We're ___ ___ the old system. (gradually removing)",back:"phasing out",context:"We're phasing out the old system.",translation:"Мы убираем старую систему."),
        DrillCard(front:"___ ___ a new staging server. (start/create)",back:"Spin up",context:"Spin up a new server.",translation:"Запусти новый сервер."),
        DrillCard(front:"I'd like to ___ ___ a concern. (raise)",back:"bring up",context:"I'd like to bring up a concern.",translation:"Хочу поднять вопрос."),
        DrillCard(front:"Let's ___ ___ into the data. (analyze deeply)",back:"drill down",context:"Let's drill down into the data.",translation:"Углубимся в данные."),
    ]
}

// MARK: - English: IT Idioms

struct ITIdiomsDrill {
    static let cheatSheet = """
    ИДИОМЫ В IT И БИЗНЕСЕ

    ПРИОРИТЕТЫ:
    • low-hanging fruit — легко достижимое: Start with low-hanging fruit.
    • move the needle — дать ощутимый результат: Will this move the needle?
    • quick win — быстрая победа: Let's find some quick wins.
    • pain point — болевая точка: What are the customer pain points?

    КОММУНИКАЦИЯ:
    • on the same page — на одной волне: Are we on the same page?
    • touch base — связаться: Let's touch base next week.
    • keep in the loop — держать в курсе: Keep me in the loop.
    • heads up — предупреждение: Heads up, the deploy is tonight.

    РАБОТА:
    • bandwidth — ресурс/время: I don't have bandwidth for this.
    • deep dive — глубокий анализ: Let's do a deep dive.
    • boil the ocean — браться за невозможное: Don't boil the ocean.
    • push the envelope — расширять границы: We need to push the envelope.
    • think outside the box — мыслить нестандартно
    • at the end of the day — в конечном итоге
    • back to square one — начать с нуля
    • ballpark figure — приблизительная оценка: Give me a ballpark figure.
    • dogfooding — использование своего продукта: We dogfood our own tools.
    • eating your own dog food — то же что dogfooding
    • rubber duck debugging — отладка «утёнком»: объясни проблему утке
    • bikeshedding — споры о мелочах: Stop bikeshedding!
    • yak shaving — цепочка подзадач: This is classic yak shaving.
    """

    static let cards: [DrillCard] = [
        DrillCard(front:"low-hanging fruit",back:"легко достижимое",context:"Start with the low-hanging fruit.",translation:"Начни с самого лёгкого."),
        DrillCard(front:"move the needle",back:"дать ощутимый результат",context:"Will this feature move the needle?",translation:"Эта фича даст ощутимый результат?"),
        DrillCard(front:"quick win",back:"быстрая победа",context:"Let's find some quick wins.",translation:"Давайте найдём быстрые победы."),
        DrillCard(front:"pain point",back:"болевая точка",context:"What are the main pain points?",translation:"Какие основные болевые точки?"),
        DrillCard(front:"on the same page",back:"на одной волне, одинаково понимаем",context:"Let's make sure we're on the same page.",translation:"Убедимся, что мы одинаково понимаем."),
        DrillCard(front:"touch base",back:"связаться, обсудить",context:"Let's touch base next week.",translation:"Давай свяжемся на следующей неделе."),
        DrillCard(front:"keep in the loop",back:"держать в курсе",context:"Please keep me in the loop.",translation:"Держи меня в курсе, пожалуйста."),
        DrillCard(front:"heads up",back:"предупреждение",context:"Heads up — the deploy is tonight.",translation:"Предупреждаю — деплой сегодня ночью."),
        DrillCard(front:"bandwidth",back:"ресурс, время (неформ.)",context:"I don't have bandwidth for this.",translation:"У меня нет ресурсов на это."),
        DrillCard(front:"deep dive",back:"глубокий анализ",context:"Let's do a deep dive into the logs.",translation:"Давайте глубоко проанализируем логи."),
        DrillCard(front:"boil the ocean",back:"браться за невозможное",context:"Don't try to boil the ocean.",translation:"Не пытайся объять необъятное."),
        DrillCard(front:"think outside the box",back:"мыслить нестандартно",context:"We need to think outside the box.",translation:"Нужно мыслить нестандартно."),
        DrillCard(front:"at the end of the day",back:"в конечном итоге",context:"At the end of the day, results matter.",translation:"В конечном итоге, важны результаты."),
        DrillCard(front:"back to square one",back:"вернуться к началу",context:"The refactor failed — back to square one.",translation:"Рефакторинг провалился — начинаем сначала."),
        DrillCard(front:"ballpark figure",back:"приблизительная оценка",context:"Give me a ballpark figure.",translation:"Дай примерную оценку."),
        DrillCard(front:"dogfooding",back:"использование своего продукта",context:"We dogfood our own tools.",translation:"Мы используем свои собственные инструменты."),
        DrillCard(front:"bikeshedding",back:"споры о мелочах",context:"Stop bikeshedding and ship it!",translation:"Хватит спорить о мелочах — выпускайте!"),
        DrillCard(front:"yak shaving",back:"цепочка подзадач",context:"This is classic yak shaving.",translation:"Это классическая цепочка подзадач."),
        DrillCard(front:"rubber duck debugging",back:"метод отладки: объяснить проблему утке",context:"Try rubber duck debugging.",translation:"Попробуй объяснить проблему утёнку."),
        DrillCard(front:"push the envelope",back:"расширять границы",context:"We're pushing the envelope with this design.",translation:"Мы расширяем границы этим дизайном."),
        DrillCard(front:"take it offline",back:"обсудить отдельно",context:"Let's take this offline after the meeting.",translation:"Обсудим это отдельно после совещания."),
        DrillCard(front:"open a can of worms",back:"поднять сложный вопрос",context:"Changing the API will open a can of worms.",translation:"Смена API поднимет кучу проблем."),
        DrillCard(front:"scope creep",back:"расползание объёма",context:"Watch out for scope creep.",translation:"Следи за расползанием объёма."),
        DrillCard(front:"technical debt",back:"технический долг",context:"We're drowning in technical debt.",translation:"Мы тонем в техническом долге."),
        DrillCard(front:"silver bullet",back:"универсальное решение",context:"There's no silver bullet for this problem.",translation:"Для этой проблемы нет универсального решения."),
        DrillCard(front:"Will this ___ the ___? (make impact)",back:"move ... needle",context:"Will this move the needle?",translation:"Это даст результат?"),
        DrillCard(front:"Start with the ___ ___ ___. (easy tasks)",back:"low-hanging fruit",context:nil,translation:"Начни с самого простого."),
        DrillCard(front:"Keep me in the ___. (informed)",back:"loop",context:"Keep me in the loop.",translation:"Держи меня в курсе."),
        DrillCard(front:"I don't have ___ for this. (capacity)",back:"bandwidth",context:nil,translation:"У меня нет ресурсов на это."),
        DrillCard(front:"Give me a ___ ___. (rough estimate)",back:"ballpark figure",context:nil,translation:"Дай примерную оценку."),
    ]
}

// MARK: - English: Email Templates

struct EmailDrill {
    static let cheatSheet = """
    ШАБЛОНЫ ДЕЛОВЫХ ПИСЕМ

    ПРИВЕТСТВИЕ:
    • Dear Mr./Ms. [Name] — формальное
    • Hi [Name] — полуформальное (IT стандарт)
    • Hello team — для группы

    НАЧАЛО ПИСЬМА:
    • I'm writing to follow up on... — Пишу, чтобы уточнить...
    • I'm reaching out regarding... — Обращаюсь по поводу...
    • As discussed in our meeting... — Как обсуждали на встрече...
    • Further to our conversation... — В продолжение разговора...
    • I hope this email finds you well. — Надеюсь, у вас всё хорошо.

    ПРОСЬБА:
    • Could you please... — Не могли бы вы...
    • I'd appreciate it if you could... — Буду благодарен, если вы...
    • Would it be possible to... — Было бы возможно...
    • I was wondering if... — Мне интересно, не могли бы вы...

    ВЛОЖЕНИЯ:
    • Please find attached... — Во вложении...
    • I've attached... for your review. — Прикрепляю... для ознакомления.

    ЗАВЕРШЕНИЕ:
    • Looking forward to your response. — Жду вашего ответа.
    • Please let me know if you have any questions. — Дайте знать, если есть вопросы.
    • Don't hesitate to reach out. — Не стесняйтесь обращаться.

    ПОДПИСЬ:
    • Best regards / Kind regards — С уважением
    • Thanks / Many thanks — Спасибо
    • Cheers — Неформально (UK/AU)
    """

    static let cards: [DrillCard] = [
        DrillCard(front:"I'm writing to follow up on...",back:"Пишу, чтобы уточнить...",context:"I'm writing to follow up on our discussion yesterday.",translation:"Пишу, чтобы уточнить по поводу нашего обсуждения вчера."),
        DrillCard(front:"I'm reaching out regarding...",back:"Обращаюсь по поводу...",context:"I'm reaching out regarding the API integration.",translation:"Обращаюсь по поводу интеграции API."),
        DrillCard(front:"As discussed in our meeting...",back:"Как обсуждали на встрече...",context:"As discussed, here's the updated timeline.",translation:"Как обсуждали, вот обновлённые сроки."),
        DrillCard(front:"Could you please clarify...",back:"Не могли бы вы уточнить...",context:"Could you please clarify the requirements?",translation:"Не могли бы вы уточнить требования?"),
        DrillCard(front:"I'd appreciate it if you could...",back:"Буду благодарен, если вы...",context:"I'd appreciate it if you could review this by Friday.",translation:"Буду благодарен, если проверите до пятницы."),
        DrillCard(front:"Please find attached...",back:"Во вложении...",context:"Please find attached the latest report.",translation:"Во вложении последний отчёт."),
        DrillCard(front:"Looking forward to your response.",back:"Жду вашего ответа.",context:nil,translation:nil),
        DrillCard(front:"Please let me know if you have any questions.",back:"Дайте знать, если есть вопросы.",context:nil,translation:nil),
        DrillCard(front:"Don't hesitate to reach out.",back:"Не стесняйтесь обращаться.",context:nil,translation:nil),
        DrillCard(front:"Best regards",back:"С уважением (формальное)",context:nil,translation:nil),
        DrillCard(front:"Kind regards",back:"С уважением (полуформальное)",context:nil,translation:nil),
        DrillCard(front:"I hope this email finds you well.",back:"Надеюсь, у вас всё хорошо.",context:nil,translation:"Стандартное начало формального письма."),
        DrillCard(front:"Further to our conversation...",back:"В продолжение нашего разговора...",context:"Further to our conversation, I'm sending the proposal.",translation:"В продолжение разговора отправляю предложение."),
        DrillCard(front:"Would it be possible to reschedule?",back:"Было бы возможно перенести?",context:"Would it be possible to reschedule to Thursday?",translation:"Можно ли перенести на четверг?"),
        DrillCard(front:"I was wondering if you could help with...",back:"Мне интересно, не могли бы вы помочь с...",context:"I was wondering if you could help with the migration.",translation:"Не могли бы вы помочь с миграцией?"),
        DrillCard(front:"I wanted to loop you in on...",back:"Хотел подключить вас к...",context:"I wanted to loop you in on the status update.",translation:"Хотел подключить вас к обновлению статуса."),
        DrillCard(front:"Just a quick heads-up...",back:"Просто быстрое предупреждение...",context:"Just a heads-up — the deploy is tonight.",translation:"Предупреждаю — деплой сегодня ночью."),
        DrillCard(front:"Thanks for getting back to me.",back:"Спасибо за ответ.",context:nil,translation:nil),
        DrillCard(front:"Apologies for the delayed response.",back:"Извините за задержку с ответом.",context:nil,translation:nil),
        DrillCard(front:"I've CC'd [Name] for visibility.",back:"Поставил [Имя] в копию для информации.",context:nil,translation:nil),
        DrillCard(front:"Let's take this offline.",back:"Давайте обсудим это отдельно.",context:nil,translation:nil),
        DrillCard(front:"I'll keep you posted.",back:"Буду держать в курсе.",context:nil,translation:nil),
        DrillCard(front:"Action items from today's meeting:",back:"Задачи по итогам сегодняшней встречи:",context:nil,translation:nil),
        DrillCard(front:"As per the attached document...",back:"Согласно приложенному документу...",context:nil,translation:nil),
        DrillCard(front:"I'd like to flag a potential issue.",back:"Хочу обратить внимание на возможную проблему.",context:nil,translation:nil),
    ]
}

// MARK: - English: Meeting Phrases

struct MeetingDrill {
    static let cheatSheet = """
    ФРАЗЫ ДЛЯ ВСТРЕЧ И СОВЕЩАНИЙ

    НАЧАЛО:
    • Let's get started. — Давайте начнём.
    • Shall we begin? — Начнём?
    • Thanks for joining. — Спасибо, что присоединились.
    • Let's go over the agenda. — Давайте пройдёмся по повестке.

    ПЕРЕХОДЫ:
    • Moving on to the next point... — Переходим к следующему пункту...
    • Let's switch gears. — Давайте сменим тему.
    • On a related note... — В связи с этим...

    МНЕНИЕ:
    • I'd like to add that... — Хочу добавить, что...
    • From my perspective... — С моей точки зрения...
    • I think we should consider... — Думаю, стоит рассмотреть...
    • I have a different take on this. — У меня другая точка зрения.

    УТОЧНЕНИЕ:
    • Could you elaborate on that? — Можете подробнее?
    • Can you walk us through...? — Расскажите нам поэтапно...?
    • Just to clarify... — Просто уточню...
    • Am I understanding correctly that...? — Правильно ли я понимаю, что...?

    ЗАВЕРШЕНИЕ:
    • Let's wrap up. — Давайте завершим.
    • To summarize... — Подводя итог...
    • Let's define action items. — Давайте определим задачи.
    • Any blockers? — Есть блокеры?
    """

    static let cards: [DrillCard] = [
        DrillCard(front:"Let's get started.",back:"Давайте начнём.",context:nil,translation:nil),
        DrillCard(front:"Shall we begin?",back:"Начнём?",context:nil,translation:nil),
        DrillCard(front:"Thanks for joining.",back:"Спасибо, что присоединились.",context:nil,translation:nil),
        DrillCard(front:"Let's go over the agenda.",back:"Давайте пройдёмся по повестке.",context:nil,translation:nil),
        DrillCard(front:"Moving on to the next point...",back:"Переходим к следующему пункту...",context:nil,translation:nil),
        DrillCard(front:"Let's switch gears.",back:"Давайте сменим тему.",context:nil,translation:nil),
        DrillCard(front:"On a related note...",back:"В связи с этим...",context:nil,translation:nil),
        DrillCard(front:"I'd like to add that...",back:"Хочу добавить, что...",context:nil,translation:nil),
        DrillCard(front:"From my perspective...",back:"С моей точки зрения...",context:nil,translation:nil),
        DrillCard(front:"I think we should consider...",back:"Думаю, стоит рассмотреть...",context:nil,translation:nil),
        DrillCard(front:"I have a different take on this.",back:"У меня другая точка зрения.",context:nil,translation:nil),
        DrillCard(front:"Could you elaborate on that?",back:"Можете подробнее?",context:nil,translation:nil),
        DrillCard(front:"Can you walk us through the process?",back:"Расскажите нам поэтапно?",context:nil,translation:nil),
        DrillCard(front:"Just to clarify...",back:"Просто уточню...",context:nil,translation:nil),
        DrillCard(front:"Am I understanding correctly that...?",back:"Правильно ли я понимаю, что...?",context:nil,translation:nil),
        DrillCard(front:"Let's wrap up.",back:"Давайте завершим.",context:nil,translation:nil),
        DrillCard(front:"To summarize...",back:"Подводя итог...",context:nil,translation:nil),
        DrillCard(front:"Let's define action items.",back:"Давайте определим задачи.",context:nil,translation:nil),
        DrillCard(front:"Any blockers?",back:"Есть блокеры?",context:nil,translation:nil),
        DrillCard(front:"Can we take this offline?",back:"Можем обсудить это отдельно?",context:nil,translation:nil),
        DrillCard(front:"I'll send a follow-up email.",back:"Отправлю письмо по итогам.",context:nil,translation:nil),
        DrillCard(front:"Does anyone have anything to add?",back:"Кто-нибудь хочет добавить?",context:nil,translation:nil),
        DrillCard(front:"Let's table this for now.",back:"Давайте отложим это пока.",context:nil,translation:nil),
        DrillCard(front:"I'll take the action item.",back:"Я возьму эту задачу.",context:nil,translation:nil),
        DrillCard(front:"Let's circle back on this next week.",back:"Вернёмся к этому на следующей неделе.",context:nil,translation:nil),
    ]
}

// MARK: - English: False Friends (Russian-English)

struct FalseFriendsDrill {
    static let cheatSheet = """
    ЛОЖНЫЕ ДРУЗЬЯ: РУССКИЙ ↔ АНГЛИЙСКИЙ

    ❌ actual ≠ актуальный → actual = фактический, реальный
       актуальный = relevant, current, up-to-date

    ❌ eventually ≠ эвентуально → eventually = в конечном счёте
       эвентуально ≠ (слово не существует)

    ❌ accurate ≠ аккуратный → accurate = точный
       аккуратный = neat, tidy, careful

    ❌ prospect ≠ перспектива → prospect = потенциальный клиент
       перспектива = perspective, outlook

    ❌ control ≠ контролировать → control = управлять
       контролировать (проверять) = check, verify, monitor

    ❌ pretend ≠ претендовать → pretend = притворяться
       претендовать = claim, apply for

    ❌ sympathetic ≠ симпатичный → sympathetic = сочувствующий
       симпатичный = attractive, good-looking

    ❌ fabric ≠ фабрика → fabric = ткань
       фабрика = factory, plant

    ❌ magazine ≠ магазин → magazine = журнал
       магазин = store, shop

    ❌ data ≠ дата → data = данные
       дата = date

    ❌ complexion ≠ комплекция → complexion = цвет лица
       комплекция = build, physique

    ❌ concrete ≠ конкретный → concrete = бетон / конкретный (оба!)
       НО: concrete evidence = конкретные доказательства ✅
    """

    static let cards: [DrillCard] = [
        DrillCard(front:"actual = ?",back:"фактический, реальный (НЕ актуальный!)",context:"The actual cost was higher than expected.",translation:"Фактическая стоимость оказалась выше."),
        DrillCard(front:"актуальный = ?",back:"relevant, current, up-to-date",context:"Is this information still relevant?",translation:"Эта информация ещё актуальна?"),
        DrillCard(front:"eventually = ?",back:"в конечном счёте (НЕ эвентуально!)",context:"Eventually, we fixed the bug.",translation:"В конце концов мы исправили баг."),
        DrillCard(front:"accurate = ?",back:"точный (НЕ аккуратный!)",context:"The data is accurate.",translation:"Данные точные."),
        DrillCard(front:"аккуратный = ?",back:"neat, tidy, careful",context:"She's very neat and organized.",translation:"Она очень аккуратная и организованная."),
        DrillCard(front:"prospect = ?",back:"потенциальный клиент (НЕ перспектива!)",context:"We have 50 new prospects this month.",translation:"У нас 50 новых потенциальных клиентов."),
        DrillCard(front:"перспектива = ?",back:"perspective, outlook",context:"From a business perspective...",translation:"С бизнес-перспективы..."),
        DrillCard(front:"control = ?",back:"управлять (НЕ только контролировать!)",context:"She controls the budget.",translation:"Она управляет бюджетом."),
        DrillCard(front:"контролировать (проверять) = ?",back:"check, verify, monitor",context:"We need to monitor the servers.",translation:"Нужно мониторить серверы."),
        DrillCard(front:"pretend = ?",back:"притворяться (НЕ претендовать!)",context:"Don't pretend you didn't know.",translation:"Не притворяйся, что не знал."),
        DrillCard(front:"претендовать = ?",back:"claim, apply for",context:"I'm applying for the position.",translation:"Я претендую на позицию."),
        DrillCard(front:"sympathetic = ?",back:"сочувствующий (НЕ симпатичный!)",context:"He was sympathetic to our concerns.",translation:"Он отнёсся с сочувствием."),
        DrillCard(front:"симпатичный = ?",back:"attractive, good-looking",context:"She's very attractive.",translation:"Она очень симпатичная."),
        DrillCard(front:"fabric = ?",back:"ткань (НЕ фабрика!)",context:"The fabric is high quality.",translation:"Ткань высокого качества."),
        DrillCard(front:"фабрика = ?",back:"factory, plant",context:"The factory produces chips.",translation:"Фабрика производит чипы."),
        DrillCard(front:"magazine = ?",back:"журнал (НЕ магазин!)",context:"I read it in a magazine.",translation:"Прочитал в журнале."),
        DrillCard(front:"магазин = ?",back:"store, shop",context:"The store is closed.",translation:"Магазин закрыт."),
        DrillCard(front:"data = ?",back:"данные (НЕ дата!)",context:"The data shows a trend.",translation:"Данные показывают тренд."),
        DrillCard(front:"дата = ?",back:"date",context:"What's the date today?",translation:"Какое сегодня число?"),
        DrillCard(front:"complexion = ?",back:"цвет лица (НЕ комплекция!)",context:"She has a fair complexion.",translation:"У неё светлый цвет лица."),
        DrillCard(front:"комплекция = ?",back:"build, physique",context:"He has a strong build.",translation:"У него крепкое телосложение."),
        DrillCard(front:"expertise ≠ экспертиза",back:"expertise = опыт, компетенция; экспертиза = examination, assessment",context:"She has deep expertise in ML.",translation:"У неё глубокая экспертиза в ML."),
        DrillCard(front:"ambitious ≠ амбициозный (негатив)",back:"ambitious = целеустремлённый (позитив в EN!)",context:"She's very ambitious.",translation:"Она очень целеустремлённая."),
        DrillCard(front:"intelligent ≠ интеллигентный",back:"intelligent = умный; интеллигентный = cultured, refined",context:"He's an intelligent engineer.",translation:"Он умный инженер."),
        DrillCard(front:"resume ≠ резюме (полностью)",back:"resume (US) = CV = резюме; НО resume также = возобновить",context:"Let's resume the meeting.",translation:"Давайте возобновим встречу."),
    ]
}

// MARK: - English: Code Review & Git

struct CodeReviewDrill {
    static let cheatSheet = """
    ФРАЗЫ ДЛЯ КОД-РЕВЬЮ И GIT

    ОДОБРЕНИЕ:
    • LGTM (Looks Good To Me) — Выглядит хорошо, одобряю
    • Approved! Ship it. — Одобрено! Выпускай.
    • Nice work! Clean code. — Хорошая работа! Чистый код.

    ЗАМЕЧАНИЯ:
    • Nit: consider renaming this variable. — Мелочь: переименуй переменную.
    • Minor: could you add a comment here? — Незначительное: добавь комментарий.
    • Major: this could cause a regression. — Серьёзное: может вызвать регрессию.
    • Blocker: this needs to be fixed before merge. — Блокер: исправь до мержа.

    ВОПРОСЫ:
    • What's the reasoning behind this approach? — Почему такой подход?
    • Have you considered using...? — Рассматривал ли вариант с...?
    • Is there a test for this case? — Есть тест для этого случая?
    • Could you add a unit test? — Можешь добавить юнит-тест?

    GIT:
    • Please rebase on main. — Сделай rebase на main.
    • Can you squash these commits? — Можешь сквошить коммиты?
    • There's a merge conflict. — Есть конфликт слияния.
    • The CI pipeline failed. — CI пайплайн упал.
    • PTAL (Please Take Another Look) — Посмотри ещё раз.
    """

    static let cards: [DrillCard] = [
        DrillCard(front:"LGTM",back:"Looks Good To Me — одобряю",context:"LGTM! Approved.",translation:"Выглядит хорошо, одобрено."),
        DrillCard(front:"Nit:",back:"мелкое замечание (необязательное)",context:"Nit: consider using a more descriptive name.",translation:"Мелочь: используй более описательное имя."),
        DrillCard(front:"This could cause a regression.",back:"Это может вызвать регрессию.",context:nil,translation:nil),
        DrillCard(front:"Blocker: fix before merge.",back:"Блокер: исправь до мержа.",context:nil,translation:nil),
        DrillCard(front:"What's the reasoning behind this?",back:"Почему такой подход?",context:nil,translation:nil),
        DrillCard(front:"Have you considered using...?",back:"Рассматривал ли вариант с...?",context:"Have you considered using a cache here?",translation:"Рассматривал вариант с кэшем?"),
        DrillCard(front:"Could you add a unit test?",back:"Можешь добавить юнит-тест?",context:nil,translation:nil),
        DrillCard(front:"Please rebase on main.",back:"Сделай rebase на main.",context:nil,translation:nil),
        DrillCard(front:"Can you squash these commits?",back:"Можешь сквошить коммиты?",context:nil,translation:nil),
        DrillCard(front:"There's a merge conflict.",back:"Есть конфликт слияния.",context:nil,translation:nil),
        DrillCard(front:"The CI pipeline failed.",back:"CI пайплайн упал.",context:nil,translation:nil),
        DrillCard(front:"PTAL",back:"Please Take Another Look — посмотри ещё раз",context:nil,translation:nil),
        DrillCard(front:"Ship it!",back:"Выпускай! (деплой)",context:"LGTM, ship it!",translation:nil),
        DrillCard(front:"Let's refactor this.",back:"Давай отрефакторим это.",context:nil,translation:nil),
        DrillCard(front:"This is a breaking change.",back:"Это ломающее изменение.",context:nil,translation:nil),
        DrillCard(front:"Can you extract this into a helper?",back:"Можешь вынести это в хелпер?",context:nil,translation:nil),
        DrillCard(front:"Is this backward compatible?",back:"Это обратно совместимо?",context:nil,translation:nil),
        DrillCard(front:"Nice catch!",back:"Хорошо заметил!",context:nil,translation:nil),
        DrillCard(front:"This is out of scope for this PR.",back:"Это выходит за рамки этого PR.",context:nil,translation:nil),
        DrillCard(front:"Let's address this in a follow-up PR.",back:"Исправим в следующем PR.",context:nil,translation:nil),
    ]
}

// MARK: - English: Daily Standup

struct StandupDrill {
    static let cheatSheet = """
    ФРАЗЫ ДЛЯ ЕЖЕДНЕВНОГО СТЕНДАПА

    ФОРМАТ:
    1. What I did yesterday (Что сделал вчера)
    2. What I'm doing today (Что делаю сегодня)
    3. Any blockers (Есть ли блокеры)

    ВЧЕРА:
    • Yesterday I worked on... — Вчера работал над...
    • I finished/completed... — Закончил...
    • I merged the PR for... — Замержил PR для...
    • I investigated the issue with... — Разбирался с проблемой...
    • I paired with [Name] on... — Работал в паре с...

    СЕГОДНЯ:
    • Today I'm going to... — Сегодня собираюсь...
    • I'll continue working on... — Продолжу работать над...
    • I'm picking up [ticket]... — Беру тикет...
    • I'll be reviewing PRs... — Буду ревьюить PR-ы...
    • I have a meeting about... — У меня встреча по поводу...

    БЛОКЕРЫ:
    • I'm blocked by... — Заблокирован из-за...
    • I'm waiting for... — Жду...
    • I need help with... — Нужна помощь с...
    • No blockers. — Блокеров нет.
    • I need access to... — Мне нужен доступ к...

    ДОПОЛНИТЕЛЬНО:
    • Quick FYI: ... — Для информации: ...
    • Heads up: ... — Предупреждение: ...
    • I'll be out tomorrow. — Завтра меня не будет.
    • I'm on PTO next week. — На следующей неделе в отпуске.
    """

    static let cards: [DrillCard] = [
        DrillCard(front:"Yesterday I worked on...",back:"Вчера я работал над...",context:"Yesterday I worked on the authentication module.",translation:"Вчера работал над модулем аутентификации."),
        DrillCard(front:"I finished the implementation of...",back:"Закончил реализацию...",context:"I finished the implementation of the search feature.",translation:"Закончил реализацию поиска."),
        DrillCard(front:"I merged the PR for...",back:"Замержил PR для...",context:"I merged the PR for the login page.",translation:"Замержил PR для страницы логина."),
        DrillCard(front:"I investigated the issue with...",back:"Разбирался с проблемой...",context:"I investigated the issue with slow queries.",translation:"Разбирался с проблемой медленных запросов."),
        DrillCard(front:"I paired with [Name] on...",back:"Работал в паре с [Имя] над...",context:"I paired with Alex on the database migration.",translation:"Работал в паре с Алексом над миграцией БД."),
        DrillCard(front:"Today I'm going to...",back:"Сегодня собираюсь...",context:"Today I'm going to start the refactoring.",translation:"Сегодня начну рефакторинг."),
        DrillCard(front:"I'll continue working on...",back:"Продолжу работать над...",context:"I'll continue working on the API endpoints.",translation:"Продолжу работать над API эндпоинтами."),
        DrillCard(front:"I'm picking up JIRA-1234.",back:"Беру тикет JIRA-1234.",context:nil,translation:nil),
        DrillCard(front:"I'll be reviewing PRs.",back:"Буду ревьюить PR-ы.",context:nil,translation:nil),
        DrillCard(front:"I have a meeting about the roadmap.",back:"У меня встреча по поводу роадмапа.",context:nil,translation:nil),
        DrillCard(front:"I'm blocked by...",back:"Заблокирован из-за...",context:"I'm blocked by the staging environment being down.",translation:"Заблокирован — стейджинг упал."),
        DrillCard(front:"I'm waiting for code review.",back:"Жду код-ревью.",context:nil,translation:nil),
        DrillCard(front:"I need help with...",back:"Нужна помощь с...",context:"I need help with the Kubernetes config.",translation:"Нужна помощь с конфигом Kubernetes."),
        DrillCard(front:"No blockers.",back:"Блокеров нет.",context:nil,translation:nil),
        DrillCard(front:"I need access to the production database.",back:"Мне нужен доступ к продовой базе.",context:nil,translation:nil),
        DrillCard(front:"Quick FYI: the deploy is scheduled for 5 PM.",back:"Для информации: деплой запланирован на 17:00.",context:nil,translation:nil),
        DrillCard(front:"Heads up: I'll be out tomorrow.",back:"Предупреждаю: завтра меня не будет.",context:nil,translation:nil),
        DrillCard(front:"I'm on PTO next week.",back:"На следующей неделе в отпуске.",context:nil,translation:"PTO = Paid Time Off"),
        DrillCard(front:"I'll be OOO on Friday.",back:"В пятницу буду вне офиса.",context:nil,translation:"OOO = Out Of Office"),
        DrillCard(front:"Can we sync on this after standup?",back:"Можем обсудить это после стендапа?",context:nil,translation:nil),
    ]
}

// MARK: - Spanish: Numbers, Prices, Time, Dates

struct NumbersDrill {
    static let cheatSheet = """
    ЧИСЛА (NÚMEROS)

    0-15: cero, uno, dos, tres, cuatro, cinco, seis, siete, ocho, nueve, diez, once, doce, trece, catorce, quince
    16-19: dieciséis, diecisiete, dieciocho, diecinueve
    20-29: veinte, veintiuno, veintidós, veintitrés... veintinueve
    30-99: treinta, cuarenta, cincuenta, sesenta, setenta, ochenta, noventa
        treinta y uno, cuarenta y dos, cincuenta y tres...
    100: cien (перед сущ.) / ciento (в составных: ciento uno)
    200-900: doscientos/as, trescientos/as, cuatrocientos/as, quinientos/as, seiscientos/as, setecientos/as, ochocientos/as, novecientos/as
    1000: mil     1.000.000: un millón (de)

    ⚠️ doscientAS personas (ж.р.!)
    ⚠️ un millón DE euros (de перед существительным!)

    ━━━━━━━━━━━━━━━━━━━━━━━━━

    ЦЕНЫ (PRECIOS)
    В Испании цены читают так:
    • 3,50 € = tres euros con cincuenta (céntimos)
    • 15,95 € = quince euros con noventa y cinco
    • 0,99 € = noventa y nueve céntimos
    • 100 € = cien euros
    • 1.250 € = mil doscientos cincuenta euros

    ⚠️ В Испании запятая — десятичный разделитель, точка — тысячи!
       1.000 = mil (тысяча), 1,50 = uno con cincuenta

    ━━━━━━━━━━━━━━━━━━━━━━━━━

    ВРЕМЯ (LA HORA)
    • ¿Qué hora es? — Который час?
    • Es la una — Час (1:00)
    • Son las dos / tres / cuatro... — 2/3/4 часа
    • Son las dos y media — 2:30 (половина)
    • Son las tres y cuarto — 3:15 (четверть)
    • Son las cuatro menos cuarto — 3:45 (без четверти)
    • Son las cinco y diez — 5:10
    • Son las seis menos veinte — 5:40 (без двадцати)
    • Es mediodía — Полдень
    • Es medianoche — Полночь
    • de la mañana — утра (AM)
    • de la tarde — дня/вечера (PM до ~20:00)
    • de la noche — вечера/ночи (PM после ~20:00)

    ━━━━━━━━━━━━━━━━━━━━━━━━━

    ДАТЫ (LAS FECHAS)
    • ¿Qué fecha es hoy? — Какое сегодня число?
    • Hoy es el 15 de marzo — Сегодня 15 марта
    • el primero de enero — 1 января (primero, не uno!)
    • el dos de febrero — 2 февраля
    • Nací el 10 de julio de 1995 — Я родился 10 июля 1995
    • en 2025 — в 2025 году (en + год без артикля)

    МЕСЯЦЫ: enero, febrero, marzo, abril, mayo, junio, julio, agosto, septiembre, octubre, noviembre, diciembre
    ⚠️ Месяцы с маленькой буквы!
    """

    static let cards: [DrillCard] = [
        // Basic numbers
        DrillCard(front:"7",back:"siete",context:nil,translation:"семь"),
        DrillCard(front:"13",back:"trece",context:nil,translation:"тринадцать"),
        DrillCard(front:"16",back:"dieciséis",context:nil,translation:"шестнадцать"),
        DrillCard(front:"21",back:"veintiuno",context:nil,translation:"двадцать один"),
        DrillCard(front:"33",back:"treinta y tres",context:nil,translation:"тридцать три"),
        DrillCard(front:"47",back:"cuarenta y siete",context:nil,translation:"сорок семь"),
        DrillCard(front:"55",back:"cincuenta y cinco",context:nil,translation:"пятьдесят пять"),
        DrillCard(front:"68",back:"sesenta y ocho",context:nil,translation:"шестьдесят восемь"),
        DrillCard(front:"72",back:"setenta y dos",context:nil,translation:"семьдесят два"),
        DrillCard(front:"84",back:"ochenta y cuatro",context:nil,translation:"восемьдесят четыре"),
        DrillCard(front:"99",back:"noventa y nueve",context:nil,translation:"девяносто девять"),
        DrillCard(front:"100",back:"cien",context:nil,translation:"сто"),
        DrillCard(front:"101",back:"ciento uno",context:nil,translation:"сто один"),
        DrillCard(front:"200",back:"doscientos",context:nil,translation:"двести"),
        DrillCard(front:"350",back:"trescientos cincuenta",context:nil,translation:"триста пятьдесят"),
        DrillCard(front:"500",back:"quinientos",context:nil,translation:"пятьсот"),
        DrillCard(front:"777",back:"setecientos setenta y siete",context:nil,translation:"семьсот семьдесят семь"),
        DrillCard(front:"1000",back:"mil",context:nil,translation:"тысяча"),
        DrillCard(front:"2500",back:"dos mil quinientos",context:nil,translation:"две тысячи пятьсот"),
        DrillCard(front:"1.000.000",back:"un millón",context:nil,translation:"один миллион"),
        // Prices
        DrillCard(front:"0,99 €",back:"noventa y nueve céntimos",context:"Cuesta noventa y nueve céntimos.",translation:"99 центов"),
        DrillCard(front:"1,50 €",back:"un euro con cincuenta",context:"Cuesta un euro con cincuenta.",translation:"1 евро 50 центов"),
        DrillCard(front:"3,75 €",back:"tres euros con setenta y cinco",context:"Son tres euros con setenta y cinco.",translation:"3 евро 75 центов"),
        DrillCard(front:"7,20 €",back:"siete euros con veinte",context:"Son siete euros con veinte.",translation:"7 евро 20 центов"),
        DrillCard(front:"10,99 €",back:"diez euros con noventa y nueve",context:"Cuesta diez euros con noventa y nueve.",translation:"10 евро 99 центов"),
        DrillCard(front:"15,95 €",back:"quince euros con noventa y cinco",context:"Son quince euros con noventa y cinco.",translation:"15 евро 95 центов"),
        DrillCard(front:"24,50 €",back:"veinticuatro euros con cincuenta",context:"Son veinticuatro euros con cincuenta.",translation:"24 евро 50 центов"),
        DrillCard(front:"49,99 €",back:"cuarenta y nueve euros con noventa y nueve",context:nil,translation:"49 евро 99 центов"),
        DrillCard(front:"99,90 €",back:"noventa y nueve euros con noventa",context:nil,translation:"99 евро 90 центов"),
        DrillCard(front:"150 €",back:"ciento cincuenta euros",context:nil,translation:"150 евро"),
        DrillCard(front:"250,00 €",back:"doscientos cincuenta euros",context:nil,translation:"250 евро"),
        DrillCard(front:"1.200 €",back:"mil doscientos euros",context:nil,translation:"1200 евро"),
        DrillCard(front:"¿Cuánto cuesta?",back:"Сколько стоит?",context:nil,translation:nil),
        DrillCard(front:"¿Cuánto es?",back:"Сколько с меня?",context:nil,translation:nil),
        DrillCard(front:"Son 5,60 €. ¿Cómo se dice?",back:"cinco euros con sesenta",context:nil,translation:"5 евро 60 центов"),
        // Time
        DrillCard(front:"1:00",back:"Es la una",context:"Es la una de la tarde.",translation:"Час дня"),
        DrillCard(front:"2:00",back:"Son las dos",context:nil,translation:"Два часа"),
        DrillCard(front:"3:15",back:"Son las tres y cuarto",context:nil,translation:"Три пятнадцать (четверть четвёртого)"),
        DrillCard(front:"4:30",back:"Son las cuatro y media",context:nil,translation:"Четыре тридцать (половина пятого)"),
        DrillCard(front:"5:45",back:"Son las seis menos cuarto",context:nil,translation:"Без четверти шесть"),
        DrillCard(front:"6:10",back:"Son las seis y diez",context:nil,translation:"Шесть десять"),
        DrillCard(front:"7:40",back:"Son las ocho menos veinte",context:nil,translation:"Без двадцати восемь"),
        DrillCard(front:"8:55",back:"Son las nueve menos cinco",context:nil,translation:"Без пяти девять"),
        DrillCard(front:"12:00 (день)",back:"Es mediodía",context:nil,translation:"Полдень"),
        DrillCard(front:"00:00",back:"Es medianoche",context:nil,translation:"Полночь"),
        DrillCard(front:"9:00 AM",back:"Son las nueve de la mañana",context:nil,translation:"Девять утра"),
        DrillCard(front:"3:00 PM",back:"Son las tres de la tarde",context:nil,translation:"Три дня"),
        DrillCard(front:"10:00 PM",back:"Son las diez de la noche",context:nil,translation:"Десять вечера"),
        DrillCard(front:"¿Qué hora es?",back:"Который час?",context:nil,translation:nil),
        DrillCard(front:"2:30 PM — как сказать?",back:"Son las dos y media de la tarde",context:nil,translation:"Половина третьего дня"),
        // Dates
        DrillCard(front:"1 января",back:"el primero de enero",context:"Hoy es el primero de enero.",translation:"⚠️ primero, не uno!"),
        DrillCard(front:"14 февраля",back:"el catorce de febrero",context:"Es el día de San Valentín.",translation:"День святого Валентина"),
        DrillCard(front:"8 марта",back:"el ocho de marzo",context:nil,translation:"8 марта"),
        DrillCard(front:"25 декабря",back:"el veinticinco de diciembre",context:"Es Navidad.",translation:"Рождество"),
        DrillCard(front:"31 октября",back:"el treinta y uno de octubre",context:"Es Halloween.",translation:"Хэллоуин"),
        DrillCard(front:"¿Qué fecha es hoy?",back:"Какое сегодня число?",context:nil,translation:nil),
        DrillCard(front:"Hoy es el 15 de marzo.",back:"Сегодня 15 марта.",context:nil,translation:nil),
        DrillCard(front:"Nací el 10 de julio de 1995.",back:"Я родился 10 июля 1995 года.",context:nil,translation:nil),
        DrillCard(front:"en 2025",back:"в 2025 году",context:"Estamos en 2025.",translation:"⚠️ en + год без артикля"),
        DrillCard(front:"el 3 de abril",back:"третье апреля",context:nil,translation:"el + число + de + месяц"),
        // Mixed — what's the number?
        DrillCard(front:"diecisiete",back:"17",context:nil,translation:"семнадцать"),
        DrillCard(front:"cuarenta y dos",back:"42",context:nil,translation:"сорок два"),
        DrillCard(front:"setecientos",back:"700",context:nil,translation:"семьсот"),
        DrillCard(front:"mil quinientos",back:"1500",context:nil,translation:"тысяча пятьсот"),
        DrillCard(front:"tres euros con cuarenta",back:"3,40 €",context:nil,translation:"3 евро 40 центов"),
        DrillCard(front:"las cinco y media",back:"5:30",context:nil,translation:"половина шестого"),
        DrillCard(front:"las ocho menos cuarto",back:"7:45",context:nil,translation:"без четверти восемь"),
        DrillCard(front:"el veinte de septiembre",back:"20 сентября",context:nil,translation:nil),
        // Rules
        DrillCard(front:"200 женщин = ?",back:"doscientAS mujeres (ж.р.!)",context:nil,translation:"⚠️ Сотни согласуются в роде!"),
        DrillCard(front:"1.000.000 евро = ?",back:"un millón DE euros (de!)",context:nil,translation:"⚠️ millón + DE + существительное"),
        DrillCard(front:"1:00 = Es la... vs Son las...",back:"Es LA una (ед.ч.) / Son LAS dos+ (мн.ч.)",context:nil,translation:"⚠️ Только 1:00 = Es la una"),
        DrillCard(front:"1 января = el primero, не el uno",back:"el primero de enero (порядковое!)",context:nil,translation:"⚠️ Только 1-е число = primero"),
    ]
}
