import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

val payBoardLocalProperties = Properties().apply {
    val file = rootProject.file("payboard.local.properties")
    if (file.exists()) {
        file.inputStream().use { input -> load(input) }
    }
}

fun localConfig(name: String): String {
    val envValue = providers.environmentVariable(name).orNull?.trim().orEmpty()
    if (envValue.isNotEmpty()) return envValue
    return payBoardLocalProperties.getProperty(name)?.trim().orEmpty()
}

android {
    namespace = "kr.co.cdd.payboard"
    compileSdk = 36

    defaultConfig {
        applicationId = "kr.co.cdd.payboard"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        manifestPlaceholders["SUPABASE_URL"] = localConfig("SUPABASE_URL")
        manifestPlaceholders["SUPABASE_ANON_KEY"] = localConfig("SUPABASE_ANON_KEY")
        manifestPlaceholders["PAYBOARD_SERVER_URL"] = localConfig("PAYBOARD_SERVER_URL")
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures {
        compose = true
    }
}

dependencies {
    implementation(project(":core:app"))
    implementation(libs.androidx.appcompat)
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
}
