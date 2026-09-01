import 'allergen.dart';

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    required this.relationship,
    required this.allergenIds,
    this.avatarIndex = 0,
  });

  final String id;
  final String name;
  final String relationship;
  final Set<String> allergenIds;
  final int avatarIndex;

  FamilyMember copyWith({
    String? name,
    String? relationship,
    Set<String>? allergenIds,
    int? avatarIndex,
  }) {
    return FamilyMember(
      id: id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      allergenIds: allergenIds ?? this.allergenIds,
      avatarIndex: avatarIndex ?? this.avatarIndex,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'relationship': relationship,
        'allergenIds': allergenIds.toList(),
        'avatarIndex': avatarIndex,
      };

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'] as String,
      name: json['name'] as String,
      relationship: json['relationship'] as String,
      allergenIds: Allergens.expandLegacyIds(
        (json['allergenIds'] as List<dynamic>).map((value) => value.toString()),
      ),
      avatarIndex: json['avatarIndex'] as int? ?? 0,
    );
  }
}
