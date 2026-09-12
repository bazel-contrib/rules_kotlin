package mixed

private class PrivateKotlinClass {
  fun greet(): String = "hi"
}

class Mixed {
  fun greet(): String = MixedJava.greet()
}
