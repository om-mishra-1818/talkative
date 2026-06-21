plugins {
    id("com.google.gms.google-services") version "4.5.0" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")

    project.pluginManager.withPlugin("com.android.library") {
        val androidExt = project.extensions.findByName("android")
        if (androidExt != null) {
            try {
                val getNamespace = androidExt.javaClass.getMethod("getNamespace")
                val namespace = getNamespace.invoke(androidExt)
                if (namespace == null) {
                    val setNamespace = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespace.invoke(androidExt, project.group.toString())
                }
            } catch (e: Exception) {
                // ignore
            }
        }

        // Force all Android library subprojects to compile against a recent SDK.
        // Stale dependencies such as isar_flutter_libs declare compileSdkVersion 30,
        // which lacks android:attr/lStar (added in API 31) and fails resource
        // linking. afterEvaluate is too late to change compileSdk (AGP locks the
        // DSL -> AgpDslLockedException), so we use the variant API's finalizeDsl
        // hook, which runs after the library's own DSL block but before it locks.
        val androidComponents = project.extensions.findByName("androidComponents")
        if (androidComponents != null) {
            val finalizeDsl =
                androidComponents.javaClass.methods.firstOrNull {
                    it.name == "finalizeDsl" &&
                        it.parameterCount == 1 &&
                        org.gradle.api.Action::class.java.isAssignableFrom(it.parameterTypes[0])
                }
            if (finalizeDsl != null) {
                val action =
                    object : org.gradle.api.Action<Any> {
                        override fun execute(ext: Any) {
                            // AGP 8 new DSL: setCompileSdk(Integer); older: setCompileSdkVersion(int).
                            try {
                                ext.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java)
                                    .invoke(ext, 36)
                            } catch (e: NoSuchMethodException) {
                                try {
                                    ext.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                                        .invoke(ext, 36)
                                } catch (e2: Exception) {
                                    project.logger.info("Could not force compileSdk on ${project.name}: ${e2.message}")
                                }
                            }
                        }
                    }
                finalizeDsl.invoke(androidComponents, action)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
