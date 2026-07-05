# cmdFlow

Menu-barowa aplikacja na macOS, która przepuszcza tekst ze schowka przez **Apple Foundation Model** (model on-device, Apple Intelligence) i wynik odkłada z powrotem do schowka — wszystko pod globalnym skrótem klawiszowym.

```
[globalny skrót]  →  tekst ze schowka  →  Twój prompt  →  Apple Foundation Model  →  wynik do schowka
```

Przykład: skopiuj fragment, naciśnij `⌃⌥⌘T`, wklej — masz tłumaczenie. Domyślnie w 100% on-device, a **opcjonalnie** możesz przełączyć backend na **OpenRouter** (własny klucz API), gdy potrzebujesz dowolnego języka lub innego modelu.

---

## Funkcje

- **Wiele akcji** — każda to para *globalny skrót + prompt*. Jedna tłumaczy na angielski, druga poprawia gramatykę, trzecia streszcza — jak zdefiniujesz.
- **Nagrywanie skrótu z animacją** — wciśnij kombinację; aplikacja ostrzega, gdy koliduje z popularnym skrótem systemowym i wymaga modyfikatora (⌘/⌃/⌥).
- **W 100% on-device** — model Apple Intelligence działa lokalnie. Tekst nie opuszcza komputera.
- **Menu bar** — brak ikony w Docku, dyskretna ikona `⌘` ze stanem (praca / sukces / błąd).

## Backend AI

W Ustawieniach wybierasz jeden z trzech trybów:

| Tryb | Opis |
|---|---|
| **Apple (on-device)** | Model Apple Intelligence lokalnie. Prywatny, darmowy, bez klucza. Ograniczone języki (patrz niżej). |
| **Apple + fallback** | Najpierw Apple; gdy odmówi (np. polski input), automatyczny fallback do OpenRouter. |
| **OpenRouter** | Każde żądanie do [OpenRouter](https://openrouter.ai) na Twoim kluczu API. Dowolny język i model. |

Dla trybów z OpenRouter: wklej klucz API (przechowywany w **Keychain**, nie w plaintext), wpisz nazwę modelu albo użyj **wyszukiwarki** (przycisk *Szukaj* — pobiera pełną listę modeli OpenRouter z filtrem i oznaczeniem darmowych).

## Wymagania

- **macOS 26 (Tahoe) lub nowszy**, **Apple Silicon** (M1+)
- Tryb Apple: **włączone Apple Intelligence** (Ustawienia systemowe → Apple Intelligence & Siri)
- Tryb OpenRouter: **klucz API** z [openrouter.ai/keys](https://openrouter.ai/keys) (działa też, gdy urządzenie nie ma Apple Intelligence)

## Obsługiwane języki (ważne)

Model on-device Apple wspiera ograniczony zestaw języków. Przetestowane:

| Scenariusz | Status |
|---|---|
| Wejście EN/DE/FR/ES/IT/PT/JA/KO/ZH → dowolna transformacja | ✅ działa |
| Tłumaczenie **na** polski (np. angielski → polski) | ✅ działa |
| **Polski tekst wejściowy** | ⚠️ często odrzucany przez guardrail Apple (`unsupported language`) |

> Polski jako język **wejściowy** nie jest jeszcze oficjalnie wspierany przez Apple Intelligence — model potrafi go odrzucić niedeterministycznie. cmdFlow pokazuje wtedy jasny komunikat i ponawia raz. Gdy Apple rozszerzy wsparcie języków w kolejnych wersjach macOS, zadziała bez zmian w aplikacji.

## Instalacja

Aplikacja jest **niepodpisana** (projekt open-source bez Apple Developer Account), więc Gatekeeper wymaga jednorazowego potwierdzenia:

1. Pobierz `cmdFlow-x.y.z.dmg` z [Releases](../../releases), otwórz i przeciągnij **cmdFlow** do folderu **Aplikacje**.
2. Pierwsze uruchomienie: **kliknij prawym przyciskiem na cmdFlow → Otwórz** → *Otwórz*.
3. Jeśli macOS twierdzi, że aplikacja jest „uszkodzona", zdejmij kwarantannę:
   ```bash
   xattr -dr com.apple.quarantine /Applications/cmdFlow.app
   ```

## Użycie

1. Kliknij ikonę `⌘` w pasku menu → **Ustawienia…**
2. **Dodaj akcję**, nadaj nazwę, ustaw **skrót** (kliknij pole i wciśnij kombinację) oraz **prompt**.
3. Skopiuj dowolny tekst (`⌘C`) i naciśnij swój skrót. Wynik jest w schowku (`⌘V`).
4. Przycisk **Uruchom teraz** testuje akcję na bieżącej zawartości schowka.

**Wskazówka do promptów:** pisz instrukcje po angielsku i konkretnie, np.
`You are a translation engine. Translate the user's text to English. Output only the translation.`

## Budowanie ze źródeł

```bash
git clone https://github.com/<user>/cmdFlow.git
cd cmdFlow
swift build -c release          # sama kompilacja
./Scripts/build_app.sh 0.1.0    # złożenie cmdFlow.app w dist/
./Scripts/make_release.sh 0.1.0 # + .dmg i .zip
```

Wymaga Xcode 26+ / Swift 6.2+.

## Jak to działa (architektura)

| Komponent | Rola |
|---|---|
| `HotKeyManager` | Globalne skróty przez Carbon `RegisterEventHotKey` — bez uprawnień Accessibility |
| `FoundationModelService` | Warstwa nad `FoundationModels` (`SystemLanguageModel`, `LanguageModelSession`) z retry i obsługą błędów |
| `OpenRouterService` | Chat completions + listowanie modeli OpenRouter |
| `Keychain` | Bezpieczne przechowywanie klucza API |
| `Clipboard` | Odczyt/zapis `NSPasteboard` |
| `AppState` | Persystencja akcji/ustawień, routing providerów, rejestracja skrótów, stan ikony |
| `ShortcutRecorder` | Nagrywanie skrótu z animacją i detekcją kolizji |

Aplikacja to pakiet SPM (`executableTarget`) składany do `.app` skryptem — bez pliku `.xcodeproj`.

## Licencja

[MIT](LICENSE) © 2026 Bogumił Łuć
