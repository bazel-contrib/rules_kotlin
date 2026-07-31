package plugin;

import kotlinx.collections.immutable.ImmutableStub;
import kotlinx.serialization.SerializationStub;

/** Stands for a compiler plugin class that references both kinds of kotlinx classes. */
public class PluginStub {
  public SerializationStub serialization;
  public ImmutableStub immutable;
}
