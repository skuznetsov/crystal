import lldb

class CrystalArraySyntheticProvider:
    def __init__(self, valobj, internal_dict):
        self.valobj = valobj
        self.buffer = None
        self.size = 0

    def update(self):
        if self.valobj.type.is_pointer:
            self.valobj = self.valobj.Dereference()
        self.size = int(self.valobj.child[0].value)
        self.type = self.valobj.type
        self.buffer = self.valobj.child[3]

    def num_children(self):
        size = 0 if self.size is None else self.size
        return size

    def get_child_index(self, name):
        try:
            return int(name.lstrip('[').rstrip(']'))
        except:
            return -1

    def get_child_at_index(self,index):
        if index >= self.size:
            return None
        try:
            elementType = self.buffer.type.GetPointeeType()
            offset = elementType.size * index
            return self.buffer.CreateChildAtOffset('[' + str(index) + ']', offset, elementType)
        except Exception as e:
            print('Got exception %s' % (str(e)))
            return None

def findType(name, module):
    cachedTypes = module.GetTypes()
    for idx in range(cachedTypes.GetSize()):
        type = cachedTypes.GetTypeAtIndex(idx)
        if type.name == name:
            return type
    return None


def CrystalString_SummaryProvider(value, dict):
    error = lldb.SBError()
    if value.TypeIsPointerType():
        value = value.Dereference()
    process = value.GetTarget().GetProcess()
    byteSize = int(value.child[0].value)
    len = int(value.child[1].value)
    len = byteSize or len
    strAddr = value.child[2].load_addr
    val = process.ReadCStringFromMemory(strAddr, len + 1, error)
    return '"%s"' % val


# Hash formatter - shows key => value pairs
class CrystalHashSyntheticProvider:
    def __init__(self, valobj, internal_dict):
        self.valobj = valobj
        self.entries = None
        self.size = 0
        self.first = 0

    def update(self):
        if self.valobj.GetType().IsPointerType():
            self.valobj = self.valobj.Dereference()

        # Get raw hash structure (bypass synthetic provider recursion)
        valobj_raw = self.valobj.GetNonSyntheticValue()

        # Hash struct: [0] first, [1] entries*, [2] indices, [3] size, [4] deleted_count
        self.first = int(valobj_raw.GetChildAtIndex(0).GetValueAsUnsigned())
        self.entries = valobj_raw.GetChildAtIndex(1)
        self.size = int(valobj_raw.GetChildAtIndex(3).GetValueAsUnsigned())

    def num_children(self):
        return self.size

    def get_child_index(self, name):
        try:
            return int(name.lstrip('[').rstrip(']'))
        except:
            return -1

    def get_child_at_index(self, index):
        if index >= self.size:
            return None
        try:
            # Get Entry(K, V) type from entries pointer
            entry_type = self.entries.GetType().GetPointeeType()
            entry_size = entry_type.GetByteSize()

            # Calculate offset: start from first non-deleted entry
            actual_index = self.first + index
            offset = entry_size * actual_index
            entry = self.entries.CreateChildAtOffset('[' + str(index) + ']', offset, entry_type)

            # Entry struct: [0] hash: UInt32, [1] key: K, [2] value: V
            # Check if entry is deleted (hash == 0)
            hash_code = int(entry.GetChildAtIndex(0).GetValueAsUnsigned())
            if hash_code == 0:
                # Skip deleted entries
                return None

            key = entry.GetChildAtIndex(1)
            value = entry.GetChildAtIndex(2)

            # Create a synthetic "key => value" child
            # For now, just return the entry itself for debugging
            return entry
        except Exception as e:
            print('Hash formatter error: %s' % str(e))
            return None

    def has_children(self):
        return self.size > 0


# Set formatter - shows Set{elem1, elem2, ...}
def CrystalSet_SummaryProvider(value, dict):
    try:
        if value.TypeIsPointerType():
            value = value.Dereference()

        # Set struct: [0] hash: Hash(T, Nil)*
        hash_ptr = value.GetChildAtIndex(0)
        if hash_ptr.TypeIsPointerType():
            hash_obj = hash_ptr.Dereference()
        else:
            hash_obj = hash_ptr

        # Get raw hash structure (bypass synthetic provider)
        hash_raw = hash_obj.GetNonSyntheticValue()

        # Hash struct: [0] first, [1] entries*, [2] indices, [3] size, [4] deleted_count
        size = int(hash_raw.GetChildAtIndex(3).GetValueAsUnsigned())

        if size == 0:
            return 'Set{}'

        # Get entries pointer and metadata
        first = int(hash_raw.GetChildAtIndex(0).GetValueAsUnsigned())
        entries = hash_raw.GetChildAtIndex(1)

        elements = []
        entry_type = entries.GetType().GetPointeeType()
        entry_size = entry_type.GetByteSize()

        for i in range(min(size, 10)):  # Show max 10 elements
            offset = entry_size * (first + i)
            entry = entries.CreateChildAtOffset('', offset, entry_type)

            # Entry: [0] hash, [1] key, [2] value (Nil)
            hash_code = int(entry.GetChildAtIndex(0).GetValueAsUnsigned())
            if hash_code != 0:  # Not deleted
                key = entry.GetChildAtIndex(1)
                elements.append(key.GetValue())

        if size > 10:
            return 'Set{' + ', '.join(str(e) for e in elements) + ', ... (%d total)}' % size
        else:
            return 'Set{' + ', '.join(str(e) for e in elements) + '}'
    except Exception as e:
        return 'Set{...} (error: %s)' % str(e)


# Range formatter - shows 1..10 or 1...10
def CrystalRange_SummaryProvider(value, dict):
    try:
        if value.TypeIsPointerType():
            value = value.Dereference()

        # Range struct: [0] begin, [1] end, [2] exclusive
        begin_val = value.GetChildAtIndex(0).GetValue()
        end_val = value.GetChildAtIndex(1).GetValue()
        # LLDB bool field: use GetValueAsUnsigned() for reliable bool reading
        exclusive = value.GetChildAtIndex(2).GetValueAsUnsigned() != 0

        if exclusive:
            return '%s...%s' % (begin_val, end_val)
        else:
            return '%s..%s' % (begin_val, end_val)
    except Exception as e:
        return 'Range(...) (error: %s)' % str(e)


# Tuple formatter - shows elements
class CrystalTupleSyntheticProvider:
    def __init__(self, valobj, internal_dict):
        self.valobj = valobj
        self.count = 0

    def update(self):
        if self.valobj.type.is_pointer:
            self.valobj = self.valobj.Dereference()

        # Tuple has elements as direct children: [0], [1], [2], ...
        self.count = self.valobj.type.num_fields

    def num_children(self):
        return self.count

    def get_child_index(self, name):
        try:
            return int(name.lstrip('[').rstrip(']'))
        except:
            return -1

    def get_child_at_index(self, index):
        if index >= self.count:
            return None
        return self.valobj.child[index]

    def has_children(self):
        return self.count > 0


# NamedTuple formatter - shows name: value pairs
class CrystalNamedTupleSyntheticProvider:
    def __init__(self, valobj, internal_dict):
        self.valobj = valobj
        self.count = 0

    def update(self):
        if self.valobj.type.is_pointer:
            self.valobj = self.valobj.Dereference()

        # NamedTuple has named fields as direct children
        self.count = self.valobj.type.num_fields

    def num_children(self):
        return self.count

    def get_child_index(self, name):
        # NamedTuple uses field names, not indices
        return -1

    def get_child_at_index(self, index):
        if index >= self.count:
            return None
        return self.valobj.child[index]

    def has_children(self):
        return self.count > 0


# Custom LLDB commands for Crystal
class CrystalSizeCommand:
    """Get the size of a Crystal collection (Array, Hash, Set, String)"""

    def __init__(self, debugger, unused):
        self.help_string = "crystal size <variable> - Get size of Array, Hash, Set, or String"

    def __call__(self, debugger, command, exe_ctx, result):
        args = command.strip()
        if not args:
            result.SetError("Usage: crystal size <variable>")
            return

        frame = exe_ctx.GetFrame()
        if not frame:
            result.SetError("No frame available")
            return

        var = frame.FindVariable(args)
        if not var.IsValid():
            result.SetError(f"Variable '{args}' not found")
            return

        type_name = var.GetTypeName()

        try:
            # Handle pointers
            if var.TypeIsPointerType():
                var = var.Dereference()
                type_name = var.GetTypeName()

            # Get raw structure
            var_raw = var.GetNonSyntheticValue()

            if 'Array' in type_name:
                size = var_raw.GetChildMemberWithName('size').GetValueAsUnsigned()
                result.AppendMessage(f"{args}.size = {size}")
            elif 'Hash' in type_name:
                size = var_raw.GetChildMemberWithName('size').GetValueAsUnsigned()
                result.AppendMessage(f"{args}.size = {size}")
            elif 'Set' in type_name:
                # Set wraps Hash
                hash_ptr = var_raw.GetChildAtIndex(0)
                if hash_ptr.TypeIsPointerType():
                    hash_obj = hash_ptr.Dereference().GetNonSyntheticValue()
                    size = hash_obj.GetChildMemberWithName('size').GetValueAsUnsigned()
                    result.AppendMessage(f"{args}.size = {size}")
                else:
                    result.SetError("Could not access Set's internal hash")
            elif 'String' in type_name:
                length = var_raw.GetChildMemberWithName('length').GetValueAsUnsigned()
                result.AppendMessage(f"{args}.size = {length}")
            else:
                result.SetError(f"Type '{type_name}' does not support .size")
        except Exception as e:
            result.SetError(f"Error getting size: {str(e)}")


class CrystalAtCommand:
    """Get element at index from Array"""

    def __init__(self, debugger, unused):
        self.help_string = "crystal at <array> <index> - Get element at index"

    def __call__(self, debugger, command, exe_ctx, result):
        args = command.strip().split()
        if len(args) != 2:
            result.SetError("Usage: crystal at <array> <index>")
            return

        var_name, index_str = args

        try:
            index = int(index_str)
        except ValueError:
            result.SetError(f"Invalid index: {index_str}")
            return

        frame = exe_ctx.GetFrame()
        if not frame:
            result.SetError("No frame available")
            return

        var = frame.FindVariable(var_name)
        if not var.IsValid():
            result.SetError(f"Variable '{var_name}' not found")
            return

        try:
            # Handle pointers
            if var.TypeIsPointerType():
                var = var.Dereference()

            # Get raw structure
            var_raw = var.GetNonSyntheticValue()

            # Get size and buffer
            size = var_raw.GetChildMemberWithName('size').GetValueAsUnsigned()

            if index < 0 or index >= size:
                result.SetError(f"Index {index} out of bounds (size = {size})")
                return

            buffer = var_raw.GetChildMemberWithName('buffer')
            element_type = buffer.GetType().GetPointeeType()
            element_size = element_type.GetByteSize()

            offset = element_size * index
            element = buffer.CreateChildAtOffset(f'[{index}]', offset, element_type)

            result.AppendMessage(f"{var_name}[{index}] = {element.GetValue()}")
        except Exception as e:
            result.SetError(f"Error getting element: {str(e)}")


class CrystalKeysCommand:
    """Get keys from a Hash"""

    def __init__(self, debugger, unused):
        self.help_string = "crystal keys <hash> - Get all keys from Hash"

    def __call__(self, debugger, command, exe_ctx, result):
        args = command.strip()
        if not args:
            result.SetError("Usage: crystal keys <hash>")
            return

        frame = exe_ctx.GetFrame()
        if not frame:
            result.SetError("No frame available")
            return

        var = frame.FindVariable(args)
        if not var.IsValid():
            result.SetError(f"Variable '{args}' not found")
            return

        try:
            # Handle pointers
            if var.TypeIsPointerType():
                var = var.Dereference()

            var_raw = var.GetNonSyntheticValue()

            # Get hash fields
            first = var_raw.GetChildMemberWithName('first').GetValueAsUnsigned()
            entries = var_raw.GetChildMemberWithName('entries')
            size = var_raw.GetChildMemberWithName('size').GetValueAsUnsigned()

            if size == 0:
                result.AppendMessage("Hash is empty")
                return

            keys = []
            entry_type = entries.GetType().GetPointeeType()
            entry_size = entry_type.GetByteSize()

            for i in range(min(size, 20)):  # Limit to 20 keys
                offset = entry_size * (first + i)
                entry = entries.CreateChildAtOffset('', offset, entry_type)

                hash_code = entry.GetChildAtIndex(0).GetValueAsUnsigned()
                if hash_code != 0:  # Not deleted
                    key = entry.GetChildAtIndex(1)
                    # Use String formatter if key is String type
                    key_type = key.GetTypeName()
                    if 'String' in key_type:
                        key_str = CrystalString_SummaryProvider(key, {})
                        keys.append(key_str)
                    else:
                        keys.append(str(key.GetValue()))

            if size > 20:
                result.AppendMessage(f"Keys (showing first 20 of {size}): {', '.join(keys)}")
            else:
                result.AppendMessage(f"Keys: {', '.join(keys)}")
        except Exception as e:
            result.SetError(f"Error getting keys: {str(e)}")


def __lldb_init_module(debugger, dict):
    # Existing formatters
    debugger.HandleCommand(r'type synthetic add -l crystal_formatters.CrystalArraySyntheticProvider -x "^Array\(.+\)(\s*\**)?" -w Crystal')
    debugger.HandleCommand(r'type summary add -F crystal_formatters.CrystalString_SummaryProvider -x "^(String|\(String \| Nil\))(\s*\**)?$" -w Crystal')

    # New formatters
    debugger.HandleCommand(r'type synthetic add -l crystal_formatters.CrystalHashSyntheticProvider -x "^Hash\(.+,.+\)(\s*\**)?" -w Crystal')
    debugger.HandleCommand(r'type summary add -F crystal_formatters.CrystalSet_SummaryProvider -x "^Set\(.+\)(\s*\**)?" -w Crystal')
    debugger.HandleCommand(r'type summary add -F crystal_formatters.CrystalRange_SummaryProvider -x "^Range\(.+,.+\)(\s*\**)?" -w Crystal')
    debugger.HandleCommand(r'type synthetic add -l crystal_formatters.CrystalTupleSyntheticProvider -x "^Tuple\(.+\)(\s*\**)?" -w Crystal')
    debugger.HandleCommand(r'type synthetic add -l crystal_formatters.CrystalNamedTupleSyntheticProvider -x "^NamedTuple\(.+\)(\s*\**)?" -w Crystal')

    debugger.HandleCommand(r'type category enable Crystal')

    # Register custom commands
    debugger.HandleCommand('command script add -c crystal_formatters.CrystalSizeCommand crystal_size')
    debugger.HandleCommand('command script add -c crystal_formatters.CrystalAtCommand crystal_at')
    debugger.HandleCommand('command script add -c crystal_formatters.CrystalKeysCommand crystal_keys')
