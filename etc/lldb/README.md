# Crystal LLDB Formatters and Commands

This directory contains LLDB Python formatters and custom commands for debugging Crystal programs.

## Installation

Add the following to your `~/.lldbinit` file:

```
command script import /path/to/crystal/etc/lldb/crystal_formatters.py
```

Or load it manually in LLDB:

```
(lldb) command script import /path/to/crystal/etc/lldb/crystal_formatters.py
```

## Type Formatters

The following Crystal types have custom formatters for better visualization in LLDB:

### String
Displays the string content instead of raw pointer/structure:
```
(lldb) p my_string
(String) $0 = "Hello, Crystal!"
```

### Array
Shows array elements with proper indexing:
```
(lldb) p my_array
(Array(Int32)) $0 = {
  [0] = 1
  [1] = 2
  [2] = 3
}
```

### Hash
Displays hash entries with key-value pairs:
```
(lldb) p my_hash
(Hash(String, Int32)) $0 = {
  [0] = { hash = 12345, key = "one", value = 1 }
  [1] = { hash = 67890, key = "two", value = 2 }
}
```

### Set
Shows set as `Set{elem1, elem2, ...}`:
```
(lldb) p my_set
(Set(Int32)) $0 = Set{10, 20, 30}
```

### Range
Displays range in Crystal syntax:
```
(lldb) p my_range_incl
(Range(Int32, Int32)) $0 = 1..10

(lldb) p my_range_excl
(Range(Int32, Int32)) $1 = 1...10
```

### Tuple
Shows tuple elements:
```
(lldb) p my_tuple
(Tuple(Int32, String)) $0 = {
  [0] = 42
  [1] = "answer"
}
```

### NamedTuple
Shows named tuple fields:
```
(lldb) p my_named_tuple
(NamedTuple(x: Int32, y: Int32)) $0 = {
  x = 10
  y = 20
}
```

## Custom Commands

### crystal_size

Get the size of a Crystal collection (Array, Hash, Set, or String).

**Usage:**
```
crystal_size <variable>
```

**Examples:**
```
(lldb) crystal_size my_array
my_array.size = 5

(lldb) crystal_size my_hash
my_hash.size = 3

(lldb) crystal_size my_set
my_set.size = 5

(lldb) crystal_size my_string
my_string.size = 15
```

**Error handling:**
```
(lldb) crystal_size nonexistent
error: Variable 'nonexistent' not found
```

### crystal_at

Get element at a specific index from an Array.

**Usage:**
```
crystal_at <array> <index>
```

**Examples:**
```
(lldb) crystal_at my_array 0
my_array[0] = 1

(lldb) crystal_at my_array 2
my_array[2] = 3
```

**Error handling:**
```
(lldb) crystal_at my_array 99
error: Index 99 out of bounds (size = 5)
```

### crystal_keys

Get all keys from a Hash.

**Usage:**
```
crystal_keys <hash>
```

**Examples:**
```
(lldb) crystal_keys my_hash
Keys: "one", "two", "three"
```

For hashes with many keys, only the first 20 are shown:
```
(lldb) crystal_keys large_hash
Keys (showing first 20 of 100): "key1", "key2", ...
```

## Field Access

You can also access struct fields directly using Crystal's `@` syntax:

```
(lldb) p (*my_array).@size
(Int32) $0 = 5

(lldb) p (*my_array).@capacity
(Int32) $1 = 8

(lldb) p (*my_string).@length
(Int32) $2 = 15

(lldb) p (*my_string).@bytesize
(Int32) $3 = 15
```

## Troubleshooting

### Formatters not working

Make sure the Crystal category is enabled:
```
(lldb) type category list
```

If "Crystal" is not in the list or is disabled, enable it:
```
(lldb) type category enable Crystal
```

### Custom commands not available

Verify the formatters are loaded:
```
(lldb) command script list
```

Reload if necessary:
```
(lldb) command script import --allow-reload /path/to/crystal/etc/lldb/crystal_formatters.py
```

## Implementation Notes

- All formatters use the LLDB Python API to access Crystal's internal data structures
- String keys in hashes are automatically formatted using the String formatter
- Synthetic providers give structured views of collections
- Custom commands bypass C++ expression evaluation for reliability
- All commands handle pointer types automatically (no need to dereference manually)
