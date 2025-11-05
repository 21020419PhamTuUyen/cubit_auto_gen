## 🚀 1. Cài đặt

Thêm vào file `pubspec.yaml` của **dự án Flutter chính**:

```yaml
dev_dependencies:
  build_runner: any
  module_generator:
    git:
      url: https://github.com/21020419PhamTuUyen/cubit_auto_gen.git
      ref: main
```
## Lệnh thực thi:
```fish
  fvm dart run build_runner build --delete-conflicting-outputs --define "module_generator|module_builder=module=<module_name>"
```

```bash
  fvm dart run build_runner build --delete-conflicting-outputs --define module_generator|module_builder=module=<tên_module>
```
