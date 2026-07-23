/// Single shared "who is writing this story" record — just Dad's and
/// Mom's names, per PROJECT_ARCHITECTURE.md's Parents data structure.
/// No accounts, no auth — matches Version 1's one-family scope.
class ParentsProfile {
  final String dadName;
  final String momName;

  const ParentsProfile({this.dadName = '', this.momName = ''});

  static const empty = ParentsProfile();

  Map<String, dynamic> toMap() => {
        'dadName': dadName,
        'momName': momName,
      };

  factory ParentsProfile.fromMap(Map<String, dynamic>? data) {
    if (data == null) return ParentsProfile.empty;
    return ParentsProfile(
      dadName: data['dadName'] as String? ?? '',
      momName: data['momName'] as String? ?? '',
    );
  }
}
