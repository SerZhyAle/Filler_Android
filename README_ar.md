# Filler لنظام Android

<!-- languages -->
اللغات: [English](README.md) - [Русский](README_ru.md) - [Українська](README_uk.md) - [Deutsch](README_de.md) - [Italiano](README_it.md) - [Español](README_es.md) - [Français](README_fr.md) - [Português](README_pt.md) - العربية - [हिन्दी](README_hi.md) - [বাংলা](README_bn.md) - [اردو](README_ur.md) - [简体中文](README_zh.md)
<!-- /languages -->

يملأ Filler المساحة الفارغة في جهاز التخزين بملفات مؤقتة ثم يحذفها. تختار وحدة التخزين الداخلية أو بطاقة ذاكرة، أو مجلدًا عليها؛ فيعرض Filler المساحة الفارغة التي قاسها والجزء الذي يتركه فارغًا للنظام، ويكتب حتى المقدار الذي تؤكده، مع إظهار مقدار ما كُتب والنسبة المئوية والوقت المتبقي، ويحذف كل ملف كتبه - بعد تشغيل مكتمل أو إيقاف أو خطأ في الكتابة أو إعادة تشغيل أو نزع بطاقة الذاكرة. تبقى ملفاتك كما هي. وعلى الهاتف يعمل الملء أيضًا وفق جدول: في وقت محدد والتطبيق مغلق، حتى بعد إعادة التشغيل، مع إبقاء المقدار المعتاد 1 GB فارغًا، مرة واحدة في اليوم على الأكثر، مع إدراج كل تشغيل في السجل. معرّف تطبيق واحد، `com.sza.filler`، يشمل تطبيق Android وتطبيق Wear OS.

إنه Filler الخاص بالتخزين المحلي في FastMediaSorter وقد صار تطبيقًا قائمًا بذاته، ومنتجًا مستقلًا: لا يشترك في أي شيفرة تطبيق مع منتجات العائلة الأخرى، بل في العقود المنشورة فقط.

## البناء

بعد تثبيت JDK وAndroid SDK، يبني الأمر `./gradlew :phone:assembleDebug :wear:assembleDebug` ملفات APK للتنقيح لتطبيق الهاتف وتطبيق الساعة. من أين جاء المنتج: [docs/PLAN_BOOTSTRAP_HANDOFF.md](docs/PLAN_BOOTSTRAP_HANDOFF.md).

## الخصوصية

لا يتلقى المطوّر أيًا من بياناتك: لا حساب ولا تحليلات ولا إعلانات ولا تتبع. ليس لدى Filler وصول إلى الإنترنت، لذلك لا شيء يغادر الجهاز؛ لا يطلب تطبيق الهاتف إلا ما يشغّل الملء المجدول في وقته والتطبيق مغلق، ولا يطلب تطبيق الساعة إلا ما يُبقي الملء مستمرًا أثناء انطفاء شاشتها. السياسة الكاملة: [سياسة الخصوصية](https://serzhyale.github.io/Filler_Android/privacy-ar.html).

## تثبيت ملف APK من GitHub Releases أو SourceForge

تجعل ملفات APK الموقّعة للهاتف والساعة المنشورة خارج Google Play نظامَ Android يطلب السماح بالتطبيقات غير المعروفة من مصدر واحد، وقد تعرض إشعارًا من Play Protect بشأن المطوّر. تجد في [دليل التثبيت](docs/INSTALL_TRUST-ar.md) ما هي كل مطالبة، ولماذا تظهر، وعلى ماذا تضغط بالضبط. أما التطبيق نفسه على Google Play فموقّع عبر Play App Signing ولا تظهر معه أي من هذه المطالبات.

## التواصل

البريد الإلكتروني [sza@ukr.net](mailto:sza@ukr.net)، وعلى GitHub [SerZhyAle](https://github.com/SerZhyAle). نرحّب بالأسئلة وبلاغات الأخطاء في [مشكلات GitHub](https://github.com/SerZhyAle/Filler_Android/issues).

يُطوَّر هذا المشروع بمساعدة كبيرة من الذكاء الاصطناعي؛ ويراجع المؤلف كل تغيير.

## الترخيص

MIT - راجع [LICENSE](LICENSE).

<!-- Rendered by tools/locale/render-translations.ps1 from README.md and tools/locale/dictionaries/ar.json. Never edit it by hand. -->
