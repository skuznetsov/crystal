# Автоматическая настройка отладки для Crystal в VSCode

Привет всем!

Я работал над улучшением developer experience для отладки Crystal-приложений и хочу поделиться результатами.

## Проблема

Когда я начинал работать с Crystal, настройка отладки в VSCode требовала целого квеста: создать `.vscode/launch.json`, найти LLDB formatters, прописать правильные пути, настроить команды. А в Variables panel переменные показывались как сырые указатели - нужно было вручную разбирать структуры памяти чтобы увидеть содержимое String или Array.

Я подумал - а почему бы не автоматизировать весь этот процесс?

## Что сделано

### DWARF Debug Info Improvements

Сначала пришлось улучшить базовый DWARF debug info в компиляторе Crystal - без этого даже простые вещи работали плохо.

**Macro debugging (Phase 3.7)** - раньше при отладке макросов debugger показывал только строку с вызовом макроса, а при попытке step into просто перепрыгивал весь expanded код. Теперь создаются temporary files (`/tmp/crystal-macro-debug-<PID>/`) с expanded source, и DWARF debug info указывает на них. Можно step-by-step проходить каждую строку macro expansion и смотреть переменные. Работает только в debug mode (`-d` флаг) для zero overhead в production.

Реализация в `src/compiler/crystal/codegen/debug.cr` - при генерации debug info для VirtualFile проверяю флаг debug mode и создаю temp файл с содержимым, заменяя путь в DWARF metadata.

**Block/closure debugging (Phase 3.6)** - проверил что уже работает корректно. Можно видеть параметры блока, локальные переменные, captured variables. Stepping через блоки работает как ожидается.

**Constants debugging (Phase 3.5)** - добавил генерацию DWARF debug info для глобальных констант. Раньше константы не были видны в debugger вообще - теперь можно делать `p CONSTANT_NAME` и видеть значение.

Реализация в `src/compiler/crystal/codegen/debug.cr:declare_const_debug_info` - создаю `DIGlobalVariableExpression` и прикрепляю к LLVM global через `global.add_debug_info()`. Ключевой момент - нужно переключиться в контекст `@main_mod` перед созданием debug metadata, иначе LLVM не регистрирует переменную в compilation unit.

**Class variables debugging (Phase 3.5.1)** - добавил генерацию DWARF debug info для class variables. Теперь `@@class_var` видны в debugger через `target variable -r ClassName`. Показывает правильный тип и значение: `(int) Counter::total = 30`. Instance variables (`@ivar`) уже работали как поля структуры.

Реализация в `src/compiler/crystal/codegen/class_var.cr:declare_class_var_debug_info` - следует той же схеме что и константы, извлекает location из initializer, создает `DIGlobalVariableExpression` с class_var_global_name.

**Proc types** - добавил DWARF debug types для `Proc` и `NilableProc`. Раньше они показывались как `void*` в debugger - теперь видно что это именно Proc с правильными параметрами и return type.

Реализация в `src/llvm/di_builder.cr` - добавил bindings для `LLVMDIBuilderCreateSubroutineType` и метод `create_subroutine_type` для генерации debug type для функций.

**Generic types и inline functions** - проверил что уже работают. Generic types правильно инстанцируются в debug info, inline functions генерируют корректные DWARF location info.

Все эти улучшения работают на уровне DWARF - значит помогают любому debugger (LLDB, GDB, lldb-dap в VSCode, CodeLLDB extension, etc), не только VSCode.

### Phase 1: Автогенерация конфигурации в crystal init

Теперь `crystal init` автоматически создает полную VSCode debugging конфигурацию:
- `.vscode/launch.json` с двумя debug конфигурациями (current file и main program)
- `.vscode/tasks.json` с build tasks
- `.vscode/crystal_formatters.py` с LLDB formatters и custom командами

Достаточно нажать F5 сразу после `crystal init app myapp` - и debugging работает.

Реализация в `src/compiler/crystal/tools/init.cr` через систему View/template - добавил три новых View для VSCode файлов (два ECR template и один статический Python файл).

### Phase 2: crystal tool debug:setup для существующих проектов

Добавил новую команду `crystal tool debug:setup` для настройки отладки в существующих проектах.

```bash
crystal tool debug:setup           # Setup для текущего проекта
crystal tool debug:setup --global  # Обновить ~/.lldbinit
crystal tool debug:setup --force   # Перезаписать существующие файлы
```

Команда определяет имя проекта из `shard.yml` (или использует имя директории), создает VSCode конфигурацию, копирует formatters из Crystal installation. С флагом `--global` обновляет `~/.lldbinit` для системного LLDB (работает в CLI, Xcode, других IDE).

Реализация в `src/compiler/crystal/command/debug_setup.cr` - использует `Crystal::Config.exec_path` для поиска formatters, YAML parser для чтения shard.yml, colorized output.

### Phase 3: LLDB Type Formatters

Написал форматтеры для основных Crystal типов. Вместо указателей в Variables panel теперь показывается:

- **String**: `"Hello, Crystal!"` вместо `0x00007f8b9c0001a0`
- **Array**: `[0] = 1, [1] = 2, [2] = 3` с индексами
- **Hash**: key-value пары с правильным форматированием
- **Set**: `Set{10, 20, 30, ...}`
- **Range**: `1..10` или `1...10`
- **Tuple**: индексированные элементы
- **NamedTuple**: именованные поля

Форматтеры работают автоматически - никаких дополнительных команд не нужно.

### Phase 4: Custom LLDB команды

Добавил три custom команды для Debug Console:

**crystal_size** - размер коллекций
```
(lldb) crystal_size my_array
my_array.size = 5
```

**crystal_at** - доступ к элементам массива
```
(lldb) crystal_at my_array 2
my_array[2] = 3
```

**crystal_keys** - ключи из Hash
```
(lldb) crystal_keys my_hash
Keys: "one", "two", "three"
```

Команды используют LLDB Python API напрямую - обходят C++ expression evaluation (который часто глючит с Crystal кодом). Автоматически разыменовывают указатели, проверяют границы массивов, форматируют String ключи.

Реализация в `etc/lldb/crystal_formatters.py` - три класса команд (`CrystalSizeCommand`, `CrystalAtCommand`, `CrystalKeysCommand`) с регистрацией через `__lldb_init_module`.

## Как использовать

### Новый проект
```bash
crystal init app myapp
cd myapp
code .
# F5 - и debugging работает
```

### Существующий проект
```bash
cd my_project
crystal tool debug:setup
# F5 - и debugging работает
```

### Системная установка
```bash
crystal tool debug:setup --global
# Теперь formatters работают везде (CLI LLDB, Xcode, etc)
```

## Документация

Написал полную документацию в `etc/lldb/README.md`:
- Инструкции по установке
- Примеры форматтеров для каждого типа
- Справка по custom командам
- Troubleshooting
- Детали VSCode интеграции

Добавил demo файл `test/debug_formatters_demo.cr` с примерами использования.

## Что не сделано и почему

**Поддержка других IDE кроме VSCode** - не добавлял потому что нужно исследовать специфику каждой IDE (CLion, Sublime Text, etc). Но с флагом `--global` formatters работают в любом LLDB-based debugger.

**Windows поддержка** - не тестировал (у меня macOS). Код написан универсально (используется `::Path`, `File.copy`, etc), но нужно кому-то протестировать на Windows. Linux должен работать (LLDB там тот же).

**Advanced LLDB features** - можно было бы добавить больше commands (например `crystal_find` для поиска в Hash по ключу, `crystal_filter` для фильтрации Array, etc). Пока ограничился базовыми операциями которые нужны в 90% случаев.

**Визуальные представления коллекций** - VSCode DAP поддерживает custom visualizers, но это требует отдельного расширения. Сейчас используются стандартные LLDB synthetic providers.

## Тестирование

Тестировал на macOS с:
- Новыми проектами через `crystal init`
- Существующими проектами через `crystal tool debug:setup`
- Глобальной установкой (`--global`)
- Всеми type formatters на реальном Crystal коде
- Custom командами с разными типами данных

Все работает с VSCode + lldb-dap extension.

## Где посмотреть код

Branch: https://github.com/skuznetsov/crystal/tree/feature/proc-debug-types

Основные файлы:
- `src/compiler/crystal/tools/init.cr` - автогенерация в crystal init
- `src/compiler/crystal/command/debug_setup.cr` - команда debug:setup
- `etc/lldb/crystal_formatters.py` - formatters и commands
- `etc/lldb/README.md` - документация

Ключевые commits:
1. Proc/NilableProc DWARF types
2. Macro debugging с expanded source visibility
3. Constants debugging (глобальные константы видны)
4. Class variables debugging (@@class_var видны)
5. Enhanced LLDB formatters (String, Array, Hash, Set, Range, Tuple, NamedTuple)
6. Custom LLDB commands (crystal_size, crystal_at, crystal_keys)
7. VSCode integration guide
8. Auto-generate VSCode config в crystal init
9. crystal tool debug:setup команда

## Буду рад фидбеку

Готов к тестированию! Пробуйте и пишите:
- Что работает хорошо
- Что не работает
- Что можно улучшить
- Platform-specific проблемы (у меня только macOS)

Если все ок - отправлю PR в upstream crystal-lang/crystal.

## Установка для тестирования

```bash
git clone -b feature/proc-debug-types https://github.com/skuznetsov/crystal.git
cd crystal
make
./bin/crystal init app test_debug
cd test_debug
code .
# F5!
```

--
ComputerMage
