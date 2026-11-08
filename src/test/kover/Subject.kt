package kover

class Subject {
  fun called() = "covered"
  fun skipped() = "missed"
}

class Generated {
  fun value() = "excluded"
}
