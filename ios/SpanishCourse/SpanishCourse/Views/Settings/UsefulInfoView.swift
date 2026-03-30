import SwiftUI

struct UsefulInfoView: View {
    var body: some View {
        List {
            // MARK: - Tips
            Section {
                tipRow(icon: "clock.fill", color: .blue,
                       title: "Занимайся каждый день",
                       text: "10 минут ежедневно эффективнее 2 часов раз в неделю. Регулярность — ключ к успеху.")
                tipRow(icon: "speaker.wave.2.fill", color: .green,
                       title: "Проговаривай вслух",
                       text: "Произноси каждое новое слово. Мышечная память помогает запоминать и улучшает произношение.")
                tipRow(icon: "heart.fill", color: .red,
                       title: "Не бойся ошибок",
                       text: "Ошибки — естественная часть обучения. Носители оценят твои старания, даже если грамматика неидеальна.")
                tipRow(icon: "music.note", color: .purple,
                       title: "Слушай музыку на испанском",
                       text: "Rosalia, Bad Bunny, Shakira, Enrique Iglesias. Найди тексты песен и подпевай.")
                tipRow(icon: "tv.fill", color: .orange,
                       title: "Смотри сериалы",
                       text: "La Casa de Papel, Elite, Las Chicas del Cable — с испанскими субтитрами. Начни с тех, что уже смотрел.")
                tipRow(icon: "text.quote", color: .teal,
                       title: "Учи фразы, а не слова",
                       text: "\"Me gustaría un café\" запоминается лучше, чем \"gustaría\" отдельно. Контекст — всё.")
                tipRow(icon: "arrow.counterclockwise", color: .indigo,
                       title: "Повторяй карточки",
                       text: "Интервальное повторение (SM-2) — самый эффективный метод запоминания. Не пропускай повторения.")
                tipRow(icon: "bubble.left.fill", color: .mint,
                       title: "Говори с первого дня",
                       text: "Даже \"Hola, me llamo...\" — это разговор. Не жди идеального уровня, чтобы начать говорить.")
            } header: {
                Text("Советы")
            }

            // MARK: - Study Plan
            Section {
                planRow(level: "A0", time: "2-4 недели",
                        desc: "Алфавит, числа, приветствия, ser/estar/tener, базовая лексика. Цель: представиться и задать простой вопрос.")
                planRow(level: "A1", time: "1-2 месяца",
                        desc: "Настоящее время, неправильные глаголы, прилагательные, gustar, pretérito intro. Цель: рассказать о себе и своём дне.")
                planRow(level: "A2", time: "2-3 месяца",
                        desc: "Прошедшие времена, imperativo, futuro, gerundio, subjuntivo intro. Цель: рассказать историю и выразить мнение.")
                planRow(level: "B1", time: "3-4 месяца",
                        desc: "Subjuntivo, составные времена, условные, косвенная речь, пассив. Цель: вести дискуссию и аргументировать.")
                planRow(level: "B2", time: "4-6 месяцев",
                        desc: "Subjuntivo imperfecto, сложные конструкции, идиомы, академический стиль. Цель: свободное общение на любую тему.")
            } header: {
                Text("План изучения")
            } footer: {
                Text("Время указано при занятиях 15-30 минут в день. Каждый учится в своём темпе — не торопись.")
            }

            // MARK: - YouTube
            Section {
                youtubeRow(name: "Dreaming Spanish",
                           desc: "Comprehensible input — понятные видео на все уровни. Лучший метод погружения.",
                           url: "https://www.youtube.com/@DreamingSpanish")
                youtubeRow(name: "Butterfly Spanish",
                           desc: "Ana из Мексики объясняет грамматику с нуля. Отлично для начинающих.",
                           url: "https://www.youtube.com/@ButterflySpanish")
                youtubeRow(name: "Español con Juan",
                           desc: "Juan из Испании. Грамматика, лексика, культура. Кастильский испанский (es-ES).",
                           url: "https://www.youtube.com/@EspanolconJuan")
                youtubeRow(name: "PRACTIQUEMOS",
                           desc: "Упражнения и объяснения от профессионального преподавателя.",
                           url: "https://www.youtube.com/@practiquemos")
                youtubeRow(name: "Maria Español",
                           desc: "Полностью на испанском. Для среднего и продвинутого уровня.",
                           url: "https://www.youtube.com/@MariaEspanol")
                youtubeRow(name: "Why Not Spanish",
                           desc: "Maria из Колумбии. Диалекты, культура, интервью с носителями.",
                           url: "https://www.youtube.com/@WhyNotSpanish")
                youtubeRow(name: "SpanishPod101",
                           desc: "Структурированные уроки от начального до продвинутого.",
                           url: "https://www.youtube.com/@SpanishPod101")
                youtubeRow(name: "Hola Spanish",
                           desc: "Уроки испанского для русскоговорящих. Объяснения на русском.",
                           url: "https://www.youtube.com/@holaspanish")
            } header: {
                Text("YouTube каналы")
            } footer: {
                Text("Нажмите на канал, чтобы открыть в YouTube.")
            }

            // MARK: - Extra tips
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Как получить максимум от приложения")
                        .font(.subheadline.bold())
                    Text("1. Проходи уроки последовательно — они выстроены по сложности\n2. После каждого урока проходи тест — это закрепляет материал\n3. Возвращайся к карточкам каждый день — SM-2 подскажет когда повторять\n4. Генерируй AI-карточки на темы, которые тебе интересны\n5. Используй озвучку — нажимай на динамик рядом со словами\n6. Создавай свои карточки — записывай слова из фильмов и песен")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Подсказки")
            }
        }
        .navigationTitle("Полезное")
    }

    // MARK: - Row Builders

    private func tipRow(icon: String, color: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func planRow(level: String, time: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(level)
                    .font(.headline.bold())
                    .foregroundStyle(levelColor(level))
                Spacer()
                Text(time)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(levelColor(level).opacity(0.15))
                    .foregroundStyle(levelColor(level))
                    .clipShape(Capsule())
            }
            Text(desc)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func youtubeRow(name: String, desc: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                Image(systemName: "play.rectangle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func levelColor(_ level: String) -> Color {
        switch level {
        case "A0": .green
        case "A1": .blue
        case "A2": .purple
        case "B1": .orange
        case "B2": .red
        default: .gray
        }
    }
}
