package app

class Greeter(private val name: String) {
    fun greet(): String {
        if (name.isEmpty()) {
            return "Hello!"
        }
        return "Hello, $name!"
    }
}
