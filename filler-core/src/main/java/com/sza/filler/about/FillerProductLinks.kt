package com.sza.filler.about

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build

/**
 * The addresses the About surfaces of the phone and the watch show (ABOUT-PAGE rules 2, 5 and 7, FILLER-0075 and
 * FILLER-0076): the one place the application types them. Nothing here is requested by the app; a surface only shows
 * an address or hands it to the browser when it is tapped. Each site address is held by the application: it is a row
 * of docs/site-held-addresses.jsonl and does not move.
 */
object FillerProductLinks {

    const val REPOSITORY = "https://github.com/SerZhyAle/Filler_Android"
    const val DOCUMENTATION = "https://github.com/SerZhyAle/Filler_Android#readme"
    const val LICENSE = "https://github.com/SerZhyAle/Filler_Android/blob/main/LICENSE"
    const val SUPPORT = "https://github.com/SerZhyAle/Filler_Android/issues"
    const val PLAY_LISTING = "https://play.google.com/store/apps/details?id=com.sza.filler"

    /** The product's own page in the interface language; the site has English, Russian and Ukrainian. */
    fun productPage(language: String): String = when (language) {
        "ru" -> "https://serzhyale.github.io/Filler_Android/index-ru.html"
        "uk" -> "https://serzhyale.github.io/Filler_Android/index-uk.html"
        else -> "https://serzhyale.github.io/Filler_Android/"
    }

    fun privacyPolicy(language: String): String = when (language) {
        "ru" -> "https://serzhyale.github.io/Filler_Android/privacy-ru.html"
        "uk" -> "https://serzhyale.github.io/Filler_Android/privacy-uk.html"
        else -> "https://serzhyale.github.io/Filler_Android/privacy.html"
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
