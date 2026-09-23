import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case en, uk, ru, es, pl, de, it

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .en: return "English"
        case .uk: return "Українська"
        case .ru: return "Русский"
        case .es: return "Español"
        case .pl: return "Polski"
        case .de: return "Deutsch"
        case .it: return "Italiano"
        }
    }

    var englishName: String {
        switch self {
        case .en: return "English"
        case .uk: return "Ukrainian"
        case .ru: return "Russian"
        case .es: return "Spanish"
        case .pl: return "Polish"
        case .de: return "German"
        case .it: return "Italian"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }
    fileprivate var index: Int { Self.allCases.firstIndex(of: self)! }
}

/// UI strings. Every entry lists translations in AppLanguage order: en, uk, ru, es, pl, de, it.
enum L: CaseIterable {
    case clickOrHotkey, setTokens, micNeeded, allowAccess, micUnavailable
    case inbox, listening, connecting, finishing, speakAll, beta, connectionLost, continueAction
    case addToTickTick, recordMore, sentTitle, tasksAdded, sentPartial, done, retry
    case addDescription, titlePlaceholder, notesPlaceholder, due, duePlaceholder, noDate, allDay, clearDate
    case priority, deleteTask, unparsedDate, today, tomorrow
    case unsentTitle, unsentMessage, send, discard, cancel
    case settings, sectionGeneral, sectionConnections, sectionHotkey, sectionBackground
    case language, dictationHint
    case geminiKey, tickTickToken, keychainNote, model, test, testOkGemini, testOkTickTick
    case errInvalidToken, errNetwork, errQuota, errUnknown
    case hotkey, hotkeyHint, hotkeyChange, hotkeyPress, hotkeyReset
    case hotkeyNeedsModifier, hotkeyConflictSystem, hotkeyConflictInUse
    case launchAtLogin, showInMenuBar, showInMenuBarHint, runInBackground, runInBackgroundHint, hiddenHint
    case theme, themeSystem, themeLight, themeDark
    case silenceTimeout, silenceTimeoutHint, seconds, back, addTask, sectionRecording
    case menuOpen, menuNewRecording, menuSettings, menuQuit
    case menuAbout, menuHide, menuHideOthers, menuShowAll, menuEdit, menuUndo, menuRedo, menuCut, menuCopy, menuPaste
    case menuSelectAll, menuWindow, menuMinimize, menuZoom, menuClose, menuBringAllToFront

    var translations: [String] {
        switch self {
        case .clickOrHotkey: return ["Click or press %@", "Натисніть або %@", "Нажмите или %@", "Haz clic o pulsa %@", "Kliknij lub naciśnij %@", "Klicken oder %@ drücken", "Fai clic o premi %@"]
        case .setTokens: return ["Add API tokens in Settings", "Вкажіть API-токени в налаштуваннях", "Укажите API-токены в настройках", "Añade los tokens de API en Ajustes", "Podaj tokeny API w ustawieniach", "API-Tokens in den Einstellungen angeben", "Inserisci i token API nelle impostazioni"]
        case .micNeeded: return ["Microphone access is needed to record", "Для запису потрібен доступ до мікрофона", "Для записи нужен доступ к микрофону", "Se necesita acceso al micrófono para grabar", "Do nagrywania potrzebny jest dostęp do mikrofonu", "Für die Aufnahme ist Mikrofonzugriff nötig", "Per registrare serve l'accesso al microfono"]
        case .allowAccess: return ["Allow access", "Дозволити доступ", "Разрешить доступ", "Permitir acceso", "Zezwól na dostęp", "Zugriff erlauben", "Consenti accesso"]
        case .micUnavailable: return ["Couldn't start the microphone", "Не вдалося увімкнути мікрофон", "Не удалось включить микрофон", "No se pudo iniciar el micrófono", "Nie udało się włączyć mikrofonu", "Mikrofon konnte nicht gestartet werden", "Impossibile avviare il microfono"]
        case .inbox: return ["Inbox", "Вхідні", "Входящие", "Bandeja de entrada", "Skrzynka", "Eingang", "In arrivo"]
        case .listening: return ["Listening…", "Слухаю…", "Слушаю…", "Escuchando…", "Słucham…", "Ich höre zu…", "Ti ascolto…"]
        case .connecting: return ["Connecting…", "Підключення…", "Подключение…", "Conectando…", "Łączenie…", "Verbinde…", "Connessione…"]
        case .finishing: return ["Finishing…", "Завершую…", "Завершаю…", "Terminando…", "Kończę…", "Wird abgeschlossen…", "Sto terminando…"]
        case .speakAll: return ["Say everything you need to do", "Кажіть усе, що треба зробити", "Говорите всё, что нужно сделать", "Di todo lo que tienes que hacer", "Powiedz wszystko, co masz do zrobienia", "Sag alles, was zu tun ist", "Di' tutto quello che devi fare"]
        case .beta: return ["Beta feature. Recognition errors are possible", "Бета-функція. Можливі помилки розпізнавання", "Бета-функция. Возможны ошибки распознавания", "Función beta. Puede haber errores de reconocimiento", "Funkcja beta. Możliwe błędy rozpoznawania", "Beta-Funktion. Erkennungsfehler möglich", "Funzione beta. Possibili errori di riconoscimento"]
        case .connectionLost: return ["Connection lost", "З'єднання втрачено", "Соединение потеряно", "Conexión perdida", "Utracono połączenie", "Verbindung verloren", "Connessione persa"]
        case .continueAction: return ["Continue", "Продовжити", "Продолжить", "Continuar", "Kontynuuj", "Fortsetzen", "Continua"]
        case .addToTickTick: return ["Add to TickTick", "Додати в TickTick", "Добавить в TickTick", "Añadir a TickTick", "Dodaj do TickTick", "Zu TickTick hinzufügen", "Aggiungi a TickTick"]
        case .recordMore: return ["Record more", "Записати ще", "Записать ещё", "Grabar más", "Nagraj więcej", "Weiter aufnehmen", "Registra ancora"]
        case .sentTitle: return ["Sent to TickTick", "Надіслано в TickTick", "Отправлено в TickTick", "Enviado a TickTick", "Wysłano do TickTick", "An TickTick gesendet", "Inviato a TickTick"]
        case .tasksAdded: return ["Tasks added: %d", "Додано завдань: %d", "Добавлено задач: %d", "Tareas añadidas: %d", "Dodano zadań: %d", "Aufgaben hinzugefügt: %d", "Attività aggiunte: %d"]
        case .sentPartial: return ["Sent %d of %d", "Надіслано %d з %d", "Отправлено %d из %d", "Enviadas %d de %d", "Wysłano %d z %d", "%d von %d gesendet", "Inviate %d di %d"]
        case .done: return ["Done", "Готово", "Готово", "Listo", "Gotowe", "Fertig", "Fatto"]
        case .retry: return ["Retry", "Повторити", "Повторить", "Reintentar", "Ponów", "Wiederholen", "Riprova"]
        case .addDescription: return ["+ description", "+ опис", "+ описание", "+ descripción", "+ opis", "+ Beschreibung", "+ descrizione"]
        case .titlePlaceholder: return ["Task name", "Назва завдання", "Название задачи", "Nombre de la tarea", "Nazwa zadania", "Aufgabenname", "Nome dell'attività"]
        case .notesPlaceholder: return ["Description", "Опис", "Описание", "Descripción", "Opis", "Beschreibung", "Descrizione"]
        case .due: return ["Due", "Термін", "Срок", "Fecha", "Termin", "Fällig", "Scadenza"]
        case .duePlaceholder: return ["e.g. tomorrow 3 pm", "напр. завтра о 15:00", "напр. завтра в 15:00", "p. ej. mañana 15:00", "np. jutro 15:00", "z. B. morgen 15:00", "es. domani 15:00"]
        case .noDate: return ["No date", "Без дати", "Без даты", "Sin fecha", "Bez daty", "Kein Datum", "Nessuna data"]
        case .allDay: return ["All day", "Весь день", "Весь день", "Todo el día", "Cały dzień", "Ganztägig", "Tutto il giorno"]
        case .clearDate: return ["Clear", "Очистити", "Очистить", "Borrar", "Wyczyść", "Löschen", "Cancella"]
        case .priority: return ["Priority", "Пріоритет", "Приоритет", "Prioridad", "Priorytet", "Priorität", "Priorità"]
        case .deleteTask: return ["Delete", "Видалити", "Удалить", "Eliminar", "Usuń", "Löschen", "Elimina"]
        case .unparsedDate: return ["Couldn't understand the date", "Не вдалося розпізнати дату", "Не удалось распознать дату", "No se entendió la fecha", "Nie rozpoznano daty", "Datum nicht erkannt", "Data non riconosciuta"]
        case .today: return ["Today", "Сьогодні", "Сегодня", "Hoy", "Dziś", "Heute", "Oggi"]
        case .tomorrow: return ["Tomorrow", "Завтра", "Завтра", "Mañana", "Jutro", "Morgen", "Domani"]
        case .unsentTitle: return ["Send or discard?", "Надіслати чи видалити?", "Отправить или удалить?", "¿Enviar o descartar?", "Wysłać czy usunąć?", "Senden oder verwerfen?", "Inviare o eliminare?"]
        case .unsentMessage: return ["Some tasks haven't been sent to TickTick yet.", "Є завдання, які ще не надіслано в TickTick.", "Есть задачи, которые ещё не отправлены в TickTick.", "Hay tareas que aún no se han enviado a TickTick.", "Są zadania, które nie zostały jeszcze wysłane do TickTick.", "Einige Aufgaben wurden noch nicht an TickTick gesendet.", "Ci sono attività non ancora inviate a TickTick."]
        case .send: return ["Send", "Надіслати", "Отправить", "Enviar", "Wyślij", "Senden", "Invia"]
        case .discard: return ["Discard", "Видалити", "Удалить", "Descartar", "Usuń", "Verwerfen", "Elimina"]
        case .cancel: return ["Cancel", "Скасувати", "Отмена", "Cancelar", "Anuluj", "Abbrechen", "Annulla"]
        case .settings: return ["Settings", "Налаштування", "Настройки", "Ajustes", "Ustawienia", "Einstellungen", "Impostazioni"]
        case .sectionGeneral: return ["General", "Загальні", "Общие", "General", "Ogólne", "Allgemein", "Generali"]
        case .sectionConnections: return ["Connections", "Підключення", "Подключения", "Conexiones", "Połączenia", "Verbindungen", "Connessioni"]
        case .sectionHotkey: return ["Hotkey", "Гаряча клавіша", "Горячая клавиша", "Atajo", "Skrót", "Tastenkürzel", "Scorciatoia"]
        case .sectionBackground: return ["Menu bar & background", "Меню-бар і фоновий режим", "Верхнее меню и фоновый режим", "Barra de menús y segundo plano", "Pasek menu i praca w tle", "Menüleiste & Hintergrund", "Barra dei menu e background"]
        case .language: return ["App language", "Мова застосунку", "Язык приложения", "Idioma de la app", "Język aplikacji", "App-Sprache", "Lingua dell'app"]
        case .dictationHint: return ["You can dictate in any language, even switching mid-session.", "Диктувати можна будь-якою мовою, навіть перемикаючись посеред сесії.", "Диктовать можно на любом языке, даже переключаясь посреди сессии.", "Puedes dictar en cualquier idioma, incluso cambiando a mitad de sesión.", "Możesz dyktować w dowolnym języku, nawet zmieniając go w trakcie sesji.", "Du kannst in jeder Sprache diktieren – auch mitten in der Sitzung wechseln.", "Puoi dettare in qualsiasi lingua, anche cambiandola durante la sessione."]
        case .geminiKey: return ["Gemini Live API key", "Ключ Gemini Live API", "Токен Gemini Live API", "Clave de Gemini Live API", "Klucz Gemini Live API", "Gemini-Live-API-Schlüssel", "Chiave Gemini Live API"]
        case .tickTickToken: return ["TickTick token", "Токен TickTick", "Токен TickTick", "Token de TickTick", "Token TickTick", "TickTick-Token", "Token TickTick"]
        case .keychainNote: return ["Stored in Keychain", "Зберігається у Зв'язці ключів", "Хранится в Связке ключей", "Se guarda en el Llavero", "Przechowywany w pęku kluczy", "Im Schlüsselbund gespeichert", "Salvato nel Portachiavi"]
        case .model: return ["Gemini model", "Модель Gemini", "Модель Gemini", "Modelo de Gemini", "Model Gemini", "Gemini-Modell", "Modello Gemini"]
        case .test: return ["Test", "Тест", "Тест", "Probar", "Test", "Testen", "Prova"]
        case .testOkGemini: return ["Connected, the model responds", "Підключено, модель відповідає", "Подключено, модель отвечает", "Conectado, el modelo responde", "Połączono, model odpowiada", "Verbunden, Modell antwortet", "Connesso, il modello risponde"]
        case .testOkTickTick: return ["Connected, found %d projects", "Підключено, знайдено проєктів: %d", "Подключено, найдено проектов: %d", "Conectado, proyectos encontrados: %d", "Połączono, znaleziono projektów: %d", "Verbunden, %d Projekte gefunden", "Connesso, progetti trovati: %d"]
        case .errInvalidToken: return ["Invalid token", "Невірний токен", "Неверный токен", "Token no válido", "Nieprawidłowy token", "Ungültiges Token", "Token non valido"]
        case .errNetwork: return ["No network connection", "Немає мережі", "Нет сети", "Sin conexión", "Brak sieci", "Keine Netzwerkverbindung", "Nessuna connessione"]
        case .errQuota: return ["Quota exceeded", "Квоту вичерпано", "Исчерпана квота", "Cuota agotada", "Wyczerpano limit", "Kontingent erschöpft", "Quota esaurita"]
        case .errUnknown: return ["Error: %@", "Помилка: %@", "Ошибка: %@", "Error: %@", "Błąd: %@", "Fehler: %@", "Errore: %@"]
        case .hotkey: return ["Global hotkey", "Глобальна гаряча клавіша", "Глобальная горячая клавиша", "Atajo global", "Globalny skrót", "Globales Tastenkürzel", "Scorciatoia globale"]
        case .hotkeyHint: return ["Opens the app and starts recording from anywhere. Press again to finish.", "Відкриває застосунок і починає запис звідусіль. Повторне натискання завершує запис.", "Открывает приложение и начинает запись откуда угодно. Повторное нажатие завершает запись.", "Abre la app y empieza a grabar desde cualquier lugar. Púlsalo de nuevo para terminar.", "Otwiera aplikację i zaczyna nagrywanie z dowolnego miejsca. Naciśnij ponownie, aby zakończyć.", "Öffnet die App und startet die Aufnahme von überall. Erneut drücken zum Beenden.", "Apre l'app e avvia la registrazione ovunque. Premi di nuovo per terminare."]
        case .hotkeyChange: return ["Change", "Змінити", "Изменить", "Cambiar", "Zmień", "Ändern", "Cambia"]
        case .hotkeyPress: return ["Press a shortcut… (Esc — cancel)", "Натисніть комбінацію… (Esc — скасувати)", "Нажмите сочетание… (Esc — отмена)", "Pulsa un atajo… (Esc — cancelar)", "Naciśnij skrót… (Esc — anuluj)", "Kürzel drücken… (Esc – Abbrechen)", "Premi una scorciatoia… (Esc — annulla)"]
        case .hotkeyReset: return ["Reset", "Скинути", "Сбросить", "Restablecer", "Przywróć", "Zurücksetzen", "Ripristina"]
        case .hotkeyNeedsModifier: return ["Add ⌘, ⌥ or ⌃ to the shortcut", "Додайте до комбінації ⌘, ⌥ або ⌃", "Добавьте в сочетание ⌘, ⌥ или ⌃", "Añade ⌘, ⌥ o ⌃ al atajo", "Dodaj do skrótu ⌘, ⌥ lub ⌃", "Füge ⌘, ⌥ oder ⌃ hinzu", "Aggiungi ⌘, ⌥ o ⌃ alla scorciatoia"]
        case .hotkeyConflictSystem: return ["%@ is already used by macOS", "%@ вже використовується macOS", "%@ уже занято macOS", "macOS ya usa %@", "%@ jest już używany przez macOS", "%@ wird bereits von macOS verwendet", "%@ è già usata da macOS"]
        case .hotkeyConflictInUse: return ["%@ is taken by another app", "%@ зайнято іншим застосунком", "%@ занято другим приложением", "Otra app ya usa %@", "%@ jest zajęty przez inną aplikację", "%@ wird von einer anderen App verwendet", "%@ è usata da un'altra app"]
        case .launchAtLogin: return ["Launch at login", "Запускати під час входу в систему", "Запускать при входе в систему", "Abrir al iniciar sesión", "Uruchamiaj przy logowaniu", "Beim Anmelden starten", "Avvia all'accesso"]
        case .showInMenuBar: return ["Show in menu bar", "Показувати у верхньому меню", "Отображать в верхнем меню", "Mostrar en la barra de menús", "Pokazuj na pasku menu", "In der Menüleiste anzeigen", "Mostra nella barra dei menu"]
        case .showInMenuBarHint: return ["An icon in the top menu for quick access to recording and settings.", "Іконка у верхньому меню для швидкого доступу до запису й налаштувань.", "Иконка в верхнем меню для быстрого доступа к записи и настройкам.", "Un icono en el menú superior para acceder rápido a la grabación y los ajustes.", "Ikona w górnym menu do szybkiego dostępu do nagrywania i ustawień.", "Symbol im oberen Menü für schnellen Zugriff auf Aufnahme und Einstellungen.", "Un'icona nel menu in alto per accedere rapidamente a registrazione e impostazioni."]
        case .runInBackground: return ["Run in background", "Працювати у фоновому режимі", "Работать в фоновом режиме", "Ejecutar en segundo plano", "Działaj w tle", "Im Hintergrund ausführen", "Esegui in background"]
        case .runInBackgroundHint: return ["After closing the window the app keeps running and responds to the hotkey. The microphone stays off until you start recording.", "Після закриття вікна застосунок продовжує працювати й реагує на гарячу клавішу. Мікрофон вимкнено, доки ви не почнете запис.", "После закрытия окна приложение продолжает работать и реагирует на горячую клавишу. Микрофон выключен, пока вы не начнёте запись.", "Al cerrar la ventana, la app sigue funcionando y responde al atajo. El micrófono permanece apagado hasta que empieces a grabar.", "Po zamknięciu okna aplikacja działa dalej i reaguje na skrót. Mikrofon jest wyłączony, dopóki nie zaczniesz nagrywać.", "Nach dem Schließen des Fensters läuft die App weiter und reagiert auf das Tastenkürzel. Das Mikrofon bleibt aus, bis du eine Aufnahme startest.", "Chiudendo la finestra l'app resta attiva e risponde alla scorciatoia. Il microfono resta spento finché non avvii la registrazione."]
        case .hiddenHint: return ["Without the menu bar icon the app is reachable only via %@ or by opening it again from Applications.", "Без іконки у верхньому меню застосунок доступний лише через %@ або повторним запуском із «Програм».", "Без иконки в верхнем меню приложение доступно только по %@ или повторным запуском из «Программ».", "Sin el icono en la barra de menús, la app solo está disponible con %@ o abriéndola de nuevo desde Aplicaciones.", "Bez ikony na pasku menu aplikacja jest dostępna tylko przez %@ lub ponowne uruchomienie z Aplikacji.", "Ohne Menüleistensymbol ist die App nur über %@ oder durch erneutes Öffnen aus „Programme“ erreichbar.", "Senza l'icona nella barra dei menu l'app è raggiungibile solo con %@ o riaprendola da Applicazioni."]
        case .theme: return ["Theme", "Тема", "Тема", "Tema", "Motyw", "Design", "Tema"]
        case .themeSystem: return ["System", "Системна", "Системная", "Sistema", "Systemowy", "System", "Sistema"]
        case .themeLight: return ["Light", "Світла", "Светлая", "Claro", "Jasny", "Hell", "Chiaro"]
        case .themeDark: return ["Dark", "Темна", "Тёмная", "Oscuro", "Ciemny", "Dunkel", "Scuro"]
        case .silenceTimeout: return ["Stop listening after silence", "Зупиняти слухання після тиші", "Отключать слушание после тишины", "Dejar de escuchar tras silencio", "Przestań słuchać po ciszy", "Zuhören nach Stille beenden", "Smetti di ascoltare dopo il silenzio"]
        case .silenceTimeoutHint: return ["If you say nothing for this long, recording ends and the tasks go to review.", "Якщо ви мовчите стільки часу, запис завершується і завдання переходять до перевірки.", "Если вы молчите столько времени, запись завершается и задачи переходят к проверке.", "Si no dices nada durante este tiempo, la grabación termina y las tareas pasan a revisión.", "Jeśli milczysz tak długo, nagrywanie się kończy, a zadania trafiają do sprawdzenia.", "Wenn du so lange nichts sagst, endet die Aufnahme und die Aufgaben gehen zur Prüfung.", "Se non parli per questo tempo, la registrazione termina e le attività passano alla revisione."]
        case .seconds: return ["%d s", "%d с", "%d с", "%d s", "%d s", "%d s", "%d s"]
        case .back: return ["Back", "Назад", "Назад", "Atrás", "Wstecz", "Zurück", "Indietro"]
        case .addTask: return ["Add task", "Додати завдання", "Добавить задачу", "Añadir tarea", "Dodaj zadanie", "Aufgabe hinzufügen", "Aggiungi attività"]
        case .sectionRecording: return ["Recording", "Запис", "Запись", "Grabación", "Nagrywanie", "Aufnahme", "Registrazione"]
        case .menuOpen: return ["Open TickTick Live", "Відкрити TickTick Live", "Открыть TickTick Live", "Abrir TickTick Live", "Otwórz TickTick Live", "TickTick Live öffnen", "Apri TickTick Live"]
        case .menuNewRecording: return ["New recording", "Новий запис", "Новая запись", "Nueva grabación", "Nowe nagranie", "Neue Aufnahme", "Nuova registrazione"]
        case .menuSettings: return ["Settings…", "Налаштування…", "Настройки…", "Ajustes…", "Ustawienia…", "Einstellungen…", "Impostazioni…"]
        case .menuQuit: return ["Quit TickTick Live", "Вийти з TickTick Live", "Завершить TickTick Live", "Salir de TickTick Live", "Zakończ TickTick Live", "TickTick Live beenden", "Esci da TickTick Live"]
        case .menuAbout: return ["About TickTick Live", "Про TickTick Live", "О программе TickTick Live", "Acerca de TickTick Live", "O TickTick Live", "Über TickTick Live", "Informazioni su TickTick Live"]
        case .menuHide: return ["Hide TickTick Live", "Сховати TickTick Live", "Скрыть TickTick Live", "Ocultar TickTick Live", "Ukryj TickTick Live", "TickTick Live ausblenden", "Nascondi TickTick Live"]
        case .menuHideOthers: return ["Hide Others", "Сховати інші", "Скрыть остальные", "Ocultar otros", "Ukryj pozostałe", "Andere ausblenden", "Nascondi altre"]
        case .menuShowAll: return ["Show All", "Показати всі", "Показать все", "Mostrar todo", "Pokaż wszystkie", "Alle einblenden", "Mostra tutte"]
        case .menuEdit: return ["Edit", "Редагування", "Правка", "Edición", "Edycja", "Bearbeiten", "Modifica"]
        case .menuUndo: return ["Undo", "Скасувати", "Отменить", "Deshacer", "Cofnij", "Widerrufen", "Annulla"]
        case .menuRedo: return ["Redo", "Повторити", "Повторить", "Rehacer", "Przywróć", "Wiederholen", "Ripeti"]
        case .menuCut: return ["Cut", "Вирізати", "Вырезать", "Cortar", "Wytnij", "Ausschneiden", "Taglia"]
        case .menuCopy: return ["Copy", "Копіювати", "Копировать", "Copiar", "Kopiuj", "Kopieren", "Copia"]
        case .menuPaste: return ["Paste", "Вставити", "Вставить", "Pegar", "Wklej", "Einsetzen", "Incolla"]
        case .menuSelectAll: return ["Select All", "Вибрати все", "Выбрать все", "Seleccionar todo", "Zaznacz wszystko", "Alles auswählen", "Seleziona tutto"]
        case .menuWindow: return ["Window", "Вікно", "Окно", "Ventana", "Okno", "Fenster", "Finestra"]
        case .menuMinimize: return ["Minimize", "Згорнути", "Свернуть", "Minimizar", "Minimalizuj", "Im Dock ablegen", "Riduci a icona"]
        case .menuZoom: return ["Zoom", "Змінити масштаб", "Изменить масштаб", "Zoom", "Powiększ", "Zoomen", "Ridimensiona"]
        case .menuClose: return ["Close", "Закрити", "Закрыть", "Cerrar", "Zamknij", "Schließen", "Chiudi"]
        case .menuBringAllToFront: return ["Bring All to Front", "Усі вікна на передній план", "Все окна — на передний план", "Traer todo al frente", "Przesuń wszystko na wierzch", "Alle nach vorne bringen", "Porta tutto in primo piano"]
        }
    }

    func string(_ lang: AppLanguage) -> String { translations[lang.index] }
}
