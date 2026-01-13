import 'package:hive/hive.dart';
import 'package:gradecalculator/models/records.dart';

part 'components.g.dart';

@HiveType(typeId: 1)
class Component {
  @HiveField(0)
  final String componentId;

  @HiveField(1)
  final String componentName;

  @HiveField(2)
  final double weight;

  @HiveField(3)
  final String courseId;

  @HiveField(4)
  final List<Records>? records;

  Component({
    required this.componentId,
    required this.componentName,
    required this.weight,
    required this.courseId,
    this.records,
  });

  factory Component.fromMap(Map<String, dynamic> map) => Component(
    componentId: map['componentId'] ?? '',
    componentName: map['componentName'] ?? '',
    weight:
        (map['weight'] is int)
            ? (map['weight'] as int).toDouble()
            : (map['weight'] ?? 0.0),
    courseId: map['courseId'] ?? '',
    records:
        map['records'] != null
            ? (map['records'] as List).map((x) => Records.fromMap(x)).toList()
            : null,
  );

  Map<String, dynamic> toMap() => {
    'componentId': componentId,
    'componentName': componentName,
    'weight': weight,
    'courseId': courseId,
    if (records != null) 'records': records!.map((x) => x.toMap()).toList(),
  };
}
