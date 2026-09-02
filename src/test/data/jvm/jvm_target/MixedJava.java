package mixed;

public final class MixedJava {
  public static String greet() {
    return new PrivateKotlinClass().greet();
  }
}
