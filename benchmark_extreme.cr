# EXTREME stress test - force many union merges

class Ex
  def self.c1(x)
    case x % 50
    when 0; 0
    when 1; "a"
    when 2; 'b'
    when 3; true
    when 4; false
    when 5; nil
    when 6; 1_i64
    when 7; 2_u32
    when 8; 3.0
    when 9; 4.5_f32
    when 10; [1]
    when 11; {1}
    when 12; {a: 1}
    when 13; 1..10
    when 14; :a
    when 15; Set{1}
    when 16; {"x" => 1}
    when 17; 1_i8
    when 18; 2_u8
    when 19; 3_i16
    when 20; 4_u16
    when 21; 5_i64
    when 22; 6_u64
    when 23; 7.0
    when 24; 8.0_f32
    when 25; [2]
    when 26; {2}
    when 27; {b: 2}
    when 28; 11..20
    when 29; :b
    when 30; Set{2}
    when 31; {"y" => 2}
    when 32; 10_i8
    when 33; 20_u8
    when 34; 30_i16
    when 35; 40_u16
    when 36; 50_i64
    when 37; 60_u64
    when 38; 70.0
    when 39; 80.0_f32
    when 40; [3]
    when 41; {3}
    when 42; {c: 3}
    when 43; 21..30
    when 44; :c
    when 45; Set{3}
    when 46; {"z" => 3}
    when 47; 100_i8
    when 48; 200_u8
    when 49; 300_i16
    else 999
    end
  end

  def self.c2(x)
    case x % 50
    when 0; "x"
    when 1; 'y'
    when 2; 100
    when 3; 200.5
    when 4; true
    when 5; [1, 2]
    when 6; {1, 2}
    when 7; {x: 1}
    when 8; nil
    when 9; :d
    when 10; "y"
    when 11; 'z'
    when 12; 300
    when 13; 400.5
    when 14; false
    when 15; [3, 4]
    when 16; {3, 4}
    when 17; {y: 2}
    when 18; nil
    when 19; :e
    when 20; "z"
    when 21; 'w'
    when 22; 500
    when 23; 600.5
    when 24; true
    when 25; [5, 6]
    when 26; {5, 6}
    when 27; {z: 3}
    when 28; nil
    when 29; :f
    when 30; "w"
    when 31; 'v'
    when 32; 700
    when 33; 800.5
    when 34; false
    when 35; [7, 8]
    when 36; {7, 8}
    when 37; {w: 4}
    when 38; nil
    when 39; :g
    when 40; "v"
    when 41; 'u'
    when 42; 900
    when 43; 1000.5
    when 44; true
    when 45; [9, 10]
    when 46; {9, 10}
    when 47; {v: 5}
    when 48; nil
    when 49; :h
    else ""
    end
  end

  def self.c3(x)
    case x % 50
    when 0; 1000
    when 1; 2000_i64
    when 2; 3000_u32
    when 3; 40.0
    when 4; 50.0_f32
    when 5; "s1"
    when 6; 'c'
    when 7; true
    when 8; nil
    when 9; [10]
    when 10; 1100
    when 11; 1200_i64
    when 12; 1300_u32
    when 13; 44.0
    when 14; 55.0_f32
    when 15; "s2"
    when 16; 'd'
    when 17; false
    when 18; nil
    when 19; [20]
    when 20; 2100
    when 21; 2200_i64
    when 22; 2300_u32
    when 23; 88.0
    when 24; 99.0_f32
    when 25; "s3"
    when 26; 'e'
    when 27; true
    when 28; nil
    when 29; [30]
    when 30; 3100
    when 31; 3200_i64
    when 32; 3300_u32
    when 33; 111.0
    when 34; 222.0_f32
    when 35; "s4"
    when 36; 'f'
    when 37; false
    when 38; nil
    when 39; [40]
    when 40; 4100
    when 41; 4200_i64
    when 42; 4300_u32
    when 43; 333.0
    when 44; 444.0_f32
    when 45; "s5"
    when 46; 'g'
    when 47; true
    when 48; nil
    when 49; [50]
    else 0
    end
  end

  def self.all(x); [c1(x), c2(x), c3(x)]; end
  def self.g1(x); all(x); end
  def self.g2(x); all(x); end
  def self.g3(x); all(x); end
  def self.g4(x); all(x); end
  def self.g5(x); all(x); end
  def self.g6(x); all(x); end
  def self.g7(x); all(x); end
  def self.g8(x); all(x); end
  def self.g9(x); all(x); end
  def self.g10(x); all(x); end
end

Ex.g1(1); Ex.g2(2); Ex.g3(3); Ex.g4(4); Ex.g5(5)
Ex.g6(6); Ex.g7(7); Ex.g8(8); Ex.g9(9); Ex.g10(10)
