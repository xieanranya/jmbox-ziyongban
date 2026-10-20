plugins {
    // 与 settings.gradle.kts 同版本（apply false）：仅为让根脚本能引用 KGP 任务类型。
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
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

// 对齐所有模块（含三方插件，如 tflite_flutter）的 Java/Kotlin JVM 目标。
// 背景：tflite_flutter 插件 Java 目标 11、Kotlin 目标随工具链默认到 21，
// Gradle 9 + KGP 2.4 的 JVM 目标一致性校验会直接让构建失败
// （"Inconsistent JVM Target Compatibility"）。统一压到 17（JDK 21 可产 17 字节码）。
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { androidExtension ->
            if (androidExtension is com.android.build.gradle.BaseExtension) {
                androidExtension.compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java)
            .configureEach {
                compilerOptions.jvmTarget.set(
                    org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17,
                )
            }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
