import 'package:siimple/src/query_builder.dart';
import 'package:uuid/uuid.dart';

import './database.dart';
import './document.dart';

class Collection {
  final String name;
  final List<Document> _documents = [];
  final Siimple database;

  Collection(this.name, this.database);

  Document create(Map<String, dynamic> data) {
    final id = Uuid().v7();
    final document = Document(id, data);
    _documents.add(document);
    database.save();
    return document;
  }

  void update(String id, Map<String, dynamic> newData) {
    var document = _documents.firstWhere((doc) => doc.id == id);
    document.data = newData;
    database.save();
  }

  void delete(String id) {
    _documents.removeWhere((doc) => doc.id == id);
    database.save();
  }

  Map<String, dynamic> toJson() {
    return {
      'documents': _documents.map((doc) => doc.toJson()).toList(),
    };
  }

  static Collection fromJson(
      String name, Map<String, dynamic> json, Siimple database) {
    final collection = Collection(name, database);
    final list = json['documents'] as List;
    final documents =
        list.map((docJson) => Document.fromJson(docJson)).toList();
    collection._documents.addAll(documents);
    return collection;
  }

  // Create a QueryBuilder to build queries fluently
  QueryBuilder query() {
    return QueryBuilder(this);
  }

  // Method to execute the query and return results
  List<Document> executeQuery(QueryBuilder builder) {
    List<Document> results = List.from(_documents);

    // Apply filters
    if (builder.filters.isNotEmpty) {
      results = results.where((doc) {
        for (var filter in builder.filters.entries) {
          // subqueries
          bool containsLookup = filter.key.contains("__");

          if (!containsLookup) {
            if (doc.data[filter.key] != filter.value) {
              return false;
            }
          }

          final keySplits = filter.key.split("__");
          final key = keySplits.first;
          final lookup = keySplits.last;

          // Case sensetive
          if (lookup == "contains") {
            if (!doc.data[key].toString().contains(filter.value)) {
              return false;
            }
          }

          // Case insensitive
          if (lookup == "icontains") {
            if (!doc.data[key]
                .toString()
                .toLowerCase()
                .contains(filter.value.toString().toLowerCase())) {
              return false;
            }
          }
        }
        return true;
      }).toList();
    }

    // Apply limit
    if (builder.limitCount != null) {
      results = results.take(builder.limitCount!).toList();
    }

    return results;
  }
}
