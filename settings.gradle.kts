pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        // ShieldControllerExtensions, used by Moonlight's core
        maven { url = uri("https://jitpack.io") }
    }
}

rootProject.name = "RayDesk"
include(":app")
// Moonlight's streaming core; sources fetched by scripts/fetch-dependencies.sh
include(":moonlight-core")
