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
