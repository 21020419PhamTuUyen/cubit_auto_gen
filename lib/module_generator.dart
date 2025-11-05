import 'dart:async';
import 'package:build/build.dart';
import 'dart:io';

Builder moduleBuilder(BuilderOptions options) {
  final moduleName = options.config['module'] ?? '';
  return _ModuleBuilder(moduleName);
}

class _ModuleBuilder implements Builder {
  final String module;
  _ModuleBuilder(this.module);

  @override
  Map<String, List<String>> get buildExtensions => {
    r'$lib$': ['.ignore'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    if (module.isEmpty) {
      print('⚠️ module_generator: module name is empty — skipping build.');
      return;
    }

    final baseDir = Directory('lib');
    final paths = {
      'bloc': 'blocs/${module}_cubit.dart',
      'entity': 'domain/data/entities/${module}_entity.dart',
      'model': 'domain/data/models/${module}_model.dart',
      'datasource': 'domain/data/datasources/remote/${module}_remote_data_source.dart',
      'repository': 'domain/repositories/${module}_repository.dart',
    };

    for (final entry in paths.entries) {
      final file = File('${baseDir.path}/${entry.value}');
      if (file.existsSync()) continue;
      file.createSync(recursive: true);
      file.writeAsStringSync(_template(entry.key, module));
      print('✅ Created ${entry.value}');
    }

    // === 🔽 Tự động cập nhật api_constant.dart ===
    final apiFile = File('lib/domain/network/api_constant.dart');
    if (!apiFile.existsSync()) {
      apiFile.createSync(recursive: true);
      apiFile.writeAsStringSync('class ApiConstant {}\n');
    }

    final capName = _cap(module); // CustomerOrder
    final content = apiFile.readAsStringSync();

    final apiLines = [
      '  static const get${capName}List = "";',
      '  static const get${capName}Detail = "";',
      '  static const create${capName} = "";',
      '  static const update${capName} = "";',
      '  static const delete${capName} = "";',
    ];

    // Chỉ thêm nếu chưa có module này
    if (!content.contains('get${capName}List')) {
      final insertIndex = content.lastIndexOf('}');
      final newContent =
          content.substring(0, insertIndex) + '\n' + apiLines.join('\n') + '\n' + content.substring(insertIndex);
      apiFile.writeAsStringSync(newContent);
      print('✅ Updated api_constant.dart with ${capName} endpoints');
    } else {
      print('⚠️ ${capName} endpoints already exist in api_constant.dart');
    }
  }

  String _template(String type, String name) {
    switch (type) {
      case 'bloc':
        return '''
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos/blocs/base_bloc/base_state.dart';
import '../../domain/repositories/${name}_repository.dart';
import '../../domain/data/models/${name}_model.dart';
import 'package:pos/blocs/utils.dart';

class ${_cap(name)}Cubit extends Cubit<BaseState> {
  final ${_cap(name)}Repository repository;
  ${_cap(name)}Cubit({required this.repository}) : super(InitState());

  get${_cap(name)}List() async {
    try {
      emit(LoadingState());
      final res = await repository.get${_cap(name)}List();
      emit(LoadedState<List<${_cap(name)}Model>>(res, timeEmit: DateTime.now()));
    } catch (e) {
      emit(ErrorState(BlocUtils.getMessageError(e)));
    }
  }

  get${_cap(name)}Detail(String id) async {
    try {
      emit(LoadingState());
      final res = await repository.get${_cap(name)}Detail({"id": id});
      emit(LoadedState<${_cap(name)}Model>(res, timeEmit: DateTime.now()));
    } catch (e) {
      emit(ErrorState(BlocUtils.getMessageError(e)));
    }
  }

  create${_cap(name)}(${_cap(name)}Model data) async {
    try {
      emit(LoadingState());
      final res = await repository.create${_cap(name)}(data.toJson());
      emit(LoadedState<bool>(res, timeEmit: DateTime.now()));
    } catch (e) {
      emit(ErrorState(BlocUtils.getMessageError(e)));
    }
  }

  update${_cap(name)}(${_cap(name)}Model data) async {
    try {
      emit(LoadingState());
      final res = await repository.update${_cap(name)}(data.toJson());
      emit(LoadedState<bool>(res, timeEmit: DateTime.now()));
      
    } catch (e) {
      emit(ErrorState(BlocUtils.getMessageError(e)));
    }
  }

  delete${_cap(name)}(String id) async {
    try {
      emit(LoadingState());
      final res = await repository.delete${_cap(name)}({"id": id});
      emit(LoadedState<bool>(res, timeEmit: DateTime.now()));
    } catch (e) {
      emit(ErrorState(BlocUtils.getMessageError(e)));
    }
  }
}
''';
      case 'repository':
        return '''
import 'package:injectable/injectable.dart';
import '../../domain/data/datasources/remote/${name}_remote_data_source.dart';
import '../../domain/data/models/${name}_model.dart';

@LazySingleton()
class ${_cap(name)}Repository {
  final ${_cap(name)}RemoteDataSource remoteDataSource;
  ${_cap(name)}Repository({required this.remoteDataSource});

  Future<List<${_cap(name)}Model>> get${_cap(name)}List() {
    return remoteDataSource.get${_cap(name)}List();
  }

  Future<${_cap(name)}Model> get${_cap(name)}Detail(Map<String, dynamic> params) {
    return remoteDataSource.get${_cap(name)}Detail(params);
  }

  Future<bool> create${_cap(name)}(Map<String, dynamic> body) {
    return remoteDataSource.create${_cap(name)}(body);
  }

  Future<bool> update${_cap(name)}(Map<String, dynamic> body) {
    return remoteDataSource.update${_cap(name)}(body);
  }

  Future<bool> delete${_cap(name)}(Map<String, dynamic> params) {
    return remoteDataSource.delete${_cap(name)}(params);
  }
}
''';
      case 'model':
        return '''
import '../../data/entities/${name}_entity.dart';

class ${_cap(name)}Model extends ${_cap(name)}Entity {
  ${_cap(name)}Model.fromJson(Map<String, dynamic> json) : super.fromJson(json);

  static List<${_cap(name)}Model> fromJsonList(dynamic list) {
    if (list == null || list is! List) return [];
    try {
      return List<${_cap(name)}Model>.from(
        list.map((x) => ${_cap(name)}Model.fromJson(x as Map<String, dynamic>))
      );
    } catch (e) {
      return [];
    }
  }
}

''';
      case 'entity':
        return '''
class ${_cap(name)}Entity {
  String? id;

  ${_cap(name)}Entity.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
    };
  }
}
''';
      case 'datasource':
        return '''

import '/domain/network/api_constant.dart';
import 'package:injectable/injectable.dart';
import 'package:pos/domain/network/network_impl.dart';
import '/../domain/data/models/${name}_model.dart';

@LazySingleton()
class ${_cap(name)}RemoteDataSource {
  final Network network;

  ${_cap(name)}RemoteDataSource({required this.network});

  Future<List<${_cap(name)}Model>> get${_cap(name)}List() async {
    final response = await network.get(url: ApiConstant.get${_cap(name)}List);

    if (response.isSuccess) {
      return ${_cap(name)}Model.fromJsonList(response.data);
    } else {
      return Future.error(response.errMessage);
    }
  }

  Future<${_cap(name)}Model> get${_cap(name)}Detail(Map<String, dynamic> params) async {
    final response = await network.get(url: ApiConstant.get${_cap(name)}Detail, params: params);
    if (response.isSuccess) {
      return ${_cap(name)}Model.fromJson(response.data);
    } else {
      return Future.error(response.errMessage);
    }
  }

  Future<bool> create${_cap(name)}(Map<String, dynamic> body) async {
    final response = await network.post(url: ApiConstant.create${_cap(name)}, body: body);
    if (response.isSuccess) {
      return true;
    } else {
      return Future.error(response.errMessage);
    }
  }

  Future<bool> update${_cap(name)}(Map<String, dynamic> body) async {
    final response = await network.put(url: ApiConstant.update${_cap(name)}, body: body);
    if (response.isSuccess) {
      return true;
    } else {
      return Future.error(response.errMessage);
    }
  }

  Future<bool> delete${_cap(name)}(Map<String, dynamic> params) async {
    final response = await network.delete(url: ApiConstant.delete${_cap(name)}, params: params);
    if (response.isSuccess) {
      return true;
    } else {
      return Future.error(response.errMessage);
    }
  }

}
''';
      default:
        return '';
    }
  }

  String _cap(String input) {
    return input
        .split('_')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1);
        })
        .join('');
  }
}
