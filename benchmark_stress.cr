# Stress test for type_merge - creates many different union types

class StressTest
  # Method with 100 different return types
  def self.many_types(x : Int32) : Int32 | String | Char | Bool | Float64 | Array(Int32) | Tuple(Int32, Int32) | NamedTuple(x: Int32) | Nil | Symbol | Range(Int32, Int32) | Set(Int32) | Hash(String, Int32) | Int64 | UInt32 | Int8 | UInt8 | Int16 | UInt16 | UInt64 | Float32
    case x % 20
    when 0 then 0
    when 1 then "string"
    when 2 then 'c'
    when 3 then true
    when 4 then 1.5
    when 5 then [1, 2, 3]
    when 6 then {1, 2}
    when 7 then {x: 42}
    when 8 then nil
    when 9 then :symbol
    when 10 then 1..10
    when 11 then Set{1, 2}
    when 12 then {"a" => 1}
    when 13 then 1_i64
    when 14 then 2_u32
    when 15 then 3_i8
    when 16 then 4_u8
    when 17 then 5_i16
    when 18 then 6_u16
    when 19 then 7_u64
    else 8.0_f32
    end
  end

  # Deeply nested conditionals creating complex unions
  def self.deep_nesting(a : Int32, b : Int32, c : Int32, d : Int32, e : Int32)
    if a > 0
      if b > 0
        if c > 0
          if d > 0
            if e > 0
              1
            elsif e > -5
              "a"
            else
              'b'
            end
          elsif d > -5
            true
          else
            [1]
          end
        elsif c > -5
          {1}
        else
          {a: 1}
        end
      elsif b > -5
        nil
      else
        :sym1
      end
    elsif a > -5
      1..10
    else
      Set{1}
    end
  end

  # Multiple methods with different union combinations
  def self.variant1(x)
    x > 0 ? 1 : "no"
  end

  def self.variant2(x)
    x > 0 ? 'y' : false
  end

  def self.variant3(x)
    x > 0 ? [1] : {2}
  end

  def self.variant4(x)
    x > 0 ? {a: 1} : nil
  end

  def self.variant5(x)
    x > 0 ? :ok : 0.5
  end

  def self.variant6(x)
    x > 0 ? 1..5 : Set{1}
  end

  def self.variant7(x)
    x > 0 ? {"a" => 1} : 100_i64
  end

  def self.variant8(x)
    x > 0 ? 200_u32 : 1_i8
  end

  # Merge all variants
  def self.merge_all(x : Int32)
    [
      variant1(x),
      variant2(x),
      variant3(x),
      variant4(x),
      variant5(x),
      variant6(x),
      variant7(x),
      variant8(x),
    ]
  end

  # Create arrays that force type merging
  def self.array_merge
    arr1 = [1, "a", 'b', true, nil, 1.5, :sym, [1], {2}]
    arr2 = [2, "c", 'd', false, nil, 2.5, :other, [3], {4}]
    arr3 = [3, "e", 'f', true, nil, 3.5, :third, [5], {6}]

    [arr1, arr2, arr3]
  end

  # Recursive union creation
  def self.recursive_merge(depth : Int32, value)
    if depth <= 0
      value
    else
      if depth % 3 == 0
        recursive_merge(depth - 1, "#{value}")
      elsif depth % 3 == 1
        recursive_merge(depth - 1, value.to_i)
      else
        recursive_merge(depth - 1, nil)
      end
    end
  end
end

# Force compilation of all methods
result1 = StressTest.many_types(42)
result2 = StressTest.deep_nesting(1, 2, 3, 4, 5)
result3 = StressTest.merge_all(10)
result4 = StressTest.array_merge
result5 = StressTest.recursive_merge(10, "start")

puts typeof(result1)
puts typeof(result2)
puts typeof(result3)
puts typeof(result4)
puts typeof(result5)
