import SwiftUI

// MARK: - Drill Card Model

struct DrillCard: Identifiable {
    let id = UUID()
    let front: String
    let back: String
    let context: String?
    var translation: String?
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
