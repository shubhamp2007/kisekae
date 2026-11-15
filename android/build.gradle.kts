allprojects {
    repositories {
        google()
        mavenCentral()
        flatDir {
            dirs("${project(":unityLibrary").projectDir}/libs")
        }
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
    if (project.name == "flutter_unity_widget_2") {
        pluginManager.withPlugin("com.android.library") {
            dependencies.add("compileOnly", project(":unityLibrary"))
        }
        configurations.configureEach {
            if (name == "implementation" || name == "api" || name == "debugImplementation" || name == "releaseImplementation") {
                dependencies.removeIf { it is org.gradle.api.artifacts.FileCollectionDependency }
            }
        }
        afterEvaluate {
            extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
                compileSdk = 36
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
