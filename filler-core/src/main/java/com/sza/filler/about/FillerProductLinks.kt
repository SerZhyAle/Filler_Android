package com.sza.filler.about

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import java.util.Locale

/**
 * The addresses the About surfaces of the phone and the watch show (ABOUT-PAGE rules 2, 5 and 7, FILLER-0075 and
 * FILLER-0076): the one place the application types them. Nothing here is requested by the app; a surface only shows
 * an address or hands it to the browser when it is tapped. Each site address is held by the application: it is a row
 * of docs/site-held-addresses.jsonl and does not move.
 *
 * The product page, the documentation and the privacy policy exist in every interface language (FILLER-0079); a
 * language the product does not publish opens the English page (SITE-STRUCTURE rule 11). Each address is written out
 * so that the held-address gate and tools/locale/check-locales.ps1 can read it.
 */
object FillerProductLinks {

    const val REPOSITORY = "https://github.com/SerZhyAle/Filler_Android"
    const val LICENSE = "https://github.com/SerZhyAle/Filler_Android/blob/main/LICENSE"
    const val SUPPORT = "https://github.com/SerZhyAle/Filler_Android/issues"
    const val PLAY_LISTING = "https://play.google.com/store/apps/details?id=com.sza.filler"

    private val TRADITIONAL_CHINESE_REGIONS = setOf("TW", "HK", "MO")

    /**
     * The language key of the addresses for an interface locale. Chinese is published in the simplified script only, so a
     * traditional-script locale, whose interface is English, gets the English pages.
     */
    fun siteLanguage(locale: Locale): String {
        if (locale.language != "zh") return locale.language
        val simplified = when (locale.script) {
            "Hans" -> true
            "" -> locale.country !in TRADITIONAL_CHINESE_REGIONS
            else -> false
        }
        return if (simplified) "zh" else "en"
    }

    /** The product's own page in the interface language. */
    fun productPage(language: String): String = when (language) {
        "ru" -> "https://serzhyale.github.io/Filler_Android/index-ru.html"
        "uk" -> "https://serzhyale.github.io/Filler_Android/index-uk.html"
        "de" -> "https://serzhyale.github.io/Filler_Android/index-de.html"
        "it" -> "https://serzhyale.github.io/Filler_Android/index-it.html"
        "es" -> "https://serzhyale.github.io/Filler_Android/index-es.html"
        "fr" -> "https://serzhyale.github.io/Filler_Android/index-fr.html"
        "pt" -> "https://serzhyale.github.io/Filler_Android/index-pt.html"
        "ar" -> "https://serzhyale.github.io/Filler_Android/index-ar.html"
        "hi" -> "https://serzhyale.github.io/Filler_Android/index-hi.html"
        "bn" -> "https://serzhyale.github.io/Filler_Android/index-bn.html"
        "ur" -> "https://serzhyale.github.io/Filler_Android/index-ur.html"
        "zh" -> "https://serzhyale.github.io/Filler_Android/index-zh.html"
        else -> "https://serzhyale.github.io/Filler_Android/"
    }

    fun privacyPolicy(language: String): String = when (language) {
        "ru" -> "https://serzhyale.github.io/Filler_Android/privacy-ru.html"
        "uk" -> "https://serzhyale.github.io/Filler_Android/privacy-uk.html"
        "de" -> "https://serzhyale.github.io/Filler_Android/privacy-de.html"
        "it" -> "https://serzhyale.github.io/Filler_Android/privacy-it.html"
        "es" -> "https://serzhyale.github.io/Filler_Android/privacy-es.html"
        "fr" -> "https://serzhyale.github.io/Filler_Android/privacy-fr.html"
        "pt" -> "https://serzhyale.github.io/Filler_Android/privacy-pt.html"
        "ar" -> "https://serzhyale.github.io/Filler_Android/privacy-ar.html"
        "hi" -> "https://serzhyale.github.io/Filler_Android/privacy-hi.html"
        "bn" -> "https://serzhyale.github.io/Filler_Android/privacy-bn.html"
        "ur" -> "https://serzhyale.github.io/Filler_Android/privacy-ur.html"
        "zh" -> "https://serzhyale.github.io/Filler_Android/privacy-zh.html"
        else -> "https://serzhyale.github.io/Filler_Android/privacy.html"
    }

    /** The README of the repository in the interface language. */
    fun documentation(language: String): String = when (language) {
        "ru" -> "https://github.com/SerZhyAle/Filler_Android/blob/main/README_ru.md"
        "uk" -> "https://github.com/SerZhyAle/Filler_Android/blob/main/README_uk.md"
        "de" -> "https://github.com/SerZhyAle/Filler_Android/blob/main/README_de.md"
        "it" -> "https://github.com/SerZhyAle/Filler_Android/blob/main/README_it.md"
        "es" -> "https://github.com/SerZhyAle/Filler_Android/blob/main/README_es.md"
        "fr" -> "https://github.com/SerZhyAle/Filler_Android/blob/main/README_fr.md"
        "pt" -> "https://github.com/SerZhyAle/Filler_Android/blob/main/README_pt.md"
        "ar" -> "https://github.com/SerZhyAle/Filler_Android/blob/main/README_ar.md"
        "hi" -> "https://github.com/SerZhyAle/Filler_Android/blob/main/README_hi.md"
        "bn" -> "https://github.com/SerZhyAle/Filler_Android/blob/main/README_bn.md"
        "ur" -> "https://github.com/SerZhyAle/Filler_Android/blob/main/README_ur.md"
        "zh" -> "https://github.com/SerZhyAle/Filler_Android/blob/main/README_zh.md"
        else -> "https://github.com/SerZhyAle/Filler_Android#readme"
    }

    /**
     * Where the mention of the other app leads (rule 7): the store listing for an install that came from Google Play,
     * the product's own page for every other install.
     */
    fun companionPage(fromPlay: Boolean, language: String): String =
        if (fromPlay) PLAY_LISTING else productPage(language)

    fun installedFromPlay(context: Context): Boolean {
        val packages = context.packageManager
        val installer = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                packages.getInstallSourceInfo(context.packageName).installingPackageName
            } else {
                @Suppress("DEPRECATION")
                packages.getInstallerPackageName(context.packageName)
            }
        } catch (e: PackageManager.NameNotFoundException) {
            null
        }
        return installer == PLAY_STORE_PACKAGE
    }

    private const val PLAY_STORE_PACKAGE = "com.android.vending"
}
