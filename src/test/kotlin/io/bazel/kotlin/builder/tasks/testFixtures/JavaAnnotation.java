package something;

import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.reflect.Array;

@Retention(RetentionPolicy.RUNTIME)
public @interface JavaAnnotation {

    Class<?>[] modules() default {};
}
