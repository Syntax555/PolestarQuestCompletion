# Polestar Quest Completion

**0.1.1-beta** ergänzt Polestar in *World of Warcraft: Forever* um einen Quest-Tab mit Gebietsfortschritt, Statusfiltern und einer Suche nach Questname oder ID. Das Add-on nutzt Polestars Questdaten und den Queststatus deines Charakters. Polestar ist die einzige Add-on-Abhängigkeit.

## Installation

1. Installiere den vollständigen [Polestar-Release 0.4.1.1](https://github.com/fitzforge/polestar/releases/tag/v0.4.1.1) für WoW: Forever. Aktiviere `Polestar_QuestDB` im Add-on-Menü der Charakterauswahl und in Polestar unter **Optionen → Questen → Quests → Quest-Datenbank**.
2. Lade das Installations-ZIP von [GitHub Releases](https://github.com/Syntax555/PolestarQuestCompletion/releases) herunter und entpacke den Ordner `PolestarQuestCompletion` nach `World of Warcraft/_forever_/Interface/AddOns/`. Die `.toc` liegt danach direkt unter `Interface/AddOns/PolestarQuestCompletion/PolestarQuestCompletion.toc`.
3. Starte den Client vollständig neu, melde dich mit deinem Charakter an und öffne den Tab mit `/pqc` oder `/polestarquests`.

## Quest-Fortschritt

- Wähle ein Gebiet oder klicke **Aktuelle Zone**. Der Fortschritt zählt die in Polestar erfassten Gebietsquests, die zum Charakter passen, und verwendet den Abschlussstatus aus dem Spiel. Suche und Filter ändern nur die sichtbare Liste. Gegenseitig ausschließende Quests können den Wert unter 100 % halten.
- Bewege den Mauszeiger über eine Quest, um bekannte Bedingungen wie Mindeststufe, fehlende Vorquests, im Log benötigte Quests und Berufsanforderungen zu sehen. Der Status **Vermutlich verfügbar** basiert auf den erfassten Bedingungen. Versteckte Voraussetzungen und Datenlücken können die tatsächliche Verfügbarkeit beeinflussen.
- Über **Ruf & Details** kannst du den optionalen `Polestar_Codex` bei Bedarf laden. Wenn er bereits geladen ist, erscheinen die Zusatzdaten direkt. Der Tooltip zeigt den laut Codex nötigen Rufrang sowie den aktuellen Rang, sofern der Client ihn liefert. Die Anforderung kann die Quest oder ihre Belohnung betreffen. Bei Klick auf die Quest öffnet sich Polestars Lookup.

## Kompatibilität

Zielclient ist WoW: Forever mit Interface `16001`. Die Logik wurde unter Lua 5.1 mit den Datenpaketen aus Polestar 0.4.1.1 und mit den Schnittstellen aus der Vorabversion 0.4.2 geprüft. Konkrete Berufsmindestränge stehen zur Verfügung, wenn der installierte Codex sie ausliest. Ein Test im laufenden WoW-Client steht aus. [Polestar 0.4.1.1](https://github.com/fitzforge/polestar/releases/tag/v0.4.1.1) · [Polestar 0.4.2](https://github.com/fitzforge/polestar/releases/tag/v0.4.2)
