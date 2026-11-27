# UI size profile and button component policy - the phone screen

The size-profile record that `UI-SIZING` section 2 rule 2 and section 4 and `BUTTONS` section 8 rule 1 ask each product
to publish, and the component policy that `BUTTONS` section 2 rule 1 asks it to record, for the phone Filler screen
(`FillerActivity`, both orientations). Written by S0027 on 2026-11-14 from the source (the two layouts, `values/styles.xml`,
`values/dimens.xml`, `res/color/filler_button_ink_neutral.xml`, `res/drawable/ic_action_*.xml`) and the library values of
Material 1.14.0. It records what the source says; no screen of it was captured on a device, and nothing here is a claim of
conformance beyond the source gate (section 8).

The watch screen has its own record, the Wear OS variant of `UI-SIZING` section 6 with its review condition; it is written
with the watch device check (S0020) and is not covered here.

## 1. Input profile

Touch, the default on Android (`UI-SIZING` section 2 rule 1). The screen has no pointer profile and no switch between
profiles; a hardware keyboard or D-pad reaches the same controls by the focus links of the layouts (`INPUT-PARITY`, S0006 D10).

## 2. Baseline, range and the two scales

- **Ordinary baseline:** the Material 3 touch baseline of the app at the system font scale 1.0 and the system display size,
  with the tokens of section 3.
- **Interface scale:** the system display size (density). Every dimension of the screen is in dp and every text size comes
  from a `textAppearance` in sp, so density scales the layout and glyphs once and the font scale scales the text once, with
  no second multiplier in the app (`UI-SIZING` section 2 rule 3).
- **Supported range:** font scale from the system's smallest setting to 2.0, the largest Android 14 offers, and every display
  size the system offers. The product exposes no interface-size selector and no compact mode, so it declares no compact
  floor (`UI-SIZING` section 2 rule 4): its smallest target is the ordinary 48 by 48 dp of section 4.
- **Text enlargement:** independent of the interface scale; text and layout grow first, the content sits in a `ScrollView`,
  no caption is shrunk, clipped or limited (`maxLines`, `ellipsize` and `singleLine` appear nowhere in the layouts).

## 3. Button tokens (touch profile, `BUTTONS` section 3)

| Token | Contract baseline | Where it lives | Value |
| --- | --- | --- | --- |
| Corner radius | 4 | `dimen/filler_button_corner_radius`, through `ShapeAppearance.Filler.Button` | 4 dp, rounded family, no pill |
| Horizontal padding per side | 16 | `dimen/filler_button_padding_horizontal` | 16 dp |
| Caption glyph tier | 20 | `dimen/filler_button_glyph_size` | 20 dp |
| Glyph-to-caption gap | 8 | `dimen/filler_button_glyph_gap` | 8 dp |
| Border width | 1 | Material's outlined button | 1 dp |
| Button gap | 8 | `filler_spacing_8` as the top margin of a button under its text | 8 dp |
| Semantic group gap | 16 | `filler_spacing_16` between the groups of the column | 16 dp |

The three Filler styles (`Widget.Filler.Button.Filled`, `.Outlined`, `.Tonal`) restate the shape and the padding because
Material 3 1.14.0 fixes both in its own button styles (a full-pill shape, 24 dp padding), so a theme attribute cannot reach
them. The glyph sits at reading start (`iconGravity="textStart"`), so right-to-left layouts mirror its place.

## 4. Smallest targets and glyph bounds

- **Targets:** each button is a `MaterialButton` of Material's own geometry: a layout height of at least 48 dp (a 40 dp face
  between two 4 dp insets, `m3_btn_inset`) and a 48 dp minimum touch target (`minTouchTargetSize`). Heights are not set by
  the product; a caption that wraps grows the button. The slider keeps Material's own thumb target. No target extension
  overlaps another control: the buttons are one per row in a column with 8 dp or 16 dp between them.
- **Width:** `wrap_content` for every button - the caption plus 2 x 16 dp of padding, plus 20 dp and 8 dp where a glyph is
  drawn, within Material's minimum width and its 320 dp maximum width (beyond which the caption wraps and the height grows).
  No button is stretched, equalised or given a weight. Whether the longest shipped caption stays on one line, and what the
  right-to-left locales (`ar`, `ur`) do, is a device check (S0006 D10 and D13).
- **Glyph bounds under enlargement:** the glyph is 20 dp at every font scale (a vector drawn at actual size, never an enlarged
  bitmap) and scales with the display size like every dp; it does not grow with the font scale (`UI-SIZING` section 2
  rule 3 allows moderate growth and does not require it). Smallest 20 dp, largest 20 dp at a given display size.

## 5. Component policy - which commands carry a glyph

`BUTTONS` section 2 rule 1: a substantive command carries its `ICON-SET` glyph when the glyph helps recognition; simple
obvious answers may be text-only.

- **Every command button of the task column carries its glyph**: each starts a distinct operation whose meaning has a
  vocabulary entry, and the glyph shows what the caption says before it is read. All four buttons are substantive.
- **Dialog answers are text-only**: the start confirmation answers with the platform's Cancel and the screen's Fill
  caption in reading order; a dialog answer keeps its caption (`BUTTONS` section 2 rule 4) and a plain answer needs no glyph.
- **A glyph is the catalog's drawing and nothing else**: the path data of each drawable is the `d` of the catalog file
  `glyphs/<id>.svg` byte for byte (checked on 2026-11-14), on the 24 by 24 grid; the product draws no private glyph for a
  meaning the vocabulary has (`ICON-SET` section 2 rule 1).
- **The volume line carries no glyph**: it is text, not a control. If a volume chooser is ever added it carries `system.storage`
  (active), never `media.volume`, which is sound.
- **Help** (`app.help`) belongs to S0028.

| Button id | Caption | Meaning (`ICON-SET` 0.39) | Status | Drawable | Style | Rank | Ink and glyph colour |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `btnFillerChooseFolder` | Choose folder | `action.choose-folder` | proposed | `ic_action_choose_folder` | `Widget.Filler.Button.Outlined` | ordinary | neutral (`colorOnSurface`) |
| `btnFillerStart` | Start filling | `action.fill-space` | proposed | `ic_action_fill_space` | `Widget.Filler.Button.Filled` | primary | `colorOnPrimary` on `colorPrimary` |
| `btnFillerCancel` | Stop and delete files | `action.cancel` (never `media.stop`) | active | `ic_action_cancel` | `Widget.Filler.Button.Outlined` | ordinary | neutral (`colorOnSurface`) |
| `btnFillerRetryCleanup` | Delete remaining files | `action.delete` | active | `ic_action_delete` | `Widget.Filler.Button.Tonal` | ordinary | `colorOnSecondaryContainer` on `colorSecondaryContainer` |
| `action_theme` (toolbar) | Color theme | `app.theme` | active | `ic_app_theme` | toolbar action | ordinary | `colorControlNormal` |
| `action_about` (toolbar) | About Filler | `app.info` | active | `ic_app_info` | toolbar action | ordinary | `colorControlNormal` |
| `btnScheduleRunNow` (`ScheduleActivity`) | Run now | `action.run` | active | `ic_action_run` | `Widget.Filler.Button.Outlined` | ordinary | neutral (`colorOnSurface`) |
| `btnSchedulePauseAll` (`ScheduleActivity`) | Pause all / Resume all | `media.pause` / `action.run` | active | `ic_media_pause` / `ic_action_run` | `Widget.Filler.Button.Outlined` | ordinary | neutral (`colorOnSurface`) |
| `btnScheduleClearHistory` (`ScheduleActivity`) | Clear history | `action.clear-all` | active | `ic_action_clear_all` | `Widget.Filler.Button.Outlined` | ordinary | neutral (`colorOnSurface`) |
| `btnScheduleNotifications` (`ScheduleActivity`) | Allow notifications | `system.notification-shade` | active | `ic_system_notification` | `Widget.Filler.Button.Outlined` | ordinary | neutral (`colorOnSurface`) |

- **Ranks:** one primary action per task surface (Start). The screen has no destructive-rank button because it has no
  destructive confirmation: Stop and Delete remaining files remove only the files the run wrote, never user data.
- **Cancel-type command:** Stop and delete files uses the neutral treatment of `BUTTONS` section 3 rule 5, the same style as
  Choose folder, with no error hue (the FastMediaSorter screen draws it with `colorError`).
- **Colour:** glyphs are mono - the ink of the caption, through Material's `iconTint` - so a theme change or a disabled
  state recolours text and glyph together; the drawables carry only a placeholder fill and the theme-role vector tint
  (`ICON-RENDER` section 3 rule 2).
- **Provisional meanings:** `action.choose-folder` and `action.fill-space` are `proposed` records in 0.39 with a decided
  glyph. They are listed here by their proposed ids until the owner folds them in. The first-shipper report of `ICON-SET`
  section 2 rule 6 is owed with the release that first ships them, not before (a release item, S0022 and S0023).

## 6. Measured pairs (source computation)

Since FILLER-0067 (2026-11-25), `Base.Theme.Filler` uses FastMediaSorter's blue Light/Dark brand palette (`values/colors.xml`,
`values-night/colors.xml`, `values/themes.xml`, `values-night/themes.xml`) plus the six custom accent theme overlays
(`ThemeOverlay.Filler.{DarkGreen,DarkBlue,DarkRed,LightGreen,LightBlue,LightRed}`) switched from the toolbar via `ColorThemePrefs`;
there is no dynamic colour. The pairs below are the WCAG 2.1 contrast ratios of the base Light and Dark brand palettes, computed on
2026-11-25 (and the stock Material 3 tonal `secondaryContainer` pair unchanged from 2026-11-14). Text and glyph share one ink, so one
pair covers both (needs 4.5 : 1 for text, 3 : 1 for a glyph and for the border).

| Pair | Light | Dark |
| --- | --- | --- |
| Start: `onPrimary` on `primary` (`#FFFFFF` on `#1976D2` / `#000000` on `#64B5F6`) | 4.60 | 9.48 |
| Choose folder and Stop: `onSurface` on `surface` (`#000000` on `#FFFFFF` / `#FFFFFF` on `#121212`) | 21.00 | 18.73 |
| Delete remaining files: `onSecondaryContainer` on `secondaryContainer` | 13.24 | 7.19 |
| Secondary text: `onSurfaceVariant` on `surface` (`#655E6A` on `#FFFFFF` / `#CAC4D0` on `#121212`) | 6.25 | 10.99 |
| Outlined border: `outline` on `surface` (`#6F6875` on `#FFFFFF` / `#938F99` on `#121212`) | 5.37 | 5.91 |

Not measured: hover, pressed, focused and selected faces, the state layers over a face, the six custom accent overlays on a device,
and the disabled state (it mutes text and glyph together by one opacity of 0.38 and carries no hue). Those are the generated captures
and measurements of `BUTTONS` section 5, S0006 D13 and FILLER-0067.

## 7. Differences from the FastMediaSorter screen

Since FILLER-0067 (2026-11-25), Filler shares FastMediaSorter's blue Light/Dark brand theme, six custom accent theme overlays
(`ColorThemePrefs`), `StandardToolbar` (`Widget.Filler.Toolbar.Flat` with 8 dp `toolbar_title_icon_gap` and
`TextAppearance.Filler.Bar.Title`), and `ScheduleActivity` `MaterialCardView` rows with `focus_button_background`, `Run now`,
`Pause/Resume all`, `Clear history`, and the API 33+ notification-permission prompt button. Deliberate differences kept (owner
decision Q2 of FILLER-0067): the `BUTTONS` 2.2 rectangular shape with radius 4, 16 dp padding, a catalog `ICON-SET` glyph on each
command, the neutral Outlined Stop, the rectangular text dialog answers (`ThemeOverlay.Filler.MaterialAlertDialog`), the 24 dp square
schedule checkbox (`BOOLEAN-OPTION` 2.2, S0045), and `FlowRowLayout` wrapping inside schedule cards so buttons never clip on 320 dp
screens or at font scale 2.0. Recorded in the heads of the layouts and in `values/styles.xml` and `values/themes.xml`.

## 8. What is claimed and what is not

Claimed, by source gate: the corner shape, the padding, the neutral Cancel-type command, the glyph policy, the pairs of
section 6, and the shape and caption of the dialog answers of every product dialog (S0033: the answers take the restated
answer style, which is rectangular and has no one-line attributes, so a caption is not cut; the stock Material answer is
not used). Not claimed: any capture, the font-scale 2.0 and longest-locale behaviour, right-to-left, the focus ring, the
reference showcase, the dialog answers on a device (the S0006 D13 check), and the hover and pressed pairs. The registry
rows of `UI-SIZING`, `BUTTONS`, `ICON-SET` and `ICON-RENDER` stay `pending` with their dated exceptions until the device
evidence exists.

## 9. Review conditions

Re-read this record when a button or a control is added to the screen, when the Material library is upgraded (its styles may
change), when an interface-size selector or a compact mode is added (a compact floor must then be declared and tested), when
the owner folds `action.choose-folder` or `action.fill-space` into the vocabulary, and when `BUTTONS` or `UI-SIZING` change.
