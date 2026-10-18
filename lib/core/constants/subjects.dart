/// Timetable semester subjects for the first-year Business Computing
/// licence students at FSEGN (Université de Carthage).
///
/// NOTE (Directive #6): These 12 names preserve the semester schedule wording
/// as indicated on the student timetable. They are used for beta group organization
/// and should not be claimed as official catalog course titles.
class Subjects {
  static const List<String> list = [
    'Statistique et probabilité',
    'Comptabilité générale',
    'Culture de l’IA',
    'Systèmes logiques, architecture et ordinateurs',
    'Algorithmique et structures',
    'Systèmes d’exploitation',
    'Analyse',
    'Principes de gestion 1',
    'Technologie Web et programmation',
    'Study Skills 1',
    'Anglais fondamental',
    'Digital Skills',
  ];

  static bool isValid(String subject) => list.contains(subject);
}
