package testing;

/** Exits with 0 when the entry of the resource jar is on the runtime classpath. */
public class ResourceDependent {
  public static void main(String[] args) {
    System.exit(ResourceDependent.class.getResource("/pkg/file.txt") == null ? 1 : 0);
  }
}
