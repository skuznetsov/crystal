require "spec"

require "../src/main"

describe CrystalGPT5 do
  it "defines a version" do
    CrystalGPT5::VERSION.should_not be_nil
  end
end
