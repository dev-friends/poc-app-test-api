# Generates syntactically valid (correct check-digit) but essentially
# random CPF numbers for specs that need a *fresh*, never-before-registered
# CPF each run. Using a fixed well-known test CPF (e.g. 111.444.777-35) is
# unreliable here because the external app under test is a shared instance
# and such commonly used numbers are frequently already taken.
module CpfGenerator
  module_function

  def generate
    digits = Array.new(9) { rand(10) }
    digits = Array.new(9) { rand(10) } while digits.uniq.size == 1

    digits << check_digit(digits)
    digits << check_digit(digits)
    digits.join
  end

  def check_digit(digits)
    weight = digits.length + 1
    sum = digits.each_with_index.sum { |digit, index| digit * (weight - index) }
    remainder = (sum * 10) % 11
    remainder == 10 ? 0 : remainder
  end
end
