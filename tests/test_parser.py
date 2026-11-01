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


def test_recurrence_on_several_weekdays():
    # TODAY is a Tuesday.
    result = parse("Blumen gießen jeden Mittwoch und Samstag", TODAY)
    assert result.title == "Blumen gießen"
    assert (result.recurrence.unit, result.recurrence.weekdays) == (Granularity.WEEK, (2, 5))
    assert result.due == Period.day(date(2026, 11, 4))

    result = parse("Sport jeden Mo, Mi und Fr um 18 Uhr", TODAY)
    assert result.recurrence.weekdays == (0, 2, 4)
    assert (result.title, result.due_time) == ("Sport", "18:00")

    result = parse("Training alle 2 Wochen am Montag und Donnerstag", TODAY)
    assert (result.recurrence.interval, result.recurrence.weekdays) == (2, (0, 3))
    assert result.title == "Training"

    assert parse("Yoga montags und donnerstags", TODAY).recurrence.weekdays == (0, 3)
    assert parse("Laufen jeden Mi. + Sa.", TODAY).recurrence.weekdays == (2, 5)
    assert parse("Gym every Tue and Thu", TODAY).due == Period.day(TODAY)
    assert parse("Zeitung werktags", TODAY).recurrence.weekdays == (0, 1, 2, 3, 4)
    assert parse("Putzen jedes Wochenende", TODAY).due == Period.day(date(2026, 11, 7))

    # One weekday needs no list, the due day says it.
    assert parse("Müll montags", TODAY).recurrence.weekdays == ()
    # Short names alone, or inside words, are not weekdays.
    assert parse("Montags-Meeting vorbereiten", TODAY).recurrence is None
    assert parse("Rechnungen jeden Monat", TODAY).recurrence.unit is Granularity.MONTH


def test_priority():
    result = parse("Zahnarzt anrufen diese Woche !", TODAY)
    assert result.priority == 1 and result.title == "Zahnarzt anrufen"
    assert parse("Zahnarzt anrufen !!", TODAY).priority == 2
    assert parse("Zahnarzt anrufen !!!", TODAY).priority == 3
    assert parse("Zahnarzt anrufen !!!!!", TODAY).priority == 3
    assert parse("Hallo!", TODAY).priority == 0


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
    assert data["priority"] == 1


@pytest.mark.parametrize(
    ("text", "title", "due", "due_time"),
    [
        # Dutch
        ("Banden wisselen volgende maand", "Banden wisselen", Period.month(2026, 12), None),
        ("Melk vandaag", "Melk", Period.day(TODAY), None),
        ("Melk overmorgen", "Melk", Period.day(date(2026, 11, 5)), None),
        ("Tandarts vrijdag", "Tandarts", Period.day(date(2026, 11, 6)), None),
        ("Tandarts morgen om 9 uur", "Tandarts", Period.day(date(2026, 11, 4)), "09:00"),
        ("Tandarts om 9:30", "Tandarts", Period.day(TODAY), "09:30"),
        ("Rapport eind van de maand", "Rapport", Period.month(2026, 11), None),
        ("Over 3 dagen bellen", "bellen", Period.day(date(2026, 11, 6)), None),
        ("Tuin in maart", "Tuin", Period.month(2027, 3), None),
        ("Belasting deze week", "Belasting", Period.iso_week(2026, 45), None),
        # French
        ("Changer les pneus le mois prochain", "Changer les pneus", Period.month(2026, 12), None),
        ("Impôts semaine 47", "Impôts", Period.iso_week(2026, 47), None),
        ("Lait aujourd'hui", "Lait", Period.day(TODAY), None),
        ("Lait demain à 9h", "Lait", Period.day(date(2026, 11, 4)), "09:00"),
        ("Réunion 14h30", "Réunion", Period.day(TODAY), "14:30"),
        ("Dentiste vendredi", "Dentiste", Period.day(date(2026, 11, 6)), None),
        ("Rapport fin du mois", "Rapport", Period.month(2026, 11), None),
        ("Appeler dans 3 jours", "Appeler", Period.day(date(2026, 11, 6)), None),
        ("Jardin en mars", "Jardin", Period.month(2027, 3), None),
        ("Vacances l'année prochaine", "Vacances", Period.year(2027), None),
        # Spanish
        ("Cambiar neumáticos el próximo mes", "Cambiar neumáticos", Period.month(2026, 12), None),
        ("Impuestos semana 47", "Impuestos", Period.iso_week(2026, 47), None),
        ("Leche hoy", "Leche", Period.day(TODAY), None),
        ("Leche mañana a las 9", "Leche", Period.day(date(2026, 11, 4)), "09:00"),
        ("Leche pasado mañana", "Leche", Period.day(date(2026, 11, 5)), None),
        ("Dentista el viernes", "Dentista", Period.day(date(2026, 11, 6)), None),
        ("Informe a finales de mes", "Informe", Period.month(2026, 11), None),
        ("Llamar en 3 días", "Llamar", Period.day(date(2026, 11, 6)), None),
        ("Jardín en mayo", "Jardín", Period.month(2027, 5), None),
        ("Comprar la semana que viene", "Comprar", Period.iso_week(2026, 46), None),
    ],
)
def test_other_languages(text, title, due, due_time):
    result = parse(text, TODAY)
    assert (result.title, result.due, result.due_time) == (title, due, due_time)


@pytest.mark.parametrize(
    ("text", "unit", "weekdays"),
    [
        ("Bloemen elke woensdag en zaterdag", Granularity.WEEK, (2, 5)),
        ("Planten dagelijks", Granularity.DAY, ()),
        ("Arroser chaque mercredi et samedi", Granularity.WEEK, (2, 5)),
        ("Arroser tous les jours", Granularity.DAY, ()),
        ("Facture tous les mois", Granularity.MONTH, ()),
        ("Regar cada miércoles y sábado", Granularity.WEEK, (2, 5)),
        ("Regar todos los días", Granularity.DAY, ()),
        ("Pagar mensualmente", Granularity.MONTH, ()),
    ],
)
def test_other_languages_recurrence(text, unit, weekdays):
    result = parse(text, TODAY)
    assert (result.recurrence.unit, result.recurrence.weekdays) == (unit, weekdays)


@pytest.mark.parametrize(
    "text",
    ["Mars Riegel kaufen", "Mayo kaufen", "Le Monde lesen", "En route", "2 h joggen", "Semaine des Kinos", "Morgenroutine"],
)
def test_other_languages_no_false_positives(text):
    result = parse(text, TODAY)
    assert (result.title, result.due, result.due_time) == (text, None, None)
