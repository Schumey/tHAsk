from datetime import date

import pytest

from core.parser import parse
from core.period import Granularity, Period

# Tuesday of ISO week 45.
TODAY = date(2026, 11, 3)


@pytest.mark.parametrize(
    ("text", "title", "due"),
    [
        ("Reifen wechseln nächsten Monat", "Reifen wechseln", Period.month(2026, 12)),
        ("Reifen wechseln naechsten Monat", "Reifen wechseln", Period.month(2026, 12)),
        ("Steuer KW 47", "Steuer", Period.iso_week(2026, 47)),
        ("Steuer kw47", "Steuer", Period.iso_week(2026, 47)),
        ("Steuer bis KW 2", "Steuer", Period.iso_week(2027, 2)),
        ("Zahnarzt anrufen diese Woche", "Zahnarzt anrufen", Period.iso_week(2026, 45)),
        ("Urlaub planen übernächste Woche", "Urlaub planen", Period.iso_week(2026, 47)),
        ("Geschenk kaufen bis Ende des Monats", "Geschenk kaufen", Period.month(2026, 11)),
        ("Geschenk kaufen bis Monatsende", "Geschenk kaufen", Period.month(2026, 11)),
        ("Bericht bis Ende nächster Woche", "Bericht", Period.iso_week(2026, 46)),
        ("Steuererklärung Q1", "Steuererklärung", Period.quarter(2027, 1)),
        ("Steuererklärung Q4 2026", "Steuererklärung", Period.quarter(2026, 4)),
        ("Garten im März", "Garten", Period.month(2027, 3)),
        ("Garten Dezember", "Garten", Period.month(2026, 12)),
        ("Garten bis Nov.", "Garten", Period.month(2026, 11)),
        ("Dach prüfen nächstes Jahr", "Dach prüfen", Period.year(2027)),
        ("Dach prüfen bis 2028", "Dach prüfen", Period.year(2028)),
        ("Milch heute", "Milch", Period.day(TODAY)),
        ("Milch morgen", "Milch", Period.day(date(2026, 11, 4))),
        ("Milch übermorgen", "Milch", Period.day(date(2026, 11, 5))),
        ("Arzt am Freitag", "Arzt", Period.day(date(2026, 11, 6))),
        ("Arzt Dienstag", "Arzt", Period.day(date(2026, 11, 10))),
        ("Rechnung 14.11.", "Rechnung", Period.day(date(2026, 11, 14))),
        ("Rechnung bis 2.1.", "Rechnung", Period.day(date(2027, 1, 2))),
        ("Rechnung 14.11.27", "Rechnung", Period.day(date(2027, 11, 14))),
        ("Rechnung 2026-12-24", "Rechnung", Period.day(date(2026, 12, 24))),
        ("Reifen in 2 Wochen", "Reifen", Period.iso_week(2026, 47)),
        ("Reifen in 3 Tagen", "Reifen", Period.day(date(2026, 11, 6))),
        ("Reifen in einem Monat", "Reifen", Period.month(2026, 12)),
        ("Call mom next week", "Call mom", Period.iso_week(2026, 46)),
        ("Call mom tomorrow", "Call mom", Period.day(date(2026, 11, 4))),
    ],
)
def test_due(text, title, due):
    result = parse(text, TODAY)
    assert (result.title, result.due) == (title, due)


@pytest.mark.parametrize(
    "text",
    [
        "Steuererklärung 2025 abgeben",
        "Mailand Reise",
        "Wochenplan schreiben",
        "Brief an Max",
        "Die Woche war lang",
    ],
)
def test_no_false_positives(text):
    result = parse(text, TODAY)
    assert result.due is None
    assert result.title == text


def test_time():
    result = parse("Zahnarzt morgen um 9:30", TODAY)
    assert (result.title, result.due, result.due_time) == ("Zahnarzt", Period.day(date(2026, 11, 4)), "09:30")
    result = parse("Anrufen 14 Uhr", TODAY)
    assert (result.title, result.due, result.due_time) == ("Anrufen", Period.day(TODAY), "14:00")


def test_time_ignored_for_periods():
    result = parse("Meeting KW 47 um 9:30", TODAY)
    assert result.due == Period.iso_week(2026, 47)
    assert result.due_time is None
    assert result.title == "Meeting um 9:30"


def test_recurrence():
    result = parse("Rechnungen ablegen jeden Monat", TODAY)
    assert result.title == "Rechnungen ablegen"
    assert result.recurrence.unit is Granularity.MONTH
    # Without an explicit due date, the current period of the recurrence is used.
    assert result.due == Period.month(2026, 11)

    result = parse("Müll rausbringen jeden Montag", TODAY)
    assert result.recurrence.unit is Granularity.WEEK
    assert result.due == Period.day(date(2026, 11, 9))

    result = parse("Pflanzen gießen alle 2 Wochen", TODAY)
    assert (result.recurrence.unit, result.recurrence.interval) == (Granularity.WEEK, 2)

    result = parse("Steuer jährlich bis Q2", TODAY)
    assert result.recurrence.unit is Granularity.YEAR
    assert result.due == Period.quarter(2027, 2)


def test_important():
    result = parse("Zahnarzt anrufen diese Woche !", TODAY)
    assert result.important and result.title == "Zahnarzt anrufen"
    assert not parse("Hallo!", TODAY).important


def test_tokens_and_disabled_kinds():
    result = parse("Rechnung vom 14.11. bezahlen", TODAY)
    assert [(token.kind, token.text) for token in result.tokens] == [("due", "14.11.")]
    result = parse("Rechnung vom 14.11. bezahlen", TODAY, disabled={"due"})
    assert result.due is None
    assert result.title == "Rechnung vom 14.11. bezahlen"


def test_serialization():
    data = parse("Steuer KW 47 !", TODAY).as_dict("de", TODAY)
    assert data["due"] == {"granularity": "week", "start": "2026-11-16"}
    assert data["due_label"] == "KW 47"
    assert data["important"] is True
