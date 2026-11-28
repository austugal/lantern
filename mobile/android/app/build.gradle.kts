plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}
android {
    namespace = "org.austugal.lantern"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }
    defaultConfig {
        applicationId = "org.austugal.lantern"
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
}
flutter { source = "../.." }
dependencies {
    implementation("com.google.android.gms:play-services-nearby:19.3.0")
    // Flutter integration_test exposes older AndroidX Test libraries to the app.
    // AGP resolves instrumentation consistently with the tested debug variant,
    // so both classpaths must select the same test libraries and transitives.
    // Keep this alignment out of releaseImplementation.
    val androidTestLibraries = listOf(
        "androidx.test:core:1.7.0",
        "androidx.test.ext:junit:1.3.0",
        "androidx.test:runner:1.7.0",
    )
    androidTestLibraries.forEach {
        add("debugImplementation", it)
        add("androidTestImplementation", it)
    }
}
