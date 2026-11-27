<#
.SYNOPSIS
    The Android vector renditions of the Filler mark: dot-sourced by render-store-assets.ps1, never run alone.

.DESCRIPTION
    Each template is one vector drawable of the phone or watch module with {PATH} where the master's path data goes
    and {NOTE} where the render-target note goes. render-store-assets.ps1 fills both and writes the files, so the
    drawing in every drawable is the master's, byte for byte (PRODUCT-IDENTITY rules 3 and 33, FILLER-0060).
#>

$generatedNote = 'Written by tools/store/render-store-assets.ps1 from the master (PRODUCT-IDENTITY,
     FILLER-0060): a render target, never edited by hand.'

$launcherForeground = @'
<?xml version="1.0" encoding="utf-8"?>
<!-- Rich launcher foreground of Filler (FILLER-0072): retains the inherited FastMediaSorter 3-bay
     storage block silhouette (S0050) on its 24-unit grid, group-scaled 2.5x and centred on the
     108-unit adaptive canvas (29-79 by 34-74, inside the 66-unit safe circle) over #12355B, with
     dimensional drive bays, status indicators, and bottom-to-top fill-level meters.
     {NOTE} -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <group
        android:scaleX="2.5"
        android:scaleY="2.5"
        android:translateX="24"
        android:translateY="24">
{FOREGROUND_PATHS}
    </group>
</vector>
'@

$launcherMonochrome = @'
<?xml version="1.0" encoding="utf-8"?>
<!-- Monochrome adaptive launcher layer of Filler (FILLER-0072): the small/mono glyph inherited from
     FastMediaSorter (S0050, upstream app_v2/src/main/res/drawable/ic_storage.xml) scaled 2.5x onto
     the 108-unit launcher canvas for Android 13+ themed icons.
     {NOTE} -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <group
        android:scaleX="2.5"
        android:scaleY="2.5"
        android:translateX="24"
        android:translateY="24">
        <path
            android:fillColor="#FFFFFF"
            android:pathData="{PATH}" />
    </group>
</vector>
'@

$debugBadgePath = 'M32.5,36.5 A4,4 0 1 0 40.5,36.5 A4,4 0 1 0 32.5,36.5 Z'

$debugLauncherForeground = @"
<?xml version="1.0" encoding="utf-8"?>
<!-- Debug launcher foreground of Filler (FILLER-0074): the product master foreground with the
     PRODUCT-IDENTITY rule 23 debug corner badge (orange #F3821D disc at (36.5, 36.5), radius 4
     on the 108-unit adaptive canvas) so debug builds are distinct from the store release.
     {NOTE} -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <group
        android:scaleX="2.5"
        android:scaleY="2.5"
        android:translateX="24"
        android:translateY="24">
{FOREGROUND_PATHS}
    </group>
    <path
        android:fillColor="#F3821D"
        android:pathData="$debugBadgePath" />
</vector>
"@

$debugLauncherMonochrome = @"
<?xml version="1.0" encoding="utf-8"?>
<!-- Debug monochrome adaptive launcher layer of Filler (FILLER-0074): the small/mono glyph with
     the debug corner badge at (36.5, 36.5), radius 4 on the 108-unit canvas.
     {NOTE} -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <group
        android:scaleX="2.5"
        android:scaleY="2.5"
        android:translateX="24"
        android:translateY="24">
        <path
            android:fillColor="#FFFFFF"
            android:pathData="{PATH}" />
    </group>
    <path
        android:fillColor="#FFFFFF"
        android:pathData="$debugBadgePath" />
</vector>
"@

$statIcon = @'
<?xml version="1.0" encoding="utf-8"?>
<!-- Notification small icon and watch-face ongoing-activity icon of Filler (FILLER-0059): the inherited
     FastMediaSorter Filler block - the one path of the upstream app_v2/src/main/res/drawable/ic_storage.xml,
     path data byte for byte - on its own 24-unit grid, so the status bar and the watch face draw the block at
     full size instead of the launcher canvas with its 108-unit margins. A single-colour, alpha-only silhouette
     (ICON-RENDER section 3 rule 9): white fill, no theme tint, because the system tints it and resolves no
     attribute of this app's theme.
     {NOTE} -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFF"
        android:pathData="{PATH}" />
</vector>
'@

$phoneTitleGlyph = @'
<?xml version="1.0" encoding="utf-8"?>
<!-- Inherited from FastMediaSorter (S0050): the Filler block icon, upstream
     app_v2/src/main/res/drawable/ic_storage.xml - the title icon of its activity_filler.xml toolbar and
     the route icon of the storage_filler block. The single path's data equals the upstream file byte for
     byte. Deliberate difference: the upstream fill @color/white reads @android:color/white here (this
     app defines no colour named white); the upstream colorControlNormal tint is kept, so the glyph draws
     in the toolbar's theme ink as it does there.
     {NOTE} -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24"
    android:tint="?attr/colorControlNormal">
    <path
        android:fillColor="@android:color/white"
        android:pathData="{PATH}" />
</vector>
'@

$wearTitleGlyph = @'
<?xml version="1.0" encoding="utf-8"?>
<!-- Inherited from FastMediaSorter (FILLER-0059): the Filler block icon, upstream
     app_v2/src/main/res/drawable/ic_storage.xml, the glyph phone/src/main/res/drawable/ic_storage.xml shows as the
     phone toolbar's logo (S0050). The single path's data equals the upstream file byte for byte. Deliberate
     differences: the fill is @android:color/white and the vector carries no tint, because the watch module has no
     colorControlNormal attribute of its own; the title that shows it tints it with the theme's primary text colour
     (ICON-RENDER section 3 rule 9: the same glyph as the phone, 24 to 32 dp on black glass, coloured by role).
     {NOTE} -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="@android:color/white"
        android:pathData="{PATH}" />
</vector>
'@

# Repository path of each vector rendition -> its template.
$vectorTargets = [ordered]@{
    'phone/src/main/res/drawable/ic_launcher_foreground.xml'  = $launcherForeground
    'wear/src/main/res/drawable/ic_launcher_foreground.xml'   = $launcherForeground
    'phone/src/main/res/drawable/ic_launcher_monochrome.xml'  = $launcherMonochrome
    'wear/src/main/res/drawable/ic_launcher_monochrome.xml'   = $launcherMonochrome
    'phone/src/debug/res/drawable/ic_launcher_foreground.xml' = $debugLauncherForeground
    'wear/src/debug/res/drawable/ic_launcher_foreground.xml'  = $debugLauncherForeground
    'phone/src/debug/res/drawable/ic_launcher_monochrome.xml' = $debugLauncherMonochrome
    'wear/src/debug/res/drawable/ic_launcher_monochrome.xml'  = $debugLauncherMonochrome
    'phone/src/main/res/drawable/ic_stat_filler.xml'          = $statIcon
    'wear/src/main/res/drawable/ic_stat_filler.xml'          = $statIcon
    'phone/src/main/res/drawable/ic_storage.xml'             = $phoneTitleGlyph
    'wear/src/main/res/drawable/ic_storage.xml'              = $wearTitleGlyph
}
