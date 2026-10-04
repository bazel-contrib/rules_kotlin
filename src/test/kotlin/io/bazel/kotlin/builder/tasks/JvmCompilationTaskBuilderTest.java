package io.bazel.kotlin.builder.tasks;

import static com.google.common.truth.Truth.assertThat;

import io.bazel.kotlin.model.Directories;
import io.bazel.kotlin.model.BtapiRuntime;
import io.bazel.kotlin.model.Common;
import io.bazel.kotlin.model.CompilationTaskInfo;
import io.bazel.kotlin.model.Inputs;
import io.bazel.kotlin.model.Jvm;
import io.bazel.kotlin.model.JvmCompilationTask;
import io.bazel.kotlin.model.KotlinToolchainInfo;
import io.bazel.kotlin.model.Outputs;
import io.bazel.kotlin.model.Plugin;
import io.bazel.kotlin.model.PluginOption;
import io.bazel.kotlin.model.PluginPhase;
import java.util.ArrayList;
import java.util.Arrays;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

@RunWith(JUnit4.class)
public class JvmCompilationTaskBuilderTest {
    @Test
    public void defaultsMatchConstructors() {
        assertThat(JvmCompilationTask.builder().build()).isEqualTo(new JvmCompilationTask());
        assertThat(Inputs.builder().build()).isEqualTo(new Inputs());
        assertThat(Directories.builder().build()).isEqualTo(new Directories());
        assertThat(Outputs.builder().build()).isEqualTo(new Outputs());
        assertThat(BtapiRuntime.builder().build()).isEqualTo(new BtapiRuntime());
        assertThat(Common.builder().build()).isEqualTo(new Common());
        assertThat(CompilationTaskInfo.builder().build()).isEqualTo(new CompilationTaskInfo());
        assertThat(Jvm.builder().build()).isEqualTo(new Jvm());
        assertThat(KotlinToolchainInfo.builder().build()).isEqualTo(new KotlinToolchainInfo());
        assertThat(Plugin.builder().build()).isEqualTo(new Plugin());
        assertThat(PluginOption.builder().build()).isEqualTo(new PluginOption());
    }

    @Test
    public void metadataAndPluginListsAreSnapshots() {
        var paths = new ArrayList<>(Arrays.asList("first.jar"));
        var runtime = BtapiRuntime.builder().apiImplClasspathList(paths);
        var info = CompilationTaskInfo.builder().friendPathsList(paths);
        var option = PluginOption.builder().key("enabled").value("true").build();
        var plugin = Plugin.builder().id("plugin").classpathList(paths)
                .addOptions(option).addPhases(PluginPhase.PLUGIN_PHASE_COMPILE);
        var firstRuntime = runtime.build();
        var firstInfo = info.build();
        var firstPlugin = plugin.build();

        paths.clear();
        runtime.addApiImplClasspath("second.jar");
        info.friendPathsList(Arrays.asList("replacement.jar"));
        plugin.addClasspath("second.jar").optionsList(Arrays.asList());

        assertThat(firstRuntime.getApiImplClasspathList()).containsExactly("first.jar");
        assertThat(firstInfo.getFriendPathsList()).containsExactly("first.jar");
        assertThat(info.build().getFriendPathsList()).containsExactly("replacement.jar");
        assertThat(firstPlugin.getClasspathList()).containsExactly("first.jar");
        assertThat(firstPlugin.getOptionsList()).containsExactly(option);
        assertThat(option.getValue()).isEqualTo("true");
        assertThat(firstPlugin.getPhasesList()).containsExactly(PluginPhase.PLUGIN_PHASE_COMPILE);
        assertThat(plugin.build().getOptionsList()).isEmpty();
        assertThat(KotlinToolchainInfo.builder().btapi(firstRuntime).btapi(null).build().getBtapi())
                .isNull();
    }

    @Test
    public void listsAreSnapshotsOfCallerAndBuilderState() {
        var classpath = new ArrayList<>(Arrays.asList("first.jar", "second.jar"));
        var builder = Inputs.builder().classpathList(classpath).addKotlinSources("First.kt");
        var first = builder.build();
        classpath.clear();
        builder.addClasspath("third.jar").addAllKotlinSources(Arrays.asList("Second.kt", "Third.kt"));

        assertThat(first.getClasspathList()).containsExactly("first.jar", "second.jar").inOrder();
        assertThat(first.getKotlinSourcesList()).containsExactly("First.kt");
        assertThat(builder.build().getClasspathList())
                .containsExactly("first.jar", "second.jar", "third.jar").inOrder();
        assertThat(builder.build().getKotlinSourcesList())
                .containsExactly("First.kt", "Second.kt", "Third.kt").inOrder();
    }

    @Test
    public void nestedBuildersCanBeReusedWithoutChangingPreviousTasks() {
        var outputs = Outputs.builder().jar("first.jar");
        var directories = Directories.builder().classes("classes").temp("tmp");
        var builder = JvmCompilationTask.builder()
                .directories(directories.build())
                .outputs(outputs.build())
                .compileKotlin(true)
                .instrumentCoverage(true);
        var first = builder.build();
        builder.outputs(outputs.jar("second.jar").build())
                .directories(directories.classes("other").build());

        assertThat(first.getOutputs().getJar()).isEqualTo("first.jar");
        assertThat(first.getDirectories().getClasses()).isEqualTo("classes");
        assertThat(first.getDirectories().getTemp()).isEqualTo("tmp");
        assertThat(first.getCompileKotlin()).isTrue();
        assertThat(first.getInstrumentCoverage()).isTrue();
        assertThat(builder.build().getOutputs().getJar()).isEqualTo("second.jar");
        assertThat(builder.build().getDirectories().getClasses()).isEqualTo("other");
    }
}
