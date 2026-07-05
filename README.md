# cmdFlow

Menu-barowa aplikacja na macOS, która przepuszcza tekst ze schowka przez **Apple Foundation Model** (model on-device, Apple Intelligence) i wynik odkłada z powrotem do schowka — wszystko pod globalnym skrótem klawiszowym.

```
[globalny skrót]  →  tekst ze schowka  →  Twój prompt  →  Apple Foundation Model  →  wynik do schowka
```

Przykład: skopiuj fragment, naciśnij `⌃⌥⌘T`, wklej — masz tłumaczenie. Zero okien, zero chmury, zero kluczy API.

---

## Funkcje

- **Wiele akcji** — każda to para *globalny skrót + prompt*. Jedna tłumaczy na angielski, druga poprawia gramatykę, trzecia streszcza — jak zdefiniujesz.
- **Nagrywanie skrótu z animacją** — wciśnij kombinację; aplikacja ostrzega, gdy koliduje z popularnym skrótem systemowym i wymaga modyfikatora (⌘/⌃/⌥).
- **W 100% on-device** — model Apple Intelligence działa lokalnie. Tekst nie opuszcza komputera.
- **Menu bar** — brak ikony w Docku, dyskretna ikona `⌘` ze stanem (praca / sukces / błąd).

## Wymagania

- **macOS 26 (Tahoe) lub nowszy**
- **Apple Silicon** (M1+)
- **Włączone Apple Intelligence** — Ustawienia systemowe → Apple Intelligence & Siri

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
| `Clipboard` | Odczyt/zapis `NSPasteboard` |
| `AppState` | Persystencja akcji (UserDefaults), rejestracja skrótów, uruchamianie, stan ikony |
| `ShortcutRecorder` | Nagrywanie skrótu z animacją i detekcją kolizji |

Aplikacja to pakiet SPM (`executableTarget`) składany do `.app` skryptem — bez pliku `.xcodeproj`.

## Licencja

[MIT](LICENSE) © 2026 Bogumił Łuć
