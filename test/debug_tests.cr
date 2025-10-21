class TestClass
    @@testClassVar = 123_u64
    
    def self.updateTestClassVar (val)
      @@testClassVar = val
    end
end

alias Primitives = (Int8 | UInt8 | Int16 | UInt16 | Int32 | UInt32 | Int64 | UInt64)
alias NullablePrimitives = (Primitives | Nil)

a : Array(NullablePrimitives)? = [1i8, 2u8, 3i16, 4u16, 5i32, 6u32, 7i64, 8u64, nil]
b = StaticArray(UInt8, 256).new(0)
c = {-1_i8, 2_u8}
d = {str: "test", val: 3_u8}
e = Nil

puts "a.class=#{a.class}"
puts "c.class=#{c.class}"
puts "d.class=#{d.class}"
puts a

puts e

a && a.each do |value|
  puts "a = #{value}"
end

TestClass.updateTestClassVar(1379_u64)

a = nil

a.each do |val|
  puts "a = #{var}"
end if a

(1u8..255u8).each_with_index do |val, idx|
#  raise "Error is here" if idx >= 5
  b[idx] = val
  puts "val=#{val}, b[#{idx}] = #{b[idx]}"
end

puts "b = #{b}"
