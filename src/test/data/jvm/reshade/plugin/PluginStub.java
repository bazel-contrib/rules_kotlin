package plugin;

import com.google.common.GuavaStub;
import kotlinx.collections.immutable.ImmutableStub;
import kotlinx.serialization.SerializationStub;

/** Stands for a compiler plugin class that references both kinds of kotlinx classes. */
public class PluginStub {
  public SerializationStub serialization;
  public ImmutableStub immutable;
  public GuavaStub guava;
  public static final Class<?> GUAVA_CLASS = GuavaStub.class;
  public static final String GUAVA_NAME = "com.google.common.collect.ImmutableList";

  // Compiler plugins also name user types as data, as Compose's stability table does.
  public static final String[] USER_TYPES = {
    "com.google.common.collect.ImmutableList",
    "com.google.common.collect.ImmutableSet",
    "com.google.common.collect.ImmutableEnumSet",
    "com.google.common.collect.ImmutableMap",
    "com.google.common.collect.ImmutableEnumMap",
    "kotlinx.collections.immutable.PersistentList",
  };
}
