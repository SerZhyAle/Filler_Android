# Android کے لیے Filler

<!-- languages -->
زبانیں: [English](README.md) - [Русский](README_ru.md) - [Українська](README_uk.md) - [Deutsch](README_de.md) - [Italiano](README_it.md) - [Español](README_es.md) - [Français](README_fr.md) - [Português](README_pt.md) - [العربية](README_ar.md) - [हिन्दी](README_hi.md) - [বাংলা](README_bn.md) - اردو - [简体中文](README_zh.md)
<!-- /languages -->

Filler اسٹوریج ڈیوائس کی خالی جگہ عارضی فائلوں سے بھرتا ہے اور پھر انہیں حذف کر دیتا ہے۔ آپ اندرونی اسٹوریج یا میموری کارڈ، یا اس پر کوئی فولڈر منتخب کرتے ہیں؛ Filler اپنی ناپی ہوئی خالی جگہ اور وہ حصہ دکھاتا ہے جو وہ سسٹم کے لیے خالی رکھتا ہے، آپ کی تصدیق کردہ مقدار تک لکھتا ہے، اس دوران لکھی گئی مقدار، فیصد اور باقی وقت سامنے رہتا ہے، اور اپنی لکھی ہوئی ہر فائل حذف کر دیتا ہے - رن مکمل ہونے، روکے جانے، لکھنے کی خرابی، ری اسٹارٹ یا میموری کارڈ نکالے جانے کے بعد۔ آپ کی اپنی فائلیں جیسی ہیں ویسی ہی رہتی ہیں۔ فون پر بھرنا شیڈول پر بھی چلتا ہے: مقررہ وقت پر ایپ بند ہونے پر بھی، حتیٰ کہ ری اسٹارٹ کے بعد بھی، معمول کی 1 GB جگہ خالی رکھتے ہوئے، دن میں زیادہ سے زیادہ ایک بار، اور ہر رن ہسٹری میں درج ہوتا ہے۔ ایک ہی ایپلیکیشن آئی ڈی، `com.sza.filler`، Android ایپ اور Wear OS ایپ دونوں کا احاطہ کرتی ہے۔

یہ FastMediaSorter کا مقامی اسٹوریج والا Filler ہے جو اب اپنی الگ ایپ ہے، اور ایک آزاد پروڈکٹ ہے: یہ اپنے خاندان کی دوسری مصنوعات کے ساتھ کوئی ایپلیکیشن کوڈ شیئر نہیں کرتا، صرف شائع شدہ معاہدے۔

## بلڈ کرنا

JDK اور Android SDK انسٹال ہوں تو `./gradlew :phone:assembleDebug :wear:assembleDebug` فون ایپ اور گھڑی ایپ کی ڈیبگ APK فائلیں بناتا ہے۔ یہ پروڈکٹ کہاں سے آیا: [docs/PLAN_BOOTSTRAP_HANDOFF.md](docs/PLAN_BOOTSTRAP_HANDOFF.md)۔

## رازداری

ڈیولپر کو آپ کا کوئی ڈیٹا نہیں ملتا: نہ کوئی اکاؤنٹ، نہ تجزیات، نہ اشتہارات، نہ ٹریکنگ۔ Filler کو انٹرنیٹ تک رسائی نہیں ہے، اس لیے کچھ بھی آلے سے باہر نہیں جاتا؛ فون ایپ صرف وہی مانگتی ہے جس سے شیڈول شدہ بھرنا ایپ بند ہونے پر وقت پر چلے، اور گھڑی ایپ صرف وہی جس سے اسکرین بند ہونے پر بھرنا جاری رہے۔ مکمل پالیسی: [رازداری کی پالیسی](https://serzhyale.github.io/Filler_Android/privacy-ur.html)۔

## GitHub Releases یا SourceForge سے APK انسٹال کرنا

Google Play سے باہر شائع کی گئی فون اور گھڑی کی دستخط شدہ APK فائلوں پر Android ایک ذریعے سے نامعلوم ایپس کی اجازت مانگتا ہے اور ڈیولپر کے بارے میں Play Protect کا نوٹس دکھا سکتا ہے۔ ہر پیغام کیا ہے، کیوں آتا ہے اور بالکل کہاں ٹیپ کرنا ہے، یہ [انسٹال گائیڈ](docs/INSTALL_TRUST-ur.md) میں ہے۔ Google Play پر موجود یہی ایپ Play App Signing سے دستخط شدہ ہے اور اس کے ساتھ ان میں سے کوئی پیغام نہیں آتا۔

## رابطہ

ای میل [sza@ukr.net](mailto:sza@ukr.net)، GitHub [SerZhyAle](https://github.com/SerZhyAle)۔ سوالات اور بگ رپورٹس [GitHub ایشوز](https://github.com/SerZhyAle/Filler_Android/issues) کے طور پر خوش آمدید ہیں۔

یہ پروجیکٹ AI کی بھرپور مدد سے تیار کیا جاتا ہے؛ مصنف ہر تبدیلی کا جائزہ لیتا ہے۔

## لائسنس

MIT - [LICENSE](LICENSE) دیکھیں۔

<!-- Rendered by tools/locale/render-translations.ps1 from README.md and tools/locale/dictionaries/ur.json. Never edit it by hand. -->
