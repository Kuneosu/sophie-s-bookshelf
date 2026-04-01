import 'dart:convert';
import 'package:flutter/foundation.dart';

enum ReadingStatus {
  wantToRead('읽고 싶은'),
  reading('읽는 중'),
  finished('완독'),
  dropped('중단');

  const ReadingStatus(this.label);
  final String label;
}

@immutable
class Book {
  final int? id;
  final String title;
  final String author;
  final String publisher;
  final String isbn;
  final String thumbnailUrl;
  final String description;
  final ReadingStatus status;
  final int? rating; // 0~5
  final String memo;
  final DateTime addedAt;
  final DateTime? startedAt;   // 읽기 시작한 날
  final DateTime? finishedAt;  // 다 읽은 날

  const Book({
    this.id,
    required this.title,
    required this.author,
    required this.publisher,
    this.isbn = '',
    this.thumbnailUrl = '',
    this.description = '',
    this.status = ReadingStatus.wantToRead,
    this.rating,
    this.memo = '',
    required this.addedAt,
    this.startedAt,
    this.finishedAt,
  });

  Book copyWith({
    int? id,
    String? title,
    String? author,
    String? publisher,
    String? isbn,
    String? thumbnailUrl,
    String? description,
    ReadingStatus? status,
    int? rating,
    String? memo,
    DateTime? addedAt,
    DateTime? startedAt,
    DateTime? finishedAt,
    bool clearStartedAt = false,
    bool clearFinishedAt = false,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      publisher: publisher ?? this.publisher,
      isbn: isbn ?? this.isbn,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      description: description ?? this.description,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      memo: memo ?? this.memo,
      addedAt: addedAt ?? this.addedAt,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      finishedAt: clearFinishedAt ? null : (finishedAt ?? this.finishedAt),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'author': author,
      'publisher': publisher,
      'isbn': isbn,
      'thumbnailUrl': thumbnailUrl,
      'description': description,
      'status': status.index,
      'rating': rating,
      'memo': memo,
      'addedAt': addedAt.millisecondsSinceEpoch,
      'startedAt': startedAt?.millisecondsSinceEpoch,
      'finishedAt': finishedAt?.millisecondsSinceEpoch,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as int?,
      title: map['title'] as String,
      author: map['author'] as String,
      publisher: map['publisher'] as String,
      isbn: map['isbn'] as String? ?? '',
      thumbnailUrl: map['thumbnailUrl'] as String? ?? '',
      description: map['description'] as String? ?? '',
      status: ReadingStatus.values[map['status'] as int? ?? 0],
      rating: map['rating'] as int?,
      memo: map['memo'] as String? ?? '',
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['addedAt'] as int),
      startedAt: map['startedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int)
          : null,
      finishedAt: map['finishedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['finishedAt'] as int)
          : null,
    );
  }

  /// JSON export용
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'author': author,
      'publisher': publisher,
      'isbn': isbn,
      'thumbnailUrl': thumbnailUrl,
      'description': description,
      'status': status.name,
      'rating': rating,
      'memo': memo,
      'addedAt': addedAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
    };
  }

  factory Book.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'wantToRead';
    final status = ReadingStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => ReadingStatus.wantToRead,
    );

    return Book(
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      publisher: json['publisher'] as String? ?? '',
      isbn: json['isbn'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: status,
      rating: json['rating'] as int?,
      memo: json['memo'] as String? ?? '',
      addedAt: json['addedAt'] != null
          ? DateTime.parse(json['addedAt'] as String)
          : DateTime.now(),
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      finishedAt: json['finishedAt'] != null
          ? DateTime.parse(json['finishedAt'] as String)
          : null,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Book && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
