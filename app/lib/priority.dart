import 'package:flutter/material.dart';

/// Bezeichnung einer Priorität (0 keine, 1 niedrig, 2 mittel, 3 hoch).
String priorityName(int priority) => switch (priority) {
      1 => 'Niedrig',
      2 => 'Mittel',
      3 => 'Hoch',
      _ => 'Keine',
    };

/// Farbe einer Priorität wie in der Weboberfläche: Niedrig grün, Mittel gelb, Hoch rot; ohne Priorität keine.
Color? priorityColor(int priority) => switch (priority) {
      1 => const Color(0xFF43A047),
      2 => const Color(0xFFFDD835),
      3 => const Color(0xFFE53935),
      _ => null,
    };

/// Breite des farbigen Balkens an einer Zeile. Je höher die Priorität, desto breiter; so hängt die Stufe
/// nicht nur an der Farbe (Rot-Grün-Schwäche).
double priorityBarWidth(int priority) => switch (priority) {
      1 => 3,
      2 => 5,
      3 => 7,
      _ => 0,
    };
