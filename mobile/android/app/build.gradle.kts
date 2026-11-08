import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    // Push (FCM) iz app/google-services.json, Firebase projekat librum-ebook-c0f24.
    alias(libs.plugins.google.services)
}

// Javni URL i anon ključ (isti kao veb); nisu tajna, RLS štiti bazu.
val supabase = Properties().apply { rootProject.file("supabase.properties").inputStream().use { load(it) } }

android {
    namespace = "club.librum.kviz"
    compileSdk = 36

    defaultConfig {
        applicationId = "club.librum.kviz"
        minSdk = 26
        targetSdk = 36
        // Play traži rastući broj za svako otpremanje: minuti od 2026-01-01, ili KVIZ_GRADNJA.
        versionCode = System.getenv("KVIZ_GRADNJA")?.toInt() ?: ((System.currentTimeMillis() / 60_000 - 29_454_720).toInt())
        versionName = "1.0.8"
        buildConfigField("String", "SUPABASE_URL", "\"${supabase["SUPABASE_URL"]}\"")
        buildConfigField("String", "SUPABASE_ANON_KEY", "\"${supabase["SUPABASE_ANON_KEY"]}\"")
        // Google Cloud „librum-kviz” → Web client (javni ID); Android klijenti (upload i debug SHA-1) se ne navode u kodu.
        buildConfigField("String", "GOOGLE_WEB_CLIENT_ID", "\"570800222406-qp0jcrhsi2ivjqe5cbigse0hj9q89g48.apps.googleusercontent.com\"")
    }

    // ⚠⚠ Ključ za objavu NIJE u gitu i ne sme da se izgubi: Play vezuje aplikaciju za njega.
    // Original `~/kljucevi/kviz-upload.jks`, lozinke u `~/kljucevi/kviz-upload.properties`.
    val tajne = Properties().apply {
        val f = file(System.getProperty("user.home") + "/kljucevi/kviz-upload.properties")
        if (f.exists()) f.inputStream().use { load(it) }
    }
    signingConfigs {
        if (tajne.getProperty("KVIZ_KEYSTORE") != null) create("izdanje") {
            storeFile = file(tajne.getProperty("KVIZ_KEYSTORE"))
            storePassword = tajne.getProperty("KVIZ_KEYSTORE_LOZINKA")
            keyAlias = tajne.getProperty("KVIZ_KEY_ALIAS")
            keyPassword = tajne.getProperty("KVIZ_KEY_LOZINKA")
        }
    }

    buildTypes {
        // `./gradlew assembleDebug -Pproba`: debug pored Play verzije na istom emulatoru (drugi ID), za vizuelnu proveru.
        debug { if (project.hasProperty("proba")) applicationIdSuffix = ".proba" }
        release {
            // R8: kod sa 45 MB na nekoliko (sve Material ikonice), AAB staje u Play otpremanje iz pregledača.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // Bez ključa izdanje ostaje nepotpisano (Play ga odbija), nikad debug potpis.
            signingConfigs.findByName("izdanje")?.let { signingConfig = it }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    // Ista mapa i rezervna pitanja kao veb i iOS (alati/napravi-mapu.mjs); .ts fajlovi iz istog foldera se ne pakuju.
    sourceSets {
        // Avatari sa Knjigopolisa (public/avatari) idu u assets/avatari kroz kopiju ispod.
        getByName("main") { assets.srcDirs("../../../src/lib/osvajanje", "../../../src/lib/igre", "../../zvuci", layout.buildDirectory.dir("generated/avatari")) }
    }
    androidResources {
        ignoreAssetsPattern = "!.svn:!.git:!.ds_store:!*.scc:.*:!CVS:!thumbs.db:!picasa.ini:!*~:!*.ts"
    }
}

val kopirajAvatare by tasks.registering(Copy::class) {
    from("../../../public/avatari")
    into(layout.buildDirectory.dir("generated/avatari/avatari"))
}
tasks.named("preBuild") { dependsOn(kopirajAvatare) }

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.extended)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.kotlinx.serialization.json)
    // Google prijava (Credential Manager): id_token ide u Supabase, kao na iOS-u.
    implementation("androidx.credentials:credentials:1.3.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.3.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")

    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.messaging)

    testImplementation(libs.junit)
}
